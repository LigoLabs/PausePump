import SwiftUI
#if canImport(WatchEngine)
import WatchEngine
#endif

// Décompte : anneau de progression dominant + temps restant.
// L'horloge est pilotée par une TimelineView : l'affichage est dérivé de
// `remaining(at: date)` (jamais d'état décrémenté), et le moteur est
// « tické » à chaque battement via onChange — pas de side effect dans body.

struct TimerView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            TimerContent(date: context.date)
        }
    }
}

private struct TimerContent: View {
    @EnvironmentObject private var model: WatchSessionModel

    /// Instant courant fourni par la TimelineView.
    let date: Date

    private var remaining: Double { model.remaining(at: date) }
    private var progress: Double { model.progress(at: date) }

    /// Couleur de la phase (teal repos / ambre effort), rouge sur la fin.
    private var ringColor: Color {
        if remaining <= 5 { return PPColor.danger }
        return model.phase == .effort ? PPColor.effort : PPColor.accent
    }

    /// Couleur du bouton play/pause central (jamais rouge).
    private var phaseColor: Color {
        model.phase == .effort ? PPColor.effort : PPColor.accent
    }

    private var ringWidth: CGFloat { PPMetrics.s(8) }

    var body: some View {
        // Le bandeau et les contrôles prennent leur hauteur idéale ; l'anneau,
        // seul élément flexible, reçoit tout le reste et `aspectRatio(.fit)`
        // le borne au plus petit des deux côtés. Ne JAMAIS lui ajouter un
        // `.frame(maxHeight: .infinity)` : l'aspectRatio se ferait alors
        // proposer une hauteur infinie, se dimensionnerait sur la largeur du
        // boîtier et le cercle passerait sous les boutons.
        // Géométrie explicite : les contrôles ont une hauteur fixe et sont
        // collés en bas, l'anneau prend tout le reste. Laisser SwiftUI
        // arbitrer donnait soit un anneau bridé, soit des boutons qui
        // remontaient contre lui.
        GeometryReader { geo in
            let controlsH = PPMetrics.s(34)
            let gap = PPMetrics.s(6)
            let side = max(min(geo.size.width, geo.size.height - controlsH - gap), 60)

            VStack(spacing: gap) {
                ring.frame(width: side, height: side)
                controls.frame(height: controlsH)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .padding(.horizontal, 2)
        // watchOS réserve 36 pt en bas (mesuré : safeAreaInsets.bottom sur un
        // 46 mm, pour 159 pt de hauteur utile seulement). On les récupère pour
        // descendre les contrôles et agrandir d'autant l'anneau, en gardant
        // une marge : le bas de la dalle est incurvé sur les vrais boîtiers,
        // un bouton posé à ras y serait rogné.
        //
        // Mesuré : cette ligne fait bien tomber safeAreaInsets.bottom de 36 à
        // 0 (soit ~34 pt de surface utile gagnés), mais la HAUTEUR du
        // conteneur reste plafonnée à ~157 pt — watchOS ne rend pas la bande
        // du bas. Les contrôles, alignés .bottom, sont donc déjà au plus bas
        // possible : inutile de chercher à les descendre davantage.
        .ignoresSafeArea(edges: .bottom)
        .padding(.bottom, PPMetrics.s(2))
        // Le tick est déclenché hors de l'évaluation de body :
        // à chaque battement de la TimelineView, `date` change.
        .onChange(of: date) { _ in
            model.tick()
        }
    }

    // — Indicateur d'état : phase en cours, ou « EN PAUSE » quand c'est figé.
    //
    //   Il était auparavant SOUS le chrono, où il poussait les chiffres vers
    //   le haut et n'apparaissait qu'à l'arrêt (donc la mise en page sautait).
    //   Il est maintenant AU-DESSUS du chrono, dans l'anneau : toujours
    //   présent, il ne décale plus rien, et il ne coûte aucune hauteur — la
    //   zone utile de la montre ne fait que ~159 pt, chaque rangée en moins
    //   agrandit d'autant l'anneau.
    private var stateLabel: some View {
        Group {
            if model.running {
                Text(model.phase == .effort ? "EFFORT" : "REPOS")
                    .foregroundColor(phaseColor)
            } else {
                Text("EN PAUSE")
                    .foregroundColor(PPColor.bg)
                    .padding(.horizontal, PPMetrics.s(8))
                    .padding(.vertical, PPMetrics.s(2))
                    .background(Capsule().fill(PPColor.textDim))
            }
        }
        .font(.system(size: PPMetrics.s(11), weight: .heavy, design: .rounded))
        .lineLimit(1)
        .tracking(0.5)
    }

    // — Anneau : prend toute la largeur disponible et reste circulaire.
    private var ring: some View {
        ZStack {
            Circle()
                .stroke(PPColor.track, lineWidth: ringWidth)
            Circle()
                .trim(from: 0, to: CGFloat(max(1 - progress, 0.0001)))
                .stroke(ringColor, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: PPMetrics.s(1)) {
                stateLabel
                Text(formatTime(remaining))
                    .font(.system(size: PPMetrics.s(30), weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(PPColor.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("\(model.currentSeries)/\(model.seriesTotal)")
                    .font(.system(size: PPMetrics.s(11), weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(PPColor.textDim)
            }
            .padding(.horizontal, ringWidth + PPMetrics.s(6))
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // — Contrôles : reset · play/pause · suivante —
    private var controls: some View {
        HStack(spacing: PPMetrics.s(12)) {
            controlButton("arrow.counterclockwise", diameter: PPMetrics.s(26)) {
                model.resetPhase()
            }
            controlButton(model.running ? "pause.fill" : "play.fill",
                          diameter: PPMetrics.s(34), prominent: true) {
                model.togglePause()
            }
            controlButton("forward.end.fill", diameter: PPMetrics.s(26)) {
                model.skip()
            }
        }
    }

    /// Petit bouton rond de contrôle ; `prominent` = play/pause central.
    private func controlButton(_ symbol: String,
                               diameter: CGFloat,
                               prominent: Bool = false,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: prominent ? PPMetrics.s(14) : PPMetrics.s(11), weight: .bold))
                .foregroundColor(prominent ? PPColor.bg : PPColor.text)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(prominent ? phaseColor : PPColor.bgElev2))
        }
        .buttonStyle(.plain)
    }
}
