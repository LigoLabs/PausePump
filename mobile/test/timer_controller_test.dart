import 'package:flutter_test/flutter_test.dart';
import 'package:pausepump/models/enums.dart';
import 'package:pausepump/services/audio_service.dart';
import 'package:pausepump/services/foreground_service.dart';
import 'package:pausepump/services/live_activity_service.dart';
import 'package:pausepump/services/notification_service.dart';
import 'package:pausepump/services/storage.dart';
import 'package:pausepump/services/wakelock_service.dart';
import 'package:pausepump/services/watch_sync_service.dart';
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
      liveActivity: LiveActivityService(supported: false),
      watchSync: WatchSyncService(supported: false),
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

  test('Mode effort : currentSeries et la timeline suivent le compteur',
      () async {
    final c = await makeController();
    await c.setMode(SessionMode.effort);
    c.setEffortAuto(false); // étape par étape : pilotable sans timers réels
    await c.updateSettings(c.settings.copyWith(prepCountdown: false));
    c.startSession(2);

    expect(c.step, SessionStep.duration);
    expect(c.currentSeries, 1);

    c.pickDuration(30); // effort série 1
    c.skip(); // → choix de la pause
    expect(c.currentSeries, 1);

    c.pickDuration(45); // pause série 1
    c.skip(); // fin de série 1 → effort série 2
    expect(c.seriesRemaining, 1);
    expect(c.currentSeries, 2, reason: 'on attaque la série 2');
    expect(c.tlDots, 1, reason: 'la timeline suit le compteur en mode effort');
    expect(c.tlBars, 1);

    c.pickDuration(30);
    c.skip();
    c.pickDuration(45);
    c.skip(); // fin de la dernière série
    expect(c.step, SessionStep.done);
    c.dispose();
  });

  test('Setup effort manuel : Démarrer passe par le choix de durée effort',
      () async {
    final c = await makeController();
    await c.setMode(SessionMode.effort);
    await c.updateSettings(c.settings.copyWith(prepCountdown: false));
    c.startSession(3); // effortAuto=true par défaut → écran setup
    expect(c.step, SessionStep.setup);

    c.setEffortAuto(false); // l'utilisateur décoche l'enchaînement auto
    c.startEffortManual(); // bouton « Démarrer ▶ »
    expect(c.step, SessionStep.duration);
    expect(c.durationTitle, contains('Effort'));

    c.pickDuration(30);
    expect(c.phase, Phase.effort, reason: 'la 1re phase lancée est un effort');
    expect(c.running, isTrue);
    c.pause();
    c.dispose();
  });
}
