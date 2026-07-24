import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Pilote le service de premier plan natif (Android) qui affiche la
/// notification persistante avec le **chrono natif** (compte à rebours rendu
/// par Android, sans code Dart). No-op sur les autres plateformes.
class ForegroundService {
  static const MethodChannel _channel = MethodChannel('pausepump/timer_service');

  bool get _supported => Platform.isAndroid;

  /// Démarre/actualise le décompte natif jusqu'à [endTime].
  Future<void> start(
    DateTime endTime, {
    required String title,
    required String label,
  }) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('start', {
        'endTime': endTime.millisecondsSinceEpoch,
        'title': title,
        'label': label,
      });
    } catch (_) {
      // Service indispo (ancienne version, permission…) → on ignore.
    }
  }

  Future<void> stop() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }

  /// Des écouteurs (Bluetooth, filaires, USB…) sont-ils branchés ?
  /// Détermine le routage du bip de fin : avec écouteurs, le son doit sortir
  /// dedans (flux média) — le flux ALARME de la notif sort toujours du
  /// haut-parleur du téléphone, gênant à la salle.
  Future<bool> hasHeadphones() async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('hasHeadphones') ?? false;
    } catch (_) {
      return false;
    }
  }
}
