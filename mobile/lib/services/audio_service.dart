import 'package:audioplayers/audioplayers.dart';

import '../models/enums.dart';

/// Lecture des bips (assets WAV). Un player dédié pour l'alarme, un pour les
/// petits sons (ticks de décompte) afin qu'ils ne se coupent pas l'un l'autre.
class AudioService {
  final AudioPlayer _alarm = AudioPlayer(playerId: 'pp_alarm');
  final AudioPlayer _fx = AudioPlayer(playerId: 'pp_fx');

  Future<void> init() async {
    // Mode par défaut (compatible iOS + Android). On prépare juste le contexte.
    await _fx.setReleaseMode(ReleaseMode.stop);
    await _alarm.setReleaseMode(ReleaseMode.stop);
  }

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
      _play(_alarm, sound.asset, volume);

  Future<void> previewAlarm(AlarmSound sound, double volume) =>
      _play(_alarm, sound.asset, volume);

  Future<void> tick(double volume) => _play(_fx, 'sounds/tick.wav', volume);
  Future<void> go(double volume) => _play(_fx, 'sounds/go.wav', volume);

  Future<void> dispose() async {
    await _alarm.dispose();
    await _fx.dispose();
  }
}
