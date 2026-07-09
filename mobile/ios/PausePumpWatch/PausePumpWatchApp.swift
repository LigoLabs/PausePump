import SwiftUI
#if canImport(WatchEngine)
import WatchEngine
#endif

// Point d'entrée de l'app watchOS PausePump (autonome, watchOS 9+).

@main
struct PausePumpWatchApp: App {

    /// Modèle unique de l'app, partagé avec toutes les vues.
    @StateObject private var model = WatchSessionModel()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
        }
        // Au retour au premier plan : rattraper une phase échue pendant
        // la suspension (le moteur dérive tout de `endDate`, jamais d'un
        // compteur décrémenté, donc un simple tick suffit).
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                model.sceneDidActivate()
            }
        }
    }
}
