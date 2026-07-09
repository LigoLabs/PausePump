import SwiftUI
#if canImport(WatchEngine)
import WatchEngine
#endif

// Séance terminée : célébration + relance rapide.

struct DoneView: View {
    @EnvironmentObject private var model: WatchSessionModel

    /// « 3 séries bouclées 💪 » (singulier si une seule).
    private var recap: String {
        model.seriesTotal <= 1
            ? "1 série bouclée 💪"
            : "\(model.seriesTotal) séries bouclées 💪"
    }

    var body: some View {
        VStack(spacing: 4) {
            Spacer(minLength: 2)

            Text("🎉")
                .font(.system(size: 38))

            Text("Séance terminée !")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundColor(PPColor.text)
                .multilineTextAlignment(.center)

            Text(recap)
                .font(.footnote)
                .foregroundColor(PPColor.textDim)

            Spacer(minLength: 6)

            Button {
                model.restart()
            } label: {
                Text("Recommencer")
            }
            .buttonStyle(PPFilledButtonStyle(color: PPColor.accent, minHeight: 42))

            Button {
                model.quit()
            } label: {
                Text("Accueil")
                    .font(.footnote)
                    .foregroundColor(PPColor.textDim)
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }
}
