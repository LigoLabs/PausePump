import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Synchronise la configuration vers l'**Apple Watch** (WatchConnectivity,
/// `updateApplicationContext`) : la montre fait tourner sa propre séance en
/// autonome, le téléphone lui pousse simplement les préférences (dernière
/// pause choisie, mode, sons/vibration). No-op hors iOS.
class WatchSyncService {
  WatchSyncService({bool? supported}) : _supported = supported ?? Platform.isIOS;

  static const MethodChannel _channel = MethodChannel('pausepump/watch_sync');

  final bool _supported;

  /// Pousse la config courante vers la montre (best effort : la montre
  /// récupère le dernier contexte à sa prochaine activation).
  Future<void> pushContext({
    required int lastPause,
    required String mode,
    required String alarm,
    required bool vibrate,
    required bool sound,
    required double volume,
  }) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('updateContext', {
        'lastPause': lastPause,
        'mode': mode,
        'alarm': alarm,
        'vibrate': vibrate,
        'sound': sound,
        'volume': volume,
      });
    } catch (_) {
      // Pas de montre appairée / WCSession indispo → on ignore.
    }
  }
}
