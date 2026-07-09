import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Palette de la marque (mêmes teintes que le thème Flutter / CSS web)

private enum Brand {
    /// #0F1219 — fond principal.
    static let bg = Color(red: 15 / 255, green: 18 / 255, blue: 25 / 255)
    /// #171B26 — fond surélevé (badges, capsules).
    static let bgElev = Color(red: 23 / 255, green: 27 / 255, blue: 38 / 255)
    /// #22D3A7 — accent teal (pause).
    static let teal = Color(red: 34 / 255, green: 211 / 255, blue: 167 / 255)
    /// #F59E0B — ambre (effort).
    static let amber = Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255)
    /// #E9F0F5 — texte principal.
    static let text = Color(red: 233 / 255, green: 240 / 255, blue: 245 / 255)
    /// #93A0B0 — texte atténué.
    static let textDim = Color(red: 147 / 255, green: 160 / 255, blue: 176 / 255)
}

/// Couleur d'accent de l'état : ambre pendant l'effort, teal pendant la pause.
private func accent(_ state: RestTimerAttributes.ContentState) -> Color {
    state.isEffort ? Brand.amber : Brand.teal
}

/// Formate un temps figé : « 45s » sous la minute, « 1:30 » au-delà.
private func formatFrozen(_ s: Double) -> String {
    let total = max(0, Int(s.rounded()))
    if total < 60 { return "\(total)s" }
    return String(format: "%d:%02d", total / 60, total % 60)
}

/// Intervalle du décompte natif, borné pour ne jamais être inversé
/// (une échéance déjà passée ferait planter `ClosedRange`). La borne basse
/// est l'origine de la phase (`startDate`) quand elle est connue, pour que la
/// barre de progression reflète écoulé/durée totale au lieu de repartir de
/// zéro à chaque mise à jour d'état.
private func timerRange(_ state: RestTimerAttributes.ContentState,
                        to endDate: Date) -> ClosedRange<Date> {
    let now = Date.now
    let end = max(now, endDate)
    let start = min(state.startDate ?? now, end)
    return start...end
}

// MARK: - Live Activity

/// Live Activity « séance en cours » : bannière écran verrouillé + Dynamic
/// Island. Le décompte défile nativement (`Text(timerInterval:)`), aucun
/// code de l'app ne tourne pendant que l'iPhone est verrouillé.
struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            // Bannière écran verrouillé / centre de notifications.
            LockScreenBanner(state: context.state)
                .activityBackgroundTint(Brand.bg)
                .activitySystemActionForegroundColor(Brand.text)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.label)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Brand.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("Série \(context.state.seriesCurrent)/\(context.state.seriesTotal)")
                            .font(.caption)
                            .foregroundStyle(Brand.textDim)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    expandedTime(context.state)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let endDate = context.state.endDate {
                        ProgressView(
                            timerInterval: timerRange(context.state, to: endDate),
                            countsDown: true,
                            label: { EmptyView() },
                            currentValueLabel: { EmptyView() }
                        )
                        .progressViewStyle(.linear)
                        .tint(accent(context.state))
                        .padding(.horizontal, 4)
                        .padding(.top, 6)
                    }
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(accent(context.state))
            } compactTrailing: {
                compactTime(context.state)
            } minimal: {
                minimalTime(context.state)
            }
            .keylineTint(accent(context.state))
        }
    }

    /// Temps de l'îlot déplié : gros décompte natif, ou temps figé (pause).
    /// À l'idle, rien — le label à gauche porte le message.
    @ViewBuilder
    private func expandedTime(_ state: RestTimerAttributes.ContentState) -> some View {
        if let endDate = state.endDate {
            Text(timerInterval: timerRange(state, to: endDate), countsDown: true)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 72)
                .foregroundStyle(accent(state))
        } else if let remaining = state.pausedRemaining {
            VStack(alignment: .trailing, spacing: 0) {
                Text(formatFrozen(remaining))
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(accent(state))
                Text("en pause")
                    .font(.caption2)
                    .foregroundStyle(Brand.textDim)
            }
        }
    }

    /// Temps compact (côté droit de l'îlot) : décompte natif ou temps figé.
    @ViewBuilder
    private func compactTime(_ state: RestTimerAttributes.ContentState) -> some View {
        if let endDate = state.endDate {
            Text(timerInterval: timerRange(state, to: endDate), countsDown: true)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 44)
                .foregroundStyle(accent(state))
        } else if let remaining = state.pausedRemaining {
            Text(formatFrozen(remaining))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(accent(state))
        }
        // Idle : rien à droite, l'haltère de gauche suffit.
    }

    /// Présentation minimale : idem compact, en plus petit ; à l'idle on
    /// retombe sur l'haltère pour ne jamais laisser l'îlot vide.
    @ViewBuilder
    private func minimalTime(_ state: RestTimerAttributes.ContentState) -> some View {
        if let endDate = state.endDate {
            Text(timerInterval: timerRange(state, to: endDate), countsDown: true)
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 36)
                .foregroundStyle(accent(state))
        } else if let remaining = state.pausedRemaining {
            Text(formatFrozen(remaining))
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(accent(state))
        } else {
            Image(systemName: "figure.strengthtraining.traditional")
                .foregroundStyle(accent(state))
        }
    }
}

// MARK: - Bannière écran verrouillé

private struct LockScreenBanner: View {
    let state: RestTimerAttributes.ContentState

    /// Idle : ni décompte ni temps figé — un message (« Fais ta 2e série 💪 »).
    private var isIdle: Bool {
        state.endDate == nil && state.pausedRemaining == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.label)
                        // À l'idle, le label est seul en scène : on le grossit.
                        .font(isIdle ? .title3.weight(.semibold) : .headline.weight(.semibold))
                        .foregroundStyle(Brand.text)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text("Série \(state.seriesCurrent)/\(state.seriesTotal)")
                        .font(.subheadline)
                        .foregroundStyle(Brand.textDim)
                }
                Spacer(minLength: 12)
                trailingTime
            }
            if let endDate = state.endDate {
                ProgressView(
                    timerInterval: timerRange(state, to: endDate),
                    countsDown: true,
                    label: { EmptyView() },
                    currentValueLabel: { EmptyView() }
                )
                .progressViewStyle(.linear)
                .tint(accent(state))
            }
        }
        .padding(16)
    }

    /// Le temps, en très gros : décompte natif iOS, ou figé avec un badge
    /// « en pause ». À l'idle, rien — le label porte tout.
    @ViewBuilder
    private var trailingTime: some View {
        if let endDate = state.endDate {
            Text(timerInterval: timerRange(state, to: endDate), countsDown: true)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(accent(state))
        } else if let remaining = state.pausedRemaining {
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatFrozen(remaining))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(accent(state))
                Text("en pause")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Brand.textDim)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Brand.bgElev))
            }
        }
    }
}
