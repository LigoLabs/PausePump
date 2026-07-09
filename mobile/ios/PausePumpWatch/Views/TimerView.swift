import SwiftUI
#if canImport(WatchEngine)
import WatchEngine
#endif

// Décompte : anneau de progression + temps restant en très grand.
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

    /// Couleur de la phase (teal pause / ambre effort), rouge sur la fin.
    private var ringColor: Color {
        if remaining <= 5 { return PPColor.danger }
        return model.phase == .effort ? PPColor.effort : PPColor.accent
    }

    /// Couleur du bouton play/pause central (jamais rouge).
    private var phaseColor: Color {
        model.phase == .effort ? PPColor.effort : PPColor.accent
    }

    var body: some View {
        VStack(spacing: 4) {
            // — Anneau de progression (se vide avec le temps) —
            ZStack {
                Circle()
                    .stroke(PPColor.track, lineWidth: 9)
                Circle()
                    .trim(from: 0, to: CGFloat(max(1 - progress, 0.0001)))
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text(formatTime(remaining))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(PPColor.text)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                    if !model.running {
                        Text("en pause")
                            .font(.caption2)
                            .foregroundColor(PPColor.textDim)
                    }
                }
            }
            .padding(6)

            Text("Série \(model.currentSeries)/\(model.seriesTotal)")
                .font(.caption2)
                .foregroundColor(PPColor.textDim)

            // — Contrôles : reset · play/pause · suivante —
            HStack(spacing: 16) {
                controlButton("arrow.counterclockwise", diameter: 32) {
                    model.resetPhase()
                }
                controlButton(model.running ? "pause.fill" : "play.fill",
                              diameter: 42, prominent: true) {
                    model.togglePause()
                }
                controlButton("forward.end.fill", diameter: 32) {
                    model.skip()
                }
            }
            .padding(.bottom, 2)
        }
        // Le tick est déclenché hors de l'évaluation de body :
        // à chaque battement de la TimelineView, `date` change.
        .onChange(of: date) { _ in
            model.tick()
        }
    }

    /// Petit bouton rond de contrôle ; `prominent` = play/pause central.
    private func controlButton(_ symbol: String,
                               diameter: CGFloat,
                               prominent: Bool = false,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: prominent ? 16 : 12, weight: .bold))
                .foregroundColor(prominent ? PPColor.bg : PPColor.text)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(prominent ? phaseColor : PPColor.bgElev2))
        }
        .buttonStyle(.plain)
    }
}
