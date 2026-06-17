import 'package:wakelock_plus/wakelock_plus.dart';

/// Garde l'écran allumé pendant un décompte (équivalent du Wake Lock web).
class WakelockService {
  Future<void> enable() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {}
  }

  Future<void> disable() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }
}
