import SwiftUI
#if canImport(WatchEngine)
import WatchEngine
#endif

// Accueil : logo, choix du mode, nombre de séries, départ.
//
// Le mode se choisit directement à la montre (il était auparavant imposé par
// l'iPhone) — voir `WatchSessionModel.chooseMode`.

struct StartView: View {
    @EnvironmentObject private var model: WatchSessionModel

    /// Nombre de séries sélectionné (borné par kSeriesChoices).
    @State private var series = 3

    /// Feuille des réglages (durées personnalisées).
    @State private var showSettings = false

    /// Feuille de réglage de l'enchaînement, en mode Effort + Repos.
    @State private var showEffortSetup = false

    private var minSeries: Int { kSeriesChoices.first ?? 1 }
    private var maxSeries: Int { kSeriesChoices.last ?? 6 }

    var body: some View {
        // Le ScrollView reste indispensable sur les petits boîtiers, mais son
        // contenu s'y empilait à partir du haut, laissant du vide en bas
        // depuis le retrait du logo. En lui imposant AU MOINS la hauteur
        // visible, le bloc se centre verticalement quand il tient à l'écran,
        // et redevient défilable dès qu'il déborde.
        GeometryReader { geo in
            ScrollView {
                content.frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
        }
        .overlay {
            PPCornerButton(symbol: "gearshape.fill") { showSettings = true }
                .ppTopLeftCorner()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(model)
        }
        .sheet(isPresented: $showEffortSetup) {
            EffortSetupView(series: series).environmentObject(model)
        }
    }

    private var content: some View {
        // Espacement serré : en mode Effort + Repos il y a une rangée de
        // plus, et le GO doit rester visible sans défiler.
        VStack(spacing: PPMetrics.s(5)) {
                // Pas de logo « PausePump » ici : sur ~157 pt de hauteur utile,
                // il coûtait une rangée entière pour rappeler le nom de l'app
                // qu'on vient d'ouvrir. La place va aux commandes.
                modePicker

                seriesStepper

                Button {
                    // Effort + Repos : le réglage de l'enchaînement arrive
                    // APRÈS le GO, comme sur l'app iPhone. En Repos seul il
                    // n'y a rien à régler, on démarre directement.
                    if model.mode == .effort {
                        showEffortSetup = true
                    } else {
                        model.startSession(series: series)
                    }
                } label: {
                    Text("GO")
                }
                .buttonStyle(PPGoButtonStyle())
        }
        .padding(.horizontal, PPMetrics.gutter)
        .padding(.vertical, 4)
    }

    // — Mode : deux pastilles, celle du mode actif est pleine —
    private var modePicker: some View {
        HStack(spacing: PPMetrics.s(5)) {
            modePill("Repos seul", mode: .pause)
            modePill("Effort + Repos", mode: .effort)
        }
    }

    private func modePill(_ label: String, mode: SessionMode) -> some View {
        let selected = model.mode == mode
        return Button {
            model.chooseMode(mode)
        } label: {
            Text(label)
                .font(.system(size: PPMetrics.s(12), weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundColor(selected ? PPColor.bg : PPColor.textDim)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, minHeight: PPMetrics.s(28))
                .background(
                    Capsule().fill(selected ? PPColor.accent : PPColor.bgElev2)
                )
        }
        .buttonStyle(.plain)
    }

    // — Séries : −  N  + —
    private var seriesStepper: some View {
        HStack {
            stepButton("minus") { series = max(series - 1, minSeries) }
            Spacer(minLength: 2)
            VStack(spacing: 0) {
                Text("\(series)")
                    .font(.system(size: PPMetrics.s(32), weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(PPColor.text)
                Text(series > 1 ? "séries" : "série")
                    .font(.system(size: PPMetrics.s(11)))
                    .foregroundColor(PPColor.textDim)
            }
            Spacer(minLength: 2)
            stepButton("plus") { series = min(series + 1, maxSeries) }
        }
        .padding(.horizontal, 2)
    }

    /// Petit bouton rond − / +.
    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        let d = PPMetrics.s(32)
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
