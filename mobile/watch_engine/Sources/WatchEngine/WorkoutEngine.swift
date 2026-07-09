import Foundation

// Port Swift de la machine à états de `lib/state/timer_controller.dart`
// (elle-même port de `advancePhase` de la version web). Toute modification de
// la logique de transition doit rester alignée sur ces deux implémentations.

/// Durées de timer proposées (secondes) — mêmes valeurs que `kDurations` (Dart).
public let kDurations: [Int] = [30, 45, 60, 90, 120, 150, 180, 300]

/// Choix du nombre de séries — mêmes valeurs que `kSeriesChoices` (Dart).
public let kSeriesChoices: [Int] = [1, 2, 3, 4, 5, 6]

/// Mode de séance.
public enum SessionMode: String, Codable, Sendable {
    case pause, effort
}

/// Phase d'un décompte.
public enum EnginePhase: String, Codable, Sendable {
    case pause, effort
}

/// Étape courante à l'écran.
public enum EngineStep: Equatable, Sendable {
    case idle       // pas de séance (écran d'accueil montre)
    case duration   // choix de la durée
    case doSet      // « Fais ta série »
    case timer      // décompte en cours
    case done       // séance terminée
}

/// Événements discrets émis par le moteur (haptique, notifications…).
public enum EngineEvent: Equatable, Sendable {
    /// Une phase démarre : planifier la notification/haptique de fin à `endDate`.
    case phaseStarted(EnginePhase, endDate: Date)
    /// La phase s'est terminée naturellement (temps écoulé) → haptique.
    case phaseCompleted(EnginePhase)
    /// Le décompte est suspendu/repris/abandonné → annuler la notification.
    case countdownInvalidated
    /// La séance est finie.
    case sessionFinished
}

/// Machine à états d'une séance. Aucun timer interne : l'UI appelle
/// [tick] régulièrement (TimelineView) et le temps est injectable (`now`)
/// pour les tests. Tous les instants sont dérivés de `endDate`, jamais d'un
/// compteur décrémenté — le décompte reste juste même si l'app est suspendue.
public final class WorkoutEngine {

    public init(now: @escaping () -> Date = { Date() }) {
        self.now = now
    }

    /// Horloge injectable (tests).
    public var now: () -> Date

    /// Événements discrets (notifications, haptique).
    public var onEvent: ((EngineEvent) -> Void)?

    // ---- Config ----
    public private(set) var mode: SessionMode = .pause
    public var effortAuto = true
    /// Écran « Fais ta série » (mode Pause seule) — toujours actif sur la montre.
    public var doSetScreen = true

    public private(set) var lastPause = 60
    public var effortSel = 60
    public var restSel = 60

    // ---- État de séance ----
    public private(set) var step: EngineStep = .idle
    public private(set) var phase: EnginePhase = .pause
    private var pickPhase: EnginePhase = .pause

    public private(set) var seriesTotal = 0
    public private(set) var seriesRemaining = 0

    // ---- Timeline (parité avec tlDots/tlBars du Dart) ----
    public private(set) var tlDots = 0
    public private(set) var tlBars = 0

    // ---- Décompte ----
    public private(set) var durationSec = 0
    public private(set) var running = false
    public private(set) var endDate: Date?
    /// Temps restant figé quand le décompte est en pause.
    public private(set) var pausedRemaining: Double?

    public var currentSeries: Int {
        let total = seriesTotal == 0 ? 1 : seriesTotal
        // Mode pause : les points suivent la validation des séries (tlDots).
        // Mode effort : dérivé du compteur (parité avec le web, js/app.js).
        let raw = mode == .effort ? total - seriesRemaining + 1 : tlDots + 1
        return min(max(raw, 1), total)
    }

    /// Temps restant (secondes) à l'instant [date].
    public func remaining(at date: Date? = nil) -> Double {
        if let frozen = pausedRemaining { return frozen }
        guard let end = endDate else { return 0 }
        return max(0, end.timeIntervalSince(date ?? now()))
    }

    /// Progression 0…1 de la phase courante (1 = terminé).
    public func progress(at date: Date? = nil) -> Double {
        guard durationSec > 0 else { return 0 }
        return min(max(1 - remaining(at: date) / Double(durationSec), 0), 1)
    }

    // =========================================================================
    //  Démarrage
    // =========================================================================
    public func setMode(_ m: SessionMode) {
        mode = m
    }

    public func startSession(series: Int) {
        seriesTotal = series
        seriesRemaining = series
        tlDots = 0
        tlBars = 0
        pausedRemaining = nil
        endDate = nil
        running = false

        if mode == .pause {
            if doSetScreen { showDoSet() } else { showDurationPick(.pause) }
        } else if effortAuto {
            startPhase(.effort, duration: effortSel)
        } else {
            showDurationPick(.effort)
        }
    }

    // =========================================================================
    //  Validation d'une série / choix de durée
    // =========================================================================
    /// « J'ai fait ma série » (Pause seule) : compteur −1 dès la validation.
    public func validateSet() {
        guard step == .doSet else { return }
        tlDots = min(tlDots + 1, seriesTotal)
        adjustSeries(-1)
        showDurationPick(.pause)
    }

    public func pickDuration(_ seconds: Int) {
        if mode == .pause {
            lastPause = seconds
            if !doSetScreen {
                tlDots = min(tlDots + 1, seriesTotal)
                adjustSeries(-1)
            }
            startPhase(.pause, duration: seconds)
            return
        }
        // Effort + Pause, étape par étape.
        if pickPhase == .effort {
            effortSel = seconds
            startPhase(.effort, duration: seconds)
        } else {
            restSel = seconds
            startPhase(.pause, duration: seconds)
        }
    }

    /// Dernière durée par défaut pour la phase en cours (page initiale du picker).
    public func defaultDuration() -> Int {
        if mode == .pause { return lastPause }
        return pickPhase == .effort ? effortSel : restSel
    }

    /// Phase que le picker est en train de configurer.
    public var pickingPhase: EnginePhase { mode == .pause ? .pause : pickPhase }

    // =========================================================================
    //  Minuteur
    // =========================================================================
    private func startPhase(_ p: EnginePhase, duration: Int) {
        phase = p
        durationSec = duration
        pausedRemaining = nil
        step = .timer
        resume(remainingSeconds: Double(duration))
    }

    private func resume(remainingSeconds: Double) {
        running = true
        pausedRemaining = nil
        let end = now().addingTimeInterval(remainingSeconds)
        endDate = end
        onEvent?(.phaseStarted(phase, endDate: end))
    }

    public func pauseCountdown() {
        guard running else { return }
        pausedRemaining = remaining()
        running = false
        onEvent?(.countdownInvalidated)
    }

    public func togglePause() {
        if running {
            pauseCountdown()
        } else if step == .timer {
            resume(remainingSeconds: pausedRemaining ?? Double(durationSec))
        }
    }

    public func resetPhase() {
        guard step == .timer else { return }
        if running {
            resume(remainingSeconds: Double(durationSec))
        } else {
            pausedRemaining = Double(durationSec)
        }
    }

    /// À appeler régulièrement (TimelineView / réactivation de l'app) :
    /// fait avancer la machine si la phase est arrivée à échéance.
    public func tick() {
        guard running, step == .timer, remaining() <= 0 else { return }
        running = false
        endDate = nil
        onEvent?(.phaseCompleted(phase))
        advancePhase()
    }

    /// ⏭ Suivante : même logique qu'une fin de phase naturelle.
    public func skip() {
        guard step == .timer else { return }
        running = false
        endDate = nil
        pausedRemaining = nil
        onEvent?(.countdownInvalidated)
        advancePhase()
    }

    // =========================================================================
    //  Transition de phase — port fidèle de `advancePhase`
    // =========================================================================
    private func advancePhase() {
        var sessionEnd = false
        var autoNext: EnginePhase?
        var manualNext: EnginePhase?

        if mode == .pause {
            tlBars = tlDots // la pause est finie → barre pleine
            sessionEnd = seriesRemaining <= 0
        } else if effortAuto {
            if phase == .effort {
                autoNext = .pause
            } else {
                adjustSeries(-1)
                syncEffortTimeline()
                sessionEnd = seriesRemaining <= 0
                if !sessionEnd { autoNext = .effort }
            }
        } else {
            if phase == .effort {
                manualNext = .pause
            } else {
                adjustSeries(-1)
                syncEffortTimeline()
                sessionEnd = seriesRemaining <= 0
                if !sessionEnd { manualNext = .effort }
            }
        }

        if sessionEnd {
            finishSession()
            return
        }
        if let next = autoNext {
            startPhase(next, duration: next == .pause ? restSel : effortSel)
            return
        }
        if let next = manualNext {
            showDurationPick(next)
        } else if doSetScreen {
            showDoSet()
        } else {
            showDurationPick(.pause)
        }
    }

    private func finishSession() {
        running = false
        endDate = nil
        pausedRemaining = nil
        step = .done
        onEvent?(.sessionFinished)
    }

    /// Relance une séance avec le même total (ajustements +/- inclus) —
    /// choix assumé, léger écart avec le web qui repart de la sélection
    /// d'origine ; même sémantique que l'app mobile Dart.
    public func restart() {
        startSession(series: seriesTotal)
    }

    public func quit() {
        running = false
        endDate = nil
        pausedRemaining = nil
        step = .idle
        onEvent?(.countdownInvalidated)
    }

    // =========================================================================
    //  Compteur de séries
    // =========================================================================
    private func adjustSeries(_ delta: Int) {
        seriesRemaining = max(seriesRemaining + delta, 0)
    }

    /// Mode effort : la timeline suit le compteur (une série = effort + pause).
    private func syncEffortTimeline() {
        tlDots = max(seriesTotal - seriesRemaining, 0)
        tlBars = tlDots
    }

    public func addSeries() {
        seriesTotal += 1
        adjustSeries(1)
    }

    public func removeSeries() {
        guard seriesRemaining > 0 else { return }
        seriesTotal = max(seriesTotal - 1, 1)
        adjustSeries(-1)
    }

    // =========================================================================
    //  Contexte téléphone (WatchConnectivity)
    // =========================================================================
    /// Applique le contexte poussé par l'iPhone (best effort, hors séance).
    public func applyPhoneContext(lastPause: Int?, mode: SessionMode?) {
        if let p = lastPause, kDurations.contains(p) { self.lastPause = p }
        if let m = mode, step == .idle { self.mode = m }
    }

    // ---- Helpers privés ----
    private func showDoSet() {
        step = .doSet
    }

    private func showDurationPick(_ forPhase: EnginePhase) {
        pickPhase = forPhase
        step = .duration
    }
}

/// « 45s » / « 1:30 » — même format que `formatTime` (Dart).
public func formatTime(_ totalSeconds: Double) -> String {
    let s = max(0, Int(totalSeconds.rounded()))
    let m = s / 60
    let sec = s % 60
    if m == 0 { return "\(sec)s" }
    return String(format: "%d:%02d", m, sec)
}
