import Flutter
import Foundation
import WatchConnectivity

/// Pont natif du canal « pausepump/watch_sync » : pousse la configuration
/// (dernière pause choisie, mode, sons/vibration…) vers l'Apple Watch via
/// `updateApplicationContext`. Best effort : la montre fait tourner sa séance
/// en autonomie et relit le dernier contexte à sa prochaine activation.
final class WatchSyncBridge: NSObject, WCSessionDelegate {

    /// Instance gardée vivante : `WCSession.delegate` est une référence faible.
    private static var shared: WatchSyncBridge?

    /// Contexte reçu avant la fin de l'activation de la session : on le
    /// mémorise pour le pousser dès `activationDidComplete`.
    private var pendingContext: [String: Any]?

    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = WatchSyncBridge()
        shared = instance
        let channel = FlutterMethodChannel(
            name: "pausepump/watch_sync",
            binaryMessenger: registrar.messenger()
        )
        channel.setMethodCallHandler { call, result in
            instance.handle(call)
            // Fire-and-forget côté Dart : jamais d'erreur remontée à Flutter.
            result(nil)
        }
        instance.activateSession()
    }

    private func activateSession() {
        // Pas de montre appairable (iPad…) → no-op.
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Dispatch des messages Dart

    private func handle(_ call: FlutterMethodCall) {
        guard call.method == "updateContext",
              WCSession.isSupported(),
              let dict = call.arguments as? [String: Any] else { return }

        let session = WCSession.default
        guard session.activationState == .activated else {
            // Session pas encore prête : on garde le dernier contexte sous le
            // coude, il partira dans `activationDidComplete`.
            pendingContext = dict
            return
        }
        // Peut échouer (montre non appairée, app watch absente…) : avalé.
        try? session.updateApplicationContext(dict)
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        // Retour sur le main thread : `pendingContext` n'est touché que là.
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let dict = self.pendingContext else { return }
            self.pendingContext = nil
            try? session.updateApplicationContext(dict)
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        // Transition vers un changement de montre : rien à faire.
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // Après un changement de montre appairée, il faut réactiver la session
        // pour continuer à pousser le contexte vers la nouvelle montre.
        session.activate()
    }
}
