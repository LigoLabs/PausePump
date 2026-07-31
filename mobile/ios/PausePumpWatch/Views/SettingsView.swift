import SwiftUI
#if canImport(WatchEngine)
import WatchEngine
#endif

// Réglages de la montre : gestion des durées proposées au sélecteur.
//
// Présenté en `sheet` depuis l'accueil, et NON comme une étape du moteur :
// `EngineStep` décrit la machine à états de la séance, dupliquée à
// l'identique en Dart et en JS (voir CLAUDE.md). Y ajouter un cas
// « réglages » propre à la montre la ferait diverger pour rien.

struct SettingsView: View {
    @EnvironmentObject private var model: WatchSessionModel
    @Environment(\.dismiss) private var dismiss

    /// Durée en cours de composition, en secondes.
    @State private var draft = 60

    /// Pas d'incrément : 5 s en dessous d'une minute, 15 s au-delà —
    /// personne ne règle un repos de 4 min à 5 s près.
    private var step: Int { draft < 60 ? 5 : 15 }

    private var canAdd: Bool { !model.durations.contains(draft) }

    var body: some View {
        ScrollView {
            VStack(spacing: PPMetrics.s(10)) {
                composer
                Divider().background(PPColor.track)
                existingList
                resetButton
            }
            .padding(.horizontal, PPMetrics.gutter)
            .padding(.bottom, 6)
        }
    }

    // — Composer une nouvelle durée —
    private var composer: some View {
        VStack(spacing: PPMetrics.s(6)) {
            Text("Ajouter une durée")
                .font(.system(size: PPMetrics.s(13), weight: .semibold, design: .rounded))
                .foregroundColor(PPColor.textDim)

            HStack {
                stepButton("minus") {
                    draft = max(draft - step, kMinDuration)
                }
                Spacer(minLength: 2)
                Text(formatTime(Double(draft)))
                    .font(.system(size: PPMetrics.s(26), weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundColor(PPColor.text)
                Spacer(minLength: 2)
                stepButton("plus") {
                    // Le pas dépend de la valeur COURANTE : sans ça, passer
                    // 55 → 60 puis + rendrait 65 au lieu de 75.
                    draft = min(draft + (draft < 60 ? 5 : 15), kMaxDuration)
                }
            }

            Button {
                model.addDuration(draft)
            } label: {
                Text(canAdd ? "Ajouter" : "Déjà dans la liste")
            }
            .buttonStyle(PPFilledButtonStyle(color: canAdd ? PPColor.accent : PPColor.bgElev2))
            .disabled(!canAdd)
        }
    }

    // — Durées déjà proposées ; tap sur la croix pour retirer —
    private var existingList: some View {
        VStack(spacing: PPMetrics.s(4)) {
            Text("Durées proposées")
                .font(.system(size: PPMetrics.s(13), weight: .semibold, design: .rounded))
                .foregroundColor(PPColor.textDim)

            ForEach(model.durations, id: \.self) { seconds in
                HStack(spacing: PPMetrics.s(6)) {
                    Text(formatTime(Double(seconds)))
                        .font(.system(size: PPMetrics.s(15), weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(PPColor.text)
                    Spacer()
                    if model.durations.count > 1 {
                        Button {
                            model.removeDuration(seconds)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: PPMetrics.s(11), weight: .bold))
                                .foregroundColor(PPColor.danger)
                                .frame(width: PPMetrics.s(26), height: PPMetrics.s(26))
                                .background(Circle().fill(PPColor.bgElev2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, PPMetrics.s(8))
                .padding(.vertical, PPMetrics.s(2))
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(PPColor.bgElev)
                )
            }
        }
    }

    private var resetButton: some View {
        Button {
            model.resetDurations()
        } label: {
            Text("Réinitialiser")
        }
        .buttonStyle(PPQuietButtonStyle())
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        let d = PPMetrics.s(30)
        return Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: PPMetrics.s(13), weight: .bold))
                .foregroundColor(PPColor.text)
                .frame(width: d, height: d)
                .background(Circle().fill(PPColor.bgElev2))
        }
        .buttonStyle(.plain)
    }
}
