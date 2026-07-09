import Foundation
import SwiftUI
import WatchKit
import UserNotifications
#if canImport(WatchEngine)
import WatchEngine
#endif

// Modèle observable de la séance côté montre.
//
// Il possède le `WorkoutEngine` (machine à états pure, sans timer interne —
// voir mobile/watch_engine) et orchestre tout ce qui touche au système :
// haptiques, notification locale de fin de phase, persistance UserDefaults
// et contexte poussé par l'iPhone (PhoneLink).
//
// Règle : TOUTE action utilisateur passe par une méthode du modèle qui fait
// `objectWillChange.send()` PUIS mute le moteur — jamais le moteur en direct.

final class WatchSessionModel: NSObject, ObservableObject {

    private let engine = WorkoutEngine()
    private let phoneLink = PhoneLink()

    /// Identifiant de LA notification de fin de phase (une seule à la fois).
    private static let endNotificationId = "pp.phase-end"

    /// Clés de persistance (survivre au relancement de l'app).
    private enum Keys {
        static let lastPause = "pp.lastPause"
        static let mode = "pp.mode"
    }

    /// L'autorisation notifications n'est demandée qu'au premier démarrage
    /// de séance (pas au lancement de l'app : moins intrusif).
    private var didRequestNotifAuth = false

    override init() {
        super.init()

        engine.onEvent = { [weak self] event in self?.handle(event) }
        restoreConfig()

        // Délégué notifications : décider de la présentation au premier plan.
        UNUserNotificationCenter.current().delegate = self

        // Liaison iPhone : la config (dernière pause, mode…) arrive
        // en applicationContext, appliquée en best effort.
        phoneLink.onContext = { [weak self] ctx in self?.apply(ctx) }
        phoneLink.activate()
    }

    // =========================================================================
    //  Lecture — les vues lisent le moteur à travers le modèle
    // =========================================================================
    var step: EngineStep { engine.step }
    var mode: SessionMode { engine.mode }
    var phase: EnginePhase { engine.phase }
    var pickingPhase: EnginePhase { engine.pickingPhase }
    var seriesTotal: Int { engine.seriesTotal }
    var seriesRemaining: Int { engine.seriesRemaining }
    var currentSeries: Int { engine.currentSeries }
    var durationSec: Int { engine.durationSec }
    var running: Bool { engine.running }

    /// Temps restant (secondes) à l'instant donné — figé si le décompte est en pause.
    func remaining(at date: Date) -> Double { engine.remaining(at: date) }
    /// Progression 0…1 de la phase courante.
    func progress(at date: Date) -> Double { engine.progress(at: date) }
    /// Dernière durée utilisée pour la phase en cours (page initiale du picker).
    func defaultDuration() -> Int { engine.defaultDuration() }

    // =========================================================================
    //  Actions utilisateur — wrappers : notifier SwiftUI puis muter le moteur
    // =========================================================================
    func startSession(series: Int) {
        requestNotifAuthIfNeeded()
        objectWillChange.send()
        engine.startSession(series: series)
    }

    /// « J'ai fait ma série » (écran doSet).
    func validateSet() {
        objectWillChange.send()
        engine.validateSet()
    }

    /// Durée choisie dans le picker → lance le décompte.
    func pickDuration(_ seconds: Int) {
        objectWillChange.send()
        engine.pickDuration(seconds)
        persistConfig()
    }

    /// Play/pause du décompte.
    func togglePause() {
        objectWillChange.send()
        engine.togglePause()
    }

    /// Remet la phase courante à sa durée initiale.
    func resetPhase() {
        objectWillChange.send()
        engine.resetPhase()
    }

    /// ⏭ Suivante — même logique qu'une fin de phase naturelle.
    func skip() {
        objectWillChange.send()
        engine.skip()
    }

    /// Relance une séance identique (écran done).
    func restart() {
        objectWillChange.send()
        engine.restart()
    }

    /// Retour à l'accueil.
    func quit() {
        objectWillChange.send()
        engine.quit()
    }

    // =========================================================================
    //  Horloge
    // =========================================================================
    /// Appelé à intervalle régulier par la TimelineView du décompte.
    /// On ne réveille SwiftUI que si le moteur a réellement changé d'état
    /// pendant CE tick (décision atomique : comparer avant/après plutôt que
    /// ré-évaluer `remaining()` deux fois) — l'affichage du temps restant est
    /// déjà re-rendu par la TimelineView.
    func tick() {
        let stepBefore = engine.step
        let runningBefore = engine.running
        engine.tick()
        if engine.step != stepBefore || engine.running != runningBefore {
            objectWillChange.send()
        }
    }

    /// À l'activation de la scène (poignet levé, app relancée) : rattraper
    /// une phase arrivée à échéance pendant que l'app était suspendue.
    func sceneDidActivate() {
        tick()
    }

    // =========================================================================
    //  Événements du moteur → haptique + notifications
    // =========================================================================
    private func handle(_ event: EngineEvent) {
        switch event {
        case .phaseStarted(let phase, let endDate):
            // La notification locale garantit l'haptique de fin même si
            // l'app est suspendue (poignet baissé pendant la pause).
            scheduleEndNotification(for: phase, endDate: endDate)
            WKInterfaceDevice.current().play(.start)

        case .phaseCompleted:
            // L'app était active : l'haptique in-app suffit,
            // la notification ne doit pas doubler.
            cancelPendingNotifications()
            WKInterfaceDevice.current().play(.notification)

        case .countdownInvalidated:
            cancelPendingNotifications()

        case .sessionFinished:
            cancelPendingNotifications()
            WKInterfaceDevice.current().play(.success)
        }
    }

    // =========================================================================
    //  Notifications locales
    // =========================================================================
    private func requestNotifAuthIfNeeded() {
        guard !didRequestNotifAuth else { return }
        didRequestNotifAuth = true
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func scheduleEndNotification(for phase: EnginePhase, endDate: Date) {
        let center = UNUserNotificationCenter.current()
        // Une seule notification de fin à la fois : on remplace la précédente.
        center.removePendingNotificationRequests(withIdentifiers: [Self.endNotificationId])

        let interval = endDate.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "PausePump ⏱️"
        content.body = phase == .pause
            ? "Pause terminée • à toi de jouer !"
            : "Effort terminé 💪"
        content.sound = .default
        // Fin de pause = time-sensitive : doit percer les modes focus.
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: Self.endNotificationId,
                                            content: content,
                                            trigger: trigger)
        center.add(request)
    }

    private func cancelPendingNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.endNotificationId])
        // Une notification déjà livrée (fin de phase au poignet baissé) ne
        // doit pas traîner dans le centre de notifications une fois traitée.
        center.removeDeliveredNotifications(withIdentifiers: [Self.endNotificationId])
    }

    // =========================================================================
    //  Contexte iPhone + persistance
    // =========================================================================
    private func apply(_ ctx: PhoneContext) {
        objectWillChange.send()
        engine.applyPhoneContext(
            lastPause: ctx.lastPause,
            mode: ctx.mode.flatMap(SessionMode.init(rawValue:))
        )
        persistConfig()
        // alarm / vibrate / sound / volume : réglages du téléphone sans
        // équivalent montre pour l'instant (la montre utilise l'haptique
        // système) — ignorés volontairement.
    }

    private func persistConfig() {
        let defaults = UserDefaults.standard
        defaults.set(engine.lastPause, forKey: Keys.lastPause)
        defaults.set(engine.mode.rawValue, forKey: Keys.mode)
    }

    private func restoreConfig() {
        let defaults = UserDefaults.standard
        let pause = defaults.integer(forKey: Keys.lastPause) // 0 si absent
        let mode = defaults.string(forKey: Keys.mode).flatMap(SessionMode.init(rawValue:))
        // `applyPhoneContext` valide la durée (kDurations) et n'applique
        // le mode que hors séance — exactement ce qu'on veut au relancement.
        engine.applyPhoneContext(lastPause: pause > 0 ? pause : nil, mode: mode)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension WatchSessionModel: UNUserNotificationCenterDelegate {

    /// `willPresent` n'est appelé que si l'app est au premier plan :
    /// dans ce cas l'haptique in-app (`.phaseCompleted`) suffit,
    /// on ne présente donc rien du tout.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                    @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([])
    }
}
