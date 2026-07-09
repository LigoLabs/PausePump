import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Pilote la **Live Activity** iOS (écran verrouillé + Dynamic Island) : le
/// compte à rebours y est rendu nativement par iOS (`Text(timerInterval:)`),
/// sans qu'aucun code Dart ne tourne — l'équivalent du chrono natif Android
/// de [ForegroundService]. No-op sur les autres plateformes.
///
/// États côté natif :
/// - `start`  → décompte qui défile jusqu'à `endTime` ;
/// - `pause`  → temps restant figé (timer en pause) ;
/// - `idle`   → pas de décompte, un message (« Fais ta 2e série »…) ;
/// - `end`    → l'activité est retirée.
class LiveActivityService {
  LiveActivityService({bool? supported})
      : _supported = supported ?? Platform.isIOS;

  static const MethodChannel _channel = MethodChannel('pausepump/live_activity');

  final bool _supported;

  Future<void> _invoke(String method, [Map<String, Object?>? args]) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>(method, args);
    } catch (_) {
      // Live Activities indispo (iOS < 16.1, désactivées…) → on ignore.
    }
  }

  /// Démarre (ou met à jour) le décompte natif de [startTime] à [endTime].
  /// [startTime] est l'origine visuelle de la barre de progression : constante
  /// pour toute la phase, même après une reprise.
  Future<void> start({
    required DateTime endTime,
    required DateTime startTime,
    required String label,
    required int seriesCurrent,
    required int seriesTotal,
    required bool isEffort,
  }) {
    return _invoke('start', {
      'endTime': endTime.millisecondsSinceEpoch,
      'startTime': startTime.millisecondsSinceEpoch,
      'label': label,
      'seriesCurrent': seriesCurrent,
      'seriesTotal': seriesTotal,
      'isEffort': isEffort,
    });
  }

  /// Fige l'activité sur [remaining] secondes (timer mis en pause).
  Future<void> pause({
    required double remaining,
    required String label,
    required int seriesCurrent,
    required int seriesTotal,
    required bool isEffort,
  }) {
    return _invoke('pause', {
      'remaining': remaining,
      'label': label,
      'seriesCurrent': seriesCurrent,
      'seriesTotal': seriesTotal,
      'isEffort': isEffort,
    });
  }

  /// Pas de décompte en cours : affiche [label] (« Fais ta 2e série »…).
  Future<void> idle({
    required String label,
    required int seriesCurrent,
    required int seriesTotal,
  }) {
    return _invoke('idle', {
      'label': label,
      'seriesCurrent': seriesCurrent,
      'seriesTotal': seriesTotal,
    });
  }

  /// Termine et retire l'activité (fin de séance, retour accueil…).
  Future<void> end() => _invoke('end');
}
