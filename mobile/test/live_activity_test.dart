import 'package:flutter/services.dart';
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

  const channel = MethodChannel('pausepump/live_activity');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// Laisse les invocations de MethodChannel (fire-and-forget) se vider.
  Future<void> flushChannel() => Future<void>.delayed(Duration.zero);

  group('LiveActivityService', () {
    test('start envoie endTime/startTime/label/séries sur le canal', () async {
      final svc = LiveActivityService(supported: true);
      final end = DateTime.now().add(const Duration(seconds: 90));
      final start = end.subtract(const Duration(seconds: 90));
      await svc.start(
        endTime: end,
        startTime: start,
        label: 'Pause',
        seriesCurrent: 2,
        seriesTotal: 5,
        isEffort: false,
      );

      expect(calls, hasLength(1));
      expect(calls.single.method, 'start');
      final args = Map<String, Object?>.from(calls.single.arguments as Map);
      expect(args['endTime'], end.millisecondsSinceEpoch);
      expect(args['startTime'], start.millisecondsSinceEpoch);
      expect(args['label'], 'Pause');
      expect(args['seriesCurrent'], 2);
      expect(args['seriesTotal'], 5);
      expect(args['isEffort'], false);
    });

    test('pause envoie le temps restant figé', () async {
      final svc = LiveActivityService(supported: true);
      await svc.pause(
        remaining: 42.5,
        label: 'Effort 💪',
        seriesCurrent: 1,
        seriesTotal: 3,
        isEffort: true,
      );

      expect(calls.single.method, 'pause');
      final args = Map<String, Object?>.from(calls.single.arguments as Map);
      expect(args['remaining'], 42.5);
      expect(args['isEffort'], true);
    });

    test('non supporté → aucun appel de canal', () async {
      final svc = LiveActivityService(supported: false);
      await svc.start(
        endTime: DateTime.now(),
        startTime: DateTime.now(),
        label: 'Pause',
        seriesCurrent: 1,
        seriesTotal: 3,
        isEffort: false,
      );
      await svc.end();
      expect(calls, isEmpty);
    });

    test('erreur de plateforme silencieuse (pas de crash)', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'UNAVAILABLE');
      });
      final svc = LiveActivityService(supported: true);
      await expectLater(svc.end(), completes);
    });
  });

  group('TimerController → Live Activity', () {
    Future<TimerController> makeController() async {
      SharedPreferences.setMockInitialValues({});
      final storage = await Storage.open();
      return TimerController(
        storage: storage,
        audio: AudioService(),
        notifications: NotificationService(),
        wakelock: WakelockService(),
        foreground: ForegroundService(),
        liveActivity: LiveActivityService(supported: true),
        watchSync: WatchSyncService(supported: false),
      );
    }

    test('séance Pause seule : end (orpheline) → idle → idle → start → pause → end',
        () async {
      final c = await makeController();
      await flushChannel();
      // À la construction : nettoyage d'une activité orpheline.
      expect(calls.map((c) => c.method), ['end']);
      calls.clear();

      c.startSession(3); // → écran « Fais ta série »
      await flushChannel();
      expect(calls.single.method, 'idle');
      var args = Map<String, Object?>.from(calls.single.arguments as Map);
      expect(args['label'], 'Fais ta 1re série 💪');
      expect(args['seriesCurrent'], 1);
      expect(args['seriesTotal'], 3);
      calls.clear();

      c.validateSet(); // → choix de durée
      await flushChannel();
      expect(calls.single.method, 'idle');
      args = Map<String, Object?>.from(calls.single.arguments as Map);
      expect(args['label'], 'Choisis ta pause');
      calls.clear();

      final before = DateTime.now();
      c.pickDuration(60); // → décompte
      await flushChannel();
      expect(calls.single.method, 'start');
      args = Map<String, Object?>.from(calls.single.arguments as Map);
      final endMs = args['endTime'] as int;
      expect(
        endMs - before.millisecondsSinceEpoch,
        inInclusiveRange(59000, 61500),
        reason: 'endTime ≈ maintenant + 60 s',
      );
      expect(args['startTime'], endMs - 60000,
          reason: 'startTime = endTime − durée (origine de la barre)');
      expect(args['label'], 'Pause');
      expect(args['isEffort'], false);
      calls.clear();

      c.pause();
      await flushChannel();
      expect(calls.single.method, 'pause');
      args = Map<String, Object?>.from(calls.single.arguments as Map);
      expect(args['remaining'], isA<double>());
      calls.clear();

      c.quitToHome();
      await flushChannel();
      expect(calls.map((c) => c.method), contains('end'));

      c.dispose();
    });

    test('mode Effort (étape par étape) : le start relaie isEffort=true',
        () async {
      final c = await makeController();
      await c.setMode(SessionMode.effort);
      c.setEffortAuto(false); // étape par étape : séance → choix durée effort
      await c.updateSettings(c.settings.copyWith(prepCountdown: false));
      c.startSession(2);
      await flushChannel();
      calls.clear();

      c.pickDuration(45); // phase effort
      await flushChannel();

      final start = calls.lastWhere((m) => m.method == 'start');
      final args = Map<String, Object?>.from(start.arguments as Map);
      expect(args['isEffort'], true);
      expect(args['label'], 'Effort 💪');

      c.pause();
      c.dispose();
    });
  });
}
