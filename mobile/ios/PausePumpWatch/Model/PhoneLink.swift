import Foundation
import WatchConnectivity

// Liaison WatchConnectivity côté montre. L'iPhone pousse sa config via
// `updateApplicationContext` ; la montre la lit ici et la remonte au
// modèle (toujours sur le main thread). La montre reste 100 % autonome :
// ce contexte est un simple « best effort » (dernière pause, mode…).

/// Config reçue de l'iPhone (toutes les clés sont optionnelles).
struct PhoneContext {
    var lastPause: Int?
    var mode: String?      // "pause" | "effort"
    var alarm: String?     // nom du son côté téléphone (non utilisé sur la montre)
    var vibrate: Bool?
    var sound: Bool?
    var volume: Double?
}

final class PhoneLink: NSObject, WCSessionDelegate {

    /// Callback (main thread) quand un contexte arrive du téléphone.
    var onContext: ((PhoneContext) -> Void)?

    /// À appeler une fois au démarrage de l'app.
    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        // Un contexte a pu être livré pendant que l'app était fermée :
        // on relit le dernier applicationContext reçu à l'activation.
        let stored = session.receivedApplicationContext
        if !stored.isEmpty { deliver(stored) }
    }

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        deliver(applicationContext)
    }

    // MARK: - Décodage

    private func deliver(_ dict: [String: Any]) {
        let ctx = PhoneContext(
            lastPause: dict["lastPause"] as? Int,
            mode: dict["mode"] as? String,
            alarm: dict["alarm"] as? String,
            vibrate: dict["vibrate"] as? Bool,
            sound: dict["sound"] as? Bool,
            volume: dict["volume"] as? Double
        )
        // Les callbacks WCSession arrivent sur une queue d'arrière-plan :
        // on repasse sur le main thread avant de toucher au modèle.
        DispatchQueue.main.async { [weak self] in
            self?.onContext?(ctx)
        }
    }
}
