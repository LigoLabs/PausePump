import SwiftUI
#if canImport(WatchEngine)
import WatchEngine
#endif

// « Fais ta série » (mode Pause seule) : un seul geste possible, ultra
// facile à taper en salle — le bouton de validation occupe tout le bas.

struct DoSetView: View {
    @EnvironmentObject private var model: WatchSessionModel

    /// Ordinal français : 1 → « 1re », sinon « 2e », « 3e »…
    private var ordinal: String {
        model.currentSeries == 1 ? "1re" : "\(model.currentSeries)e"
    }

    var body: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 2)

            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(PPColor.accent)

            // « Fais ta 2e série » — l'ordinal ressort en teal.
            (Text("Fais ta ")
                + Text(ordinal).foregroundColor(PPColor.accent)
                + Text(" série"))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundColor(PPColor.text)
                .multilineTextAlignment(.center)

            Text("Série \(model.currentSeries)/\(model.seriesTotal)")
                .font(.caption2)
                .foregroundColor(PPColor.textDim)

            Spacer(minLength: 4)

            Button {
                model.validateSet()
            } label: {
                Text("J'ai fait ma série ✓")
            }
            .buttonStyle(PPFilledButtonStyle(color: PPColor.accent, minHeight: 52))
        }
        .padding(.horizontal, 4)
    }
}
