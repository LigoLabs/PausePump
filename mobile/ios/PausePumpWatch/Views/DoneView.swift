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
        VStack(spacing: PPMetrics.s(4)) {
            Spacer(minLength: 0)

            Text("🎉")
                .font(.system(size: PPMetrics.s(30)))

            Text("Séance terminée !")
                .font(.system(size: PPMetrics.s(17), weight: .bold, design: .rounded))
                .foregroundColor(PPColor.text)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            Text(recap)
                .font(.system(size: PPMetrics.s(12)))
                .foregroundColor(PPColor.textDim)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)

            Button {
                model.restart()
            } label: {
                Text("Recommencer")
            }
            .buttonStyle(PPFilledButtonStyle(color: PPColor.accent))

            Button {
                model.quit()
            } label: {
                Text("Accueil")
            }
            .buttonStyle(PPQuietButtonStyle(minHeight: PPMetrics.s(30)))
        }
        .padding(.horizontal, PPMetrics.gutter)
        .padding(.bottom, 2)
    }
}
