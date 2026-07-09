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
        }
        .animation(.easeInOut(duration: 0.25), value: model.step)
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
