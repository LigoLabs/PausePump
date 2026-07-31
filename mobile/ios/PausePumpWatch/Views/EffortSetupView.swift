import SwiftUI
#if canImport(WatchEngine)
import WatchEngine
#endif

// Réglage de l'enchaînement, en mode Effort + Repos — présenté APRÈS le GO,
// comme l'écran de configuration de l'app iPhone (lib/screens/session_screen.dart).
//
// Deux cas :
//   • Enchaîner        → on fixe ici la durée d'effort ET celle de repos,
//                        puis tout se déroule sans intervention.
//   • À chaque étape   → rien à régler, le moteur demandera une durée avant
//                        chaque phase.

struct EffortSetupView: View {
    @EnvironmentObject private var model: WatchSessionModel
    @Environment(\.dismiss) private var dismiss

    /// Nombre de séries choisi sur l'accueil, transmis tel quel.
    let series: Int

    @State private var auto = true
    @State private var effort = 60
    @State private var rest = 60

    var body: some View {
        ScrollView {
            VStack(spacing: PPMetrics.s(7)) {
                chainPicker

                Text(auto
                     ? "Tu règles l'effort et le repos, puis ça enchaîne tout seul."
                     : "Tu choisiras la durée à chaque étape : d'abord l'effort, puis le repos.")
                    .font(.system(size: PPMetrics.s(11)))
                    .foregroundColor(PPColor.textDim)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                // Les durées ne servent qu'en enchaînement auto — en étape par
                // étape elles seraient écrasées par les choix successifs.
                if auto {
                    durationRow("💪 Effort", value: $effort, tint: PPColor.effort)
                    durationRow("😮‍💨 Repos", value: $rest, tint: PPColor.accent)
                }

                Button {
                    model.startEffortSession(series: series,
                                             auto: auto,
                                             effort: effort,
                                             rest: rest)
                    dismiss()
                } label: {
                    Text("Démarrer ▶")
                }
                .buttonStyle(PPFilledButtonStyle(color: PPColor.accent))
            }
            .padding(.horizontal, PPMetrics.gutter)
            .padding(.bottom, 6)
        }
        .onAppear {
            // Reprend les derniers réglages connus.
            auto = model.effortAuto
            effort = nearestDuration(model.effortSel)
            rest = nearestDuration(model.restSel)
        }
    }

    // — Enchaîner / À chaque étape —
    private var chainPicker: some View {
        HStack(spacing: PPMetrics.s(5)) {
            chainPill("Enchaîner", on: true)
            chainPill("À chaque étape", on: false)
        }
    }

    private func chainPill(_ label: String, on value: Bool) -> some View {
        let selected = auto == value
        return Button {
            auto = value
        } label: {
            Text(label)
                .font(.system(size: PPMetrics.s(11), weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundColor(selected ? PPColor.bg : PPColor.textDim)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, minHeight: PPMetrics.s(26))
                .background(Capsule().fill(selected ? PPColor.accent : PPColor.bgElev2))
        }
        .buttonStyle(.plain)
    }

    // — Une durée réglable, qui parcourt la liste des durées proposées —
    private func durationRow(_ label: String,
                             value: Binding<Int>,
                             tint: Color) -> some View {
        VStack(spacing: PPMetrics.s(2)) {
            Text(label)
                .font(.system(size: PPMetrics.s(11), weight: .semibold, design: .rounded))
                .foregroundColor(PPColor.textDim)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: PPMetrics.s(5)) {
                stepButton("minus") { value.wrappedValue = shift(value.wrappedValue, by: -1) }
                Text(formatTime(Double(value.wrappedValue)))
                    .font(.system(size: PPMetrics.s(17), weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundColor(tint)
                    .frame(maxWidth: .infinity)
                stepButton("plus") { value.wrappedValue = shift(value.wrappedValue, by: 1) }
            }
        }
        .padding(.vertical, PPMetrics.s(3))
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous).fill(PPColor.bgElev)
        )
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        let d = PPMetrics.s(26)
        return Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: PPMetrics.s(11), weight: .bold))
                .foregroundColor(PPColor.text)
                .frame(width: d, height: d)
                .background(Circle().fill(PPColor.bgElev2))
        }
        .buttonStyle(.plain)
    }

    // — Navigation dans la liste des durées proposées (réglages compris) —

    /// Durée proposée la plus proche : `effortSel` peut valoir une valeur
    /// retirée depuis des réglages, il ne faut pas rester bloqué dessus.
    private func nearestDuration(_ seconds: Int) -> Int {
        model.durations.min { abs($0 - seconds) < abs($1 - seconds) } ?? seconds
    }

    private func shift(_ seconds: Int, by delta: Int) -> Int {
        let list = model.durations
        guard let index = list.firstIndex(of: seconds) else { return nearestDuration(seconds) }
        return list[min(max(index + delta, 0), list.count - 1)]
    }
}
