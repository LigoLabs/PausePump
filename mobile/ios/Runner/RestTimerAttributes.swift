import ActivityKit
import Foundation

/// Attributs de la Live Activity « séance en cours ». Fichier partagé entre
/// la cible Runner et l'extension PausePumpWidgets (via le script de setup).
///
/// Annoté iOS 16.1 (disponibilité d'ActivityKit) car Runner cible iOS 13 :
/// le pont ne l'utilise que derrière un `guard #available(iOS 16.2, *)`.
@available(iOS 16.1, *)
struct RestTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Échéance du décompte (nil = pas de décompte en cours).
        var endDate: Date?
        /// Origine visuelle de la phase (constante même après une reprise) :
        /// borne basse de la barre de progression, sinon elle repartirait de
        /// zéro à chaque mise à jour d'état.
        var startDate: Date?
        /// Temps restant figé, en secondes (décompte mis en pause).
        var pausedRemaining: Double?
        /// « Pause », « Effort 💪 », « Fais ta 2e série 💪 »…
        var label: String
        var seriesCurrent: Int
        var seriesTotal: Int
        var isEffort: Bool
    }
}
