import SwiftUI
#if canImport(WatchEngine)
import WatchEngine
#endif

// « Fais ta série » (mode Repos seul) : un seul geste possible.
// Le bouton reste pleine largeur — c'est ça qui le rend facile à taper —
// mais sa hauteur est ramenée au gabarit commun.

struct DoSetView: View {
    @EnvironmentObject private var model: WatchSessionModel

    /// Ordinal français : 1 → « 1re », sinon « 2e », « 3e »…
    private var ordinal: String {
        model.currentSeries == 1 ? "1re" : "\(model.currentSeries)e"
    }

    var body: some View {
        VStack(spacing: PPMetrics.s(6)) {
            Spacer(minLength: 0)

            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: PPMetrics.s(26), weight: .semibold))
                .foregroundColor(PPColor.accent)

            // « Fais ta 2e série » — l'ordinal ressort en teal.
            (Text("Fais ta ")
                + Text(ordinal).foregroundColor(PPColor.accent)
                + Text(" série"))
                .font(.system(size: PPMetrics.s(17), weight: .bold, design: .rounded))
                .foregroundColor(PPColor.text)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            Text("Série \(model.currentSeries)/\(model.seriesTotal)")
                .font(.system(size: PPMetrics.s(11)))
                .foregroundColor(PPColor.textDim)

            Spacer(minLength: 0)

            Button {
                model.validateSet()
            } label: {
                Text("J'ai fait ma série")
            }
            .buttonStyle(PPFilledButtonStyle(color: PPColor.accent))
        }
        .padding(.horizontal, PPMetrics.gutter)
        .padding(.bottom, 2)
    }
}
