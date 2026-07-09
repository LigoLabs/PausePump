import XCTest
@testable import WatchEngine

/// Horloge contrôlable pour simuler l'écoulement du temps.
final class FakeClock {
    var current = Date(timeIntervalSince1970: 1_000_000)
    func advance(_ seconds: Double) { current = current.addingTimeInterval(seconds) }
}

final class WorkoutEngineTests: XCTestCase {
    var clock: FakeClock!
    var engine: WorkoutEngine!
    var events: [EngineEvent] = []

    override func setUp() {
        super.setUp()
        clock = FakeClock()
        engine = WorkoutEngine(now: { [clock] in clock!.current })
        events = []
        engine.onEvent = { [weak self] in self?.events.append($0) }
    }

    /// Fait s'écouler le temps puis notifie le moteur (comme la TimelineView).
    private func elapse(_ seconds: Double) {
        clock.advance(seconds)
        engine.tick()
    }

    // =========================================================================
    //  Pause seule — parité avec timer_controller_test.dart
    // =========================================================================
    func testPauseSeuleValiderUneSerie() {
        engine.setMode(.pause)
        engine.startSession(series: 3)

        XCTAssertEqual(engine.step, .doSet)
        XCTAssertEqual(engine.seriesRemaining, 3)
        XCTAssertEqual(engine.seriesTotal, 3)
        XCTAssertEqual(engine.tlDots, 0)

        engine.validateSet()
        XCTAssertEqual(engine.seriesRemaining, 2, "compteur −1 dès la validation")
        XCTAssertEqual(engine.tlDots, 1, "le point de la série se remplit")
        XCTAssertEqual(engine.step, .duration)

        engine.pickDuration(60)
        XCTAssertEqual(engine.step, .timer)
        XCTAssertTrue(engine.running)
        XCTAssertEqual(engine.phase, .pause)
        XCTAssertEqual(engine.remaining(), 60.0, accuracy: 0.001)

        engine.pauseCountdown()
        XCTAssertFalse(engine.running)
        XCTAssertEqual(engine.remaining(), 60.0, accuracy: 0.001,
                       "le restant est figé pendant la pause du décompte")
    }

    func testCompteurPlusMoinsAjusteTotalEtRestant() {
        engine.setMode(.pause)
        engine.startSession(series: 3)

        engine.addSeries()
        XCTAssertEqual(engine.seriesTotal, 4)
        XCTAssertEqual(engine.seriesRemaining, 4)

        engine.removeSeries()
        XCTAssertEqual(engine.seriesTotal, 3)
        XCTAssertEqual(engine.seriesRemaining, 3)
    }

    func testDerniereDureeMemorisee() {
        engine.setMode(.pause)
        engine.startSession(series: 2)

        engine.validateSet()
        engine.pickDuration(90)

        XCTAssertEqual(engine.lastPause, 90)
        XCTAssertEqual(engine.defaultDuration(), 90)
    }

    func testFormatTime() {
        XCTAssertEqual(formatTime(45), "45s")
        XCTAssertEqual(formatTime(60), "1:00")
        XCTAssertEqual(formatTime(90), "1:30")
        XCTAssertEqual(formatTime(125), "2:05")
    }

    // =========================================================================
    //  Écoulement du temps & fin de phase
    // =========================================================================
    func testPauseSeuleSeanceComplete() {
        engine.setMode(.pause)
        engine.startSession(series: 2)

        // Série 1
        engine.validateSet()
        engine.pickDuration(60)
        elapse(59)
        XCTAssertEqual(engine.step, .timer, "pas encore fini")
        elapse(2) // 61 s écoulées → phase terminée
        XCTAssertEqual(engine.step, .doSet, "retour à « Fais ta série »")
        XCTAssertEqual(engine.tlBars, 1, "la barre de pause se remplit")
        XCTAssertTrue(events.contains(.phaseCompleted(.pause)))

        // Série 2 (dernière) : la fin de la pause clôt la séance
        engine.validateSet()
        XCTAssertEqual(engine.seriesRemaining, 0)
        engine.pickDuration(30)
        elapse(31)
        XCTAssertEqual(engine.step, .done)
        XCTAssertTrue(events.contains(.sessionFinished))
    }

    func testRemainingDeriveDeLHorloge() {
        engine.setMode(.pause)
        engine.startSession(series: 2) // il restera une série → retour doSet
        engine.validateSet()
        engine.pickDuration(120)

        clock.advance(45)
        XCTAssertEqual(engine.remaining(), 75.0, accuracy: 0.001)
        XCTAssertEqual(engine.progress(), 0.375, accuracy: 0.001)

        // Longue suspension (poignet baissé) : le restant reste juste.
        clock.advance(200)
        XCTAssertEqual(engine.remaining(), 0)
        engine.tick()
        XCTAssertEqual(engine.step, .doSet)
    }

    func testPauseRepriseConserveLeRestant() {
        engine.setMode(.pause)
        engine.startSession(series: 2) // il restera une série → retour doSet
        engine.validateSet()
        engine.pickDuration(60)

        clock.advance(20)
        engine.pauseCountdown()
        XCTAssertEqual(engine.remaining(), 40.0, accuracy: 0.001)
        XCTAssertTrue(events.contains(.countdownInvalidated))

        // Le temps passe pendant la pause : le restant ne bouge pas.
        clock.advance(100)
        XCTAssertEqual(engine.remaining(), 40.0, accuracy: 0.001)

        engine.togglePause() // reprise
        XCTAssertTrue(engine.running)
        clock.advance(39)
        XCTAssertEqual(engine.step, .timer)
        elapse(2)
        XCTAssertEqual(engine.step, .doSet)
    }

    func testResetPhaseRepartDeLaDuree() {
        engine.setMode(.pause)
        engine.startSession(series: 2)
        engine.validateSet()
        engine.pickDuration(60)

        clock.advance(30)
        engine.resetPhase()
        XCTAssertEqual(engine.remaining(), 60.0, accuracy: 0.001)
        XCTAssertTrue(engine.running)
    }

    func testSkipAgitCommeUneFinNaturelle() {
        engine.setMode(.pause)
        engine.startSession(series: 2)
        engine.validateSet()
        engine.pickDuration(60)

        engine.skip()
        XCTAssertEqual(engine.step, .doSet)
        XCTAssertEqual(engine.tlBars, 1)
        XCTAssertFalse(events.contains(.phaseCompleted(.pause)),
                       "un skip n'émet pas de phaseCompleted (pas d'haptique)")
    }

    // =========================================================================
    //  Effort + Pause (enchaînement auto)
    // =========================================================================
    func testEffortAutoEnchaine() {
        engine.setMode(.effort)
        engine.effortAuto = true
        engine.effortSel = 30
        engine.restSel = 45
        engine.startSession(series: 2)

        // Démarre directement sur l'effort.
        XCTAssertEqual(engine.step, .timer)
        XCTAssertEqual(engine.phase, .effort)
        XCTAssertEqual(engine.remaining(), 30.0, accuracy: 0.001)

        elapse(31) // fin de l'effort → pause auto
        XCTAssertEqual(engine.phase, .pause)
        XCTAssertTrue(engine.running)
        XCTAssertEqual(engine.remaining(), 45.0, accuracy: 0.001)

        elapse(46) // fin de la pause → série 1 faite, effort 2 enchaîné
        XCTAssertEqual(engine.seriesRemaining, 1)
        XCTAssertEqual(engine.phase, .effort)
        XCTAssertEqual(engine.currentSeries, 2, "on attaque la série 2")
        XCTAssertEqual(engine.tlDots, 1, "la timeline suit le compteur en mode effort")

        elapse(31) // effort 2 → pause 2
        elapse(46) // pause 2 → séance finie
        XCTAssertEqual(engine.seriesRemaining, 0)
        XCTAssertEqual(engine.step, .done)
    }

    // =========================================================================
    //  Effort + Pause (étape par étape)
    // =========================================================================
    func testEffortManuelPasseParLeChoixDeDuree() {
        engine.setMode(.effort)
        engine.effortAuto = false
        engine.startSession(series: 1)

        XCTAssertEqual(engine.step, .duration)
        XCTAssertEqual(engine.pickingPhase, .effort)

        engine.pickDuration(30) // effort
        XCTAssertEqual(engine.phase, .effort)
        elapse(31) // fin effort → choix de la pause
        XCTAssertEqual(engine.step, .duration)
        XCTAssertEqual(engine.pickingPhase, .pause)

        engine.pickDuration(45) // pause
        elapse(46) // fin pause, dernière série → done
        XCTAssertEqual(engine.step, .done)
    }

    // =========================================================================
    //  Événements & divers
    // =========================================================================
    func testPhaseStartedPorteLaBonneEcheance() {
        engine.setMode(.pause)
        engine.startSession(series: 1)
        engine.validateSet()
        engine.pickDuration(90)

        guard case let .phaseStarted(phase, endDate) = events.last else {
            return XCTFail("phaseStarted attendu, reçu \(String(describing: events.last))")
        }
        XCTAssertEqual(phase, .pause)
        XCTAssertEqual(endDate.timeIntervalSince(clock.current), 90.0, accuracy: 0.001)
    }

    func testQuitRemetAuRepos() {
        engine.setMode(.pause)
        engine.startSession(series: 3)
        engine.validateSet()
        engine.pickDuration(60)

        engine.quit()
        XCTAssertEqual(engine.step, .idle)
        XCTAssertFalse(engine.running)
        XCTAssertEqual(engine.remaining(), 0)
    }

    func testRestartRepartSurLeMemeTotal()
    {
        engine.setMode(.pause)
        engine.startSession(series: 4)
        engine.validateSet()
        engine.pickDuration(30)
        engine.skip()

        engine.restart()
        XCTAssertEqual(engine.seriesTotal, 4)
        XCTAssertEqual(engine.seriesRemaining, 4)
        XCTAssertEqual(engine.tlDots, 0)
        XCTAssertEqual(engine.step, .doSet)
    }

    func testContexteTelephone() {
        engine.applyPhoneContext(lastPause: 120, mode: .effort)
        XCTAssertEqual(engine.lastPause, 120)
        XCTAssertEqual(engine.mode, .effort)

        // Une durée hors liste est ignorée.
        engine.applyPhoneContext(lastPause: 37, mode: nil)
        XCTAssertEqual(engine.lastPause, 120)

        // En pleine séance, le mode n'est pas écrasé.
        engine.setMode(.pause)
        engine.startSession(series: 2)
        engine.applyPhoneContext(lastPause: nil, mode: .effort)
        XCTAssertEqual(engine.mode, .pause)
    }
}
