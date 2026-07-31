import SwiftUI
#if canImport(WatchEngine)
import WatchEngine
#endif

// Routeur d'écrans : reflète `engine.step` (machine à états du moteur).
// Même découpage que les « views » du web (setup/duration/doset/timer/done).

struct RootView: View {
    @EnvironmentObject private var model: WatchSessionModel

    var body: some View {
        ZStack {
            // Fond de marque partout (le noir pur de watchOS est remplacé
            // par le bleu-nuit PausePump).
            PPColor.bg.ignoresSafeArea()

            content
                .transition(.opacity)

            // Retour à l'accueil, disponible à TOUT moment d'une séance.
            // En surimpression dans le coin haut-gauche (le coin haut-droit
            // est occupé par l'heure système) : il ne prend aucune place dans
            // la mise en page des écrans, déjà très contrainte.
            if showsHomeButton {
                PPCornerButton(symbol: "house.fill") { model.quit() }
                    .ppTopLeftCorner()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.step)
    }

    /// Pas d'accueil sur l'accueil, ni sur l'écran de fin qui a déjà son
    /// propre bouton « Accueil » en toutes lettres.
    private var showsHomeButton: Bool {
        switch model.step {
        case .idle, .done: return false
        case .doSet, .duration, .timer: return true
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.step {
        case .idle:
            StartView()
        case .doSet:
            DoSetView()
        case .duration:
            DurationPickView()
        case .timer:
            TimerView()
        case .done:
            DoneView()
        }
    }
}
