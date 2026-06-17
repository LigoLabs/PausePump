import 'package:audioplayers/audioplayers.dart';

import '../models/enums.dart';

/// Lecture des bips (assets WAV). Les players sont créés à la demande pour
/// rester testables sans plugin natif. Un player dédié à l'alarme, un aux
/// petits sons (ticks), afin qu'ils ne se coupent pas l'un l'autre.
class AudioService {
  AudioPlayer? _alarm;
  AudioPlayer? _fx;

  AudioPlayer get _alarmPlayer => _alarm ??= AudioPlayer(playerId: 'pp_alarm');
  AudioPlayer get _fxPlayer => _fx ??= AudioPlayer(playerId: 'pp_fx');

  Future<void> init() async {}

  Future<void> _play(AudioPlayer player, String asset, double volume) async {
    try {
      await player.stop();
      await player.setVolume(volume.clamp(0.0, 1.0).toDouble());
      await player.play(AssetSource(asset));
    } catch (_) {
      // Audio indispo : on ignore silencieusement.
    }
  }

  Future<void> playAlarm(AlarmSound sound, double volume) =>
      _play(_alarmPlayer, sound.asset, volume);

  Future<void> previewAlarm(AlarmSound sound, double volume) =>
      _play(_alarmPlayer, sound.asset, volume);

  Future<void> tick(double volume) => _play(_fxPlayer, 'sounds/tick.wav', volume);
  Future<void> go(double volume) => _play(_fxPlayer, 'sounds/go.wav', volume);

  Future<void> dispose() async {
    await _alarm?.dispose();
    await _fx?.dispose();
  }
}
