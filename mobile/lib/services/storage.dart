import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// Persistance des réglages et de la dernière config (SharedPreferences).
/// Équivalent des clés `pausepump.settings.v1` / `pausepump.session.v1` du web.
class Storage {
  Storage(this._prefs);

  static const _kSettings = 'pausepump.settings.v1';
  static const _kLastPause = 'pausepump.lastPause.v1';
  static const _kMode = 'pausepump.mode.v1';
  static const _kSeries = 'pausepump.series.v1';
  static const _kEffort = 'pausepump.effort.v1';
  static const _kRest = 'pausepump.rest.v1';
  static const _kEffortAuto = 'pausepump.effortAuto.v1';

  final SharedPreferences _prefs;

  static Future<Storage> open() async {
    return Storage(await SharedPreferences.getInstance());
  }

  AppSettings loadSettings() {
    final raw = _prefs.getString(_kSettings);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings s) =>
      _prefs.setString(_kSettings, jsonEncode(s.toJson()));

  /// Dernière durée de pause sélectionnée (raccourci « relancer »).
  int loadLastPause() => _prefs.getInt(_kLastPause) ?? 60;
  Future<void> saveLastPause(int seconds) => _prefs.setInt(_kLastPause, seconds);

  String loadMode() => _prefs.getString(_kMode) ?? 'pause';
  Future<void> saveMode(String mode) => _prefs.setString(_kMode, mode);

  /// Dernière config de séance (nombre de séries, durées effort/pause,
  /// enchaînement auto) — restaurée au lancement comme sur le web.
  int loadSeries() => _prefs.getInt(_kSeries) ?? 3;
  Future<void> saveSeries(int n) => _prefs.setInt(_kSeries, n);

  int loadEffort() => _prefs.getInt(_kEffort) ?? 60;
  Future<void> saveEffort(int seconds) => _prefs.setInt(_kEffort, seconds);

  int loadRest() => _prefs.getInt(_kRest) ?? 60;
  Future<void> saveRest(int seconds) => _prefs.setInt(_kRest, seconds);

  bool loadEffortAuto() => _prefs.getBool(_kEffortAuto) ?? true;
  Future<void> saveEffortAuto(bool v) => _prefs.setBool(_kEffortAuto, v);
}
