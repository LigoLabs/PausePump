import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';

import '../models/enums.dart';

/// Lecture des bips (assets WAV). Les players sont créés à la demande pour
/// rester testables sans plugin natif. Un player par son (alarme, tick, go),
/// chacun gardant sa source **préchargée** : le bip part sans latence de
/// chargement au moment critique (fin de pause, décompte).
///
/// Le contexte audio est configuré pour ne **jamais couper la musique** des
/// autres apps (Spotify…) : pas de prise de focus sur Android, session
/// `mixWithOthers` sur iOS — même comportement que le web (Web Audio ne
/// touche pas au focus). `playback` (iOS) : le bip sonne aussi quand
/// l'interrupteur silencieux est activé.
class AudioService {
  // Futures cachés : la création (asynchrone) de chaque player n'a lieu
  // qu'une fois, même en cas d'appels concurrents.
  Future<AudioPlayer>? _alarm;
  Future<AudioPlayer>? _tick;
  Future<AudioPlayer>? _go;
  String? _alarmAsset; // asset actuellement chargé dans le player d'alarme

  static final AudioContext _mixContext = AudioContext(
    android: const AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.media,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {AVAudioSessionOptions.mixWithOthers},
    ),
  );

  Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(_mixContext);
    } catch (_) {
      // Plugin indispo (tests) : on ignore.
    }
  }

  /// Player basse latence (SoundPool côté Android) qui conserve sa source
  /// après un stop (ReleaseMode.stop) → rejouable immédiatement via resume().
  Future<AudioPlayer> _create(String id, {String? asset}) async {
    final p = AudioPlayer(playerId: id);
    try {
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setReleaseMode(ReleaseMode.stop);
      // iOS ne supporte que le contexte global (posé dans init()).
      if (Platform.isAndroid) await p.setAudioContext(_mixContext);
      if (asset != null) await p.setSource(AssetSource(asset));
    } catch (_) {
      // Audio indispo : le player reste utilisable en no-op.
    }
    return p;
  }

  Future<AudioPlayer> _alarmPlayer() => _alarm ??= _create('pp_alarm');

  /// Précharge le son d'alarme choisi pour qu'il parte sans délai à la fin
  /// du décompte. Appelé au démarrage, au changement de réglage et à chaque
  /// lancement de phase (no-op si déjà chargé).
  Future<void> prepareAlarm(AlarmSound sound) async {
    try {
      final p = await _alarmPlayer();
      if (_alarmAsset != sound.asset) {
        _alarmAsset = null; // si setSource échoue, on retentera au prochain appel
        await p.setSource(AssetSource(sound.asset));
        _alarmAsset = sound.asset;
      }
    } catch (_) {}
  }

  Future<void> _playAlarmAsset(String asset, double volume) async {
    try {
      final p = await _alarmPlayer();
      await p.stop();
      await p.setVolume(volume.clamp(0.0, 1.0).toDouble());
      if (_alarmAsset != asset) {
        _alarmAsset = null; // si setSource échoue, on retentera au prochain appel
        await p.setSource(AssetSource(asset));
        _alarmAsset = asset;
      }
      await p.resume();
    } catch (_) {
      // Audio indispo : on ignore silencieusement.
    }
  }

  /// Rejoue le son déjà chargé dans son player dédié.
  Future<void> _replay(Future<AudioPlayer> player, double volume) async {
    try {
      final p = await player;
      await p.stop();
      await p.setVolume(volume.clamp(0.0, 1.0).toDouble());
      await p.resume();
    } catch (_) {}
  }

  Future<void> playAlarm(AlarmSound sound, double volume) =>
      _playAlarmAsset(sound.asset, volume);

  Future<void> previewAlarm(AlarmSound sound, double volume) =>
      _playAlarmAsset(sound.asset, volume);

  Future<void> tick(double volume) =>
      _replay(_tick ??= _create('pp_tick', asset: 'sounds/tick.wav'), volume);

  Future<void> go(double volume) =>
      _replay(_go ??= _create('pp_go', asset: 'sounds/go.wav'), volume);

  Future<void> dispose() async {
    for (final f in [_alarm, _tick, _go]) {
      if (f == null) continue;
      try {
        await (await f).dispose();
      } catch (_) {}
    }
    _alarm = _tick = _go = null;
    _alarmAsset = null;
  }
}
