import SwiftUI
#if canImport(WatchEngine)
import WatchEngine
#endif

// Accueil : logo, mode courant (piloté par l'iPhone), nombre de séries
// et gros bouton de départ.

struct StartView: View {
    @EnvironmentObject private var model: WatchSessionModel

    /// Nombre de séries sélectionné (borné par kSeriesChoices).
    @State private var series = 3

    private var minSeries: Int { kSeriesChoices.first ?? 1 }
    private var maxSeries: Int { kSeriesChoices.last ?? 6 }

    var body: some View {
        VStack(spacing: 6) {
            // — Logo : « Pause » blanc + « Pump » teal —
            HStack(spacing: 0) {
                Text("Pause").foregroundColor(PPColor.text)
                Text("Pump").foregroundColor(PPColor.accent)
            }
            .font(.system(.title3, design: .rounded).weight(.heavy))

            // v1 : le mode est piloté par le téléphone, simple rappel discret.
            Text(model.mode == .pause ? "Pause seule" : "Effort + Pause")
                .font(.footnote)
                .foregroundColor(PPColor.textDim)

            Spacer(minLength: 4)

            // — Sélecteur du nombre de séries —
            HStack {
                stepButton("minus") { series = max(series - 1, minSeries) }
                Spacer()
                VStack(spacing: 0) {
                    Text("\(series)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(PPColor.text)
                    Text(series > 1 ? "séries" : "série")
                        .font(.caption2)
                        .foregroundColor(PPColor.textDim)
                }
                Spacer()
                stepButton("plus") { series = min(series + 1, maxSeries) }
            }
            .padding(.horizontal, 6)

            Spacer(minLength: 6)

            Button {
                model.startSession(series: series)
            } label: {
                Text("C'est parti")
            }
            .buttonStyle(PPFilledButtonStyle(color: PPColor.accent, minHeight: 44))
        }
        .padding(.horizontal, 4)
    }

    /// Petit bouton rond − / + (hit-target généreux pour la salle).
    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(PPColor.text)
                .frame(width: 38, height: 38)
                .background(Circle().fill(PPColor.bgElev2))
        }
        .buttonStyle(.plain)
    }
}
