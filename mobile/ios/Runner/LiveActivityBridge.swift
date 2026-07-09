import ActivityKit
import Flutter
import Foundation

/// Pont natif du canal « pausepump/live_activity » : pilote la Live Activity
/// (écran verrouillé + Dynamic Island) depuis Dart. Le compte à rebours y est
/// rendu par iOS lui-même (`Text(timerInterval:)`) — aucun tick côté app,
/// c'est l'équivalent iOS du chrono natif du foreground service Android.
final class LiveActivityBridge: NSObject {

    /// Instance gardée vivante tant que le moteur Flutter tourne.
    private static var shared: LiveActivityBridge?

    /// Chaîne de sérialisation des opérations ActivityKit : les messages du
    /// canal arrivent dans l'ordre, mais chaque opération est async — lancer
    /// un Task indépendant par message pourrait les entrelacer (un `update`
    /// doublant le `request` initial, par exemple). Chaque nouvelle opération
    /// attend donc la fin de la précédente.
    private var chain: Task<Void, Never>?

    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = LiveActivityBridge()
        shared = instance
        let channel = FlutterMethodChannel(
            name: "pausepump/live_activity",
            binaryMessenger: registrar.messenger()
        )
        channel.setMethodCallHandler { call, result in
            instance.handle(call)
            // Fire-and-forget côté Dart : on répond immédiatement et les
            // erreurs ActivityKit sont avalées (jamais remontées à Flutter).
            result(nil)
        }
    }

    // MARK: - Dispatch des messages Dart

    private func handle(_ call: FlutterMethodCall) {
        // Live Activities pilotables (ActivityContent, update/end) : iOS 16.2+.
        guard #available(iOS 16.2, *) else { return }

        let args = call.arguments as? [String: Any] ?? [:]

        switch call.method {
        case "start":
            // endTime/startTime : époques en millisecondes, envoyées par Dart en Int.
            let endMs = (args["endTime"] as? NSNumber)?.doubleValue ?? 0
            let startMs = (args["startTime"] as? NSNumber)?.doubleValue
            let state = RestTimerAttributes.ContentState(
                endDate: Date(timeIntervalSince1970: endMs / 1000.0),
                startDate: startMs.map { Date(timeIntervalSince1970: $0 / 1000.0) },
                pausedRemaining: nil,
                label: args["label"] as? String ?? "",
                seriesCurrent: (args["seriesCurrent"] as? NSNumber)?.intValue ?? 0,
                seriesTotal: (args["seriesTotal"] as? NSNumber)?.intValue ?? 0,
                isEffort: (args["isEffort"] as? NSNumber)?.boolValue ?? false
            )
            enqueue { await Self.push(state) }

        case "pause":
            // Décompte figé : plus d'échéance, juste le restant en secondes.
            let state = RestTimerAttributes.ContentState(
                endDate: nil,
                startDate: nil,
                pausedRemaining: (args["remaining"] as? NSNumber)?.doubleValue ?? 0,
                label: args["label"] as? String ?? "",
                seriesCurrent: (args["seriesCurrent"] as? NSNumber)?.intValue ?? 0,
                seriesTotal: (args["seriesTotal"] as? NSNumber)?.intValue ?? 0,
                isEffort: (args["isEffort"] as? NSNumber)?.boolValue ?? false
            )
            enqueue { await Self.push(state) }

        case "idle":
            // Pas de décompte : un message type « Fais ta 2e série 💪 ».
            let state = RestTimerAttributes.ContentState(
                endDate: nil,
                startDate: nil,
                pausedRemaining: nil,
                label: args["label"] as? String ?? "",
                seriesCurrent: (args["seriesCurrent"] as? NSNumber)?.intValue ?? 0,
                seriesTotal: (args["seriesTotal"] as? NSNumber)?.intValue ?? 0,
                isEffort: false
            )
            enqueue { await Self.push(state) }

        case "end":
            enqueue { await Self.endAll() }

        default:
            break
        }
    }

    /// Enchaîne [op] après l'opération précédente (exécution strictement FIFO).
    private func enqueue(_ op: @escaping () async -> Void) {
        chain = Task { [prev = self.chain] in
            await prev?.value
            await op()
        }
    }

    // MARK: - ActivityKit

    /// Met à jour l'activité en cours, ou en démarre une s'il n'y en a pas.
    /// Une seule activité à la fois pour toute la séance.
    @available(iOS 16.2, *)
    private static func push(_ state: RestTimerAttributes.ContentState) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // staleDate : l'OS grise l'activité 60 s après l'échéance si l'app n'a
        // pas donné signe de vie ; pas d'échéance → jamais périmée.
        let content = ActivityContent(
            state: state,
            staleDate: state.endDate?.addingTimeInterval(60)
        )
        // Ne réutiliser qu'une activité encore visible : si l'utilisateur l'a
        // balayée (état dismissed), un update ne s'afficherait plus jamais —
        // on en redemande une neuve à la place.
        if let activity = Activity<RestTimerAttributes>.activities
            .first(where: { $0.activityState == .active }) {
            await activity.update(content)
        } else {
            // Échec possible (quota, activités coupées entre-temps…) : avalé,
            // l'app reste pleinement fonctionnelle sans Live Activity.
            _ = try? Activity<RestTimerAttributes>.request(
                attributes: RestTimerAttributes(),
                content: content,
                pushType: nil
            )
        }
    }

    /// Termine et retire immédiatement toutes les activités de l'app.
    @available(iOS 16.2, *)
    private static func endAll() async {
        for activity in Activity<RestTimerAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
