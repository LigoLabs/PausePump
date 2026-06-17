import 'package:flutter_test/flutter_test.dart';
import 'package:pausepump/models/enums.dart';
import 'package:pausepump/services/audio_service.dart';
import 'package:pausepump/services/foreground_service.dart';
import 'package:pausepump/services/notification_service.dart';
import 'package:pausepump/services/storage.dart';
import 'package:pausepump/services/wakelock_service.dart';
import 'package:pausepump/state/timer_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Services non initialisés (init() jamais appelé) → no-op, sans plugin natif.
  Future<TimerController> makeController() async {
    SharedPreferences.setMockInitialValues({});
    final storage = await Storage.open();
    return TimerController(
      storage: storage,
      audio: AudioService(),
      notifications: NotificationService(),
      wakelock: WakelockService(),
      foreground: ForegroundService(),
    );
  }

  test('Pause seule : valider une série décrémente le compteur et remplit un point',
      () async {
    final c = await makeController();
    await c.setMode(SessionMode.pause);
    c.startSession(3);

    expect(c.step, SessionStep.doSet);
    expect(c.seriesRemaining, 3);
    expect(c.seriesTotal, 3);
    expect(c.tlDots, 0);

    c.validateSet();
    expect(c.seriesRemaining, 2, reason: 'compteur −1 dès la validation');
    expect(c.tlDots, 1, reason: 'le point de la série se remplit');
    expect(c.step, SessionStep.duration);

    c.pickDuration(60);
    expect(c.step, SessionStep.timer);
    expect(c.running, isTrue);
    expect(c.phase, Phase.pause);
    expect(c.remaining, 60.0);

    c.pause();
    expect(c.running, isFalse);
    c.dispose();
  });

  test('Le compteur +/- ajuste le total ET le restant', () async {
    final c = await makeController();
    await c.setMode(SessionMode.pause);
    c.startSession(3);

    c.addSeries();
    expect(c.seriesTotal, 4);
    expect(c.seriesRemaining, 4);

    c.removeSeries();
    expect(c.seriesTotal, 3);
    expect(c.seriesRemaining, 3);
    c.dispose();
  });

  test('La dernière durée choisie est mémorisée (raccourci Espace)', () async {
    final c = await makeController();
    await c.setMode(SessionMode.pause);
    c.startSession(2);

    c.validateSet();
    c.pickDuration(90);
    c.pause();

    expect(c.lastPause, 90);
    expect(c.defaultDuration(), 90);
    c.dispose();
  });

  test('formatTime formate correctement', () {
    expect(formatTime(45), '45s');
    expect(formatTime(60), '1:00');
    expect(formatTime(90), '1:30');
    expect(formatTime(125), '2:05');
  });
}
