import SwiftUI
#if canImport(WatchEngine)
import WatchEngine
#endif

// Choix de la durée — le cœur de l'UX montre : la DERNIÈRE durée utilisée
// s'affiche en très grand dès l'ouverture, un swipe gauche/droite fait
// défiler les autres durées (TabView paginée), un tap lance le décompte.

struct DurationPickView: View {
    @EnvironmentObject private var model: WatchSessionModel

    /// Index de la page affichée dans kDurations.
    @State private var selection = 0

    /// Couleur de la phase en cours de configuration.
    private var phaseColor: Color {
        model.pickingPhase == .pause ? PPColor.accent : PPColor.effort
    }

    private var title: String {
        if model.mode == .pause { return "Choisis ta pause" }
        return model.pickingPhase == .effort ? "💪 Effort — durée" : "😮‍💨 Pause — durée"
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundColor(PPColor.textDim)
                .padding(.top, 2)

            // Une durée par page, très grande, tap = lancer.
            TabView(selection: $selection) {
                ForEach(Array(kDurations.enumerated()), id: \.offset) { index, seconds in
                    Button {
                        model.pickDuration(seconds)
                    } label: {
                        Text(formatTime(Double(seconds)))
                            .font(.system(size: 46, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(phaseColor)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .tag(index)
                }
            }
            .tabViewStyle(.page)

            Text("tap pour lancer · swipe pour changer")
                .font(.system(size: 11))
                .foregroundColor(PPColor.textDim)
                .padding(.bottom, 2)
        }
        .onAppear {
            // Ouvre le picker directement sur la dernière durée utilisée.
            if let index = kDurations.firstIndex(of: model.defaultDuration()) {
                selection = index
            }
        }
    }
}
