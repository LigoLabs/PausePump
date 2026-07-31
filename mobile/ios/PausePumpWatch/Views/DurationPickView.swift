import SwiftUI
#if canImport(WatchEngine)
import WatchEngine
#endif

// Choix de la durée : grille de deux tuiles par ligne.
//
// C'était auparavant un TabView paginé (une durée plein écran, swipe pour
// changer) : illisible — le chiffre géant débordait sur le texte d'aide et
// rien ne montrait les autres durées. Une grille les rend toutes visibles
// d'un coup d'œil, et un tap lance directement le décompte.

struct DurationPickView: View {
    @EnvironmentObject private var model: WatchSessionModel

    /// Couleur de la phase en cours de configuration.
    private var phaseColor: Color {
        model.pickingPhase == .pause ? PPColor.accent : PPColor.effort
    }

    private var title: String {
        if model.mode == .pause { return "Choisis ton repos" }
        return model.pickingPhase == .effort ? "💪 Effort" : "😮‍💨 Repos"
    }

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: PPMetrics.s(5)),
         GridItem(.flexible(), spacing: PPMetrics.s(5))]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: PPMetrics.s(6)) {
                Text(title)
                    .font(.system(size: PPMetrics.s(13), weight: .semibold, design: .rounded))
                    .foregroundColor(PPColor.textDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                LazyVGrid(columns: columns, spacing: PPMetrics.s(5)) {
                    ForEach(model.durations, id: \.self) { seconds in
                        durationTile(seconds)
                    }
                }
            }
            .padding(.horizontal, PPMetrics.gutter)
            .padding(.bottom, 4)
        }
    }

    /// Une tuile de durée. Celle utilisée la dernière fois est cerclée pour
    /// que le geste le plus fréquent (relancer la même durée) se repère sans
    /// lire.
    private func durationTile(_ seconds: Int) -> some View {
        let isDefault = seconds == model.defaultDuration()
        return Button {
            model.pickDuration(seconds)
        } label: {
            Text(formatTime(Double(seconds)))
                .font(.system(size: PPMetrics.s(18), weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundColor(isDefault ? phaseColor : PPColor.text)
                .frame(maxWidth: .infinity, minHeight: PPMetrics.tileHeight)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(PPColor.bgElev2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(isDefault ? phaseColor : .clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}
