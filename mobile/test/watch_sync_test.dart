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

  const channel = MethodChannel('pausepump/watch_sync');
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

  Future<void> flushChannel() => Future<void>.delayed(Duration.zero);

  test('pushContext envoie la config complète', () async {
    final svc = WatchSyncService(supported: true);
    await svc.pushContext(
      lastPause: 90,
      mode: 'pause',
      alarm: 'bell',
      vibrate: true,
      sound: true,
      volume: 0.8,
    );

    expect(calls.single.method, 'updateContext');
    final args = Map<String, Object?>.from(calls.single.arguments as Map);
    expect(args['lastPause'], 90);
    expect(args['mode'], 'pause');
    expect(args['alarm'], 'bell');
    expect(args['vibrate'], true);
    expect(args['sound'], true);
    expect(args['volume'], 0.8);
  });

  test('le contrôleur pousse le contexte à la construction, au changement de '
      'mode, de durée et de réglages', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await Storage.open();
    final c = TimerController(
      storage: storage,
      audio: AudioService(),
      notifications: NotificationService(),
      wakelock: WakelockService(),
      foreground: ForegroundService(),
      liveActivity: LiveActivityService(supported: false),
      watchSync: WatchSyncService(supported: true),
    );
    await flushChannel();
    expect(calls, hasLength(1), reason: 'push initial à la construction');
    calls.clear();

    await c.setMode(SessionMode.effort);
    await flushChannel();
    expect(calls, hasLength(1));
    expect(
      Map<String, Object?>.from(calls.single.arguments as Map)['mode'],
      'effort',
    );
    calls.clear();

    await c.setMode(SessionMode.pause);
    c.startSession(2);
    c.validateSet();
    calls.clear();

    c.pickDuration(120); // mémorise la dernière pause → push
    await flushChannel();
    expect(calls, hasLength(1));
    expect(
      Map<String, Object?>.from(calls.single.arguments as Map)['lastPause'],
      120,
    );
    calls.clear();

    await c.updateSettings(c.settings.copyWith(vibrate: false));
    await flushChannel();
    expect(calls, hasLength(1));
    expect(
      Map<String, Object?>.from(calls.single.arguments as Map)['vibrate'],
      false,
    );

    c.pause();
    c.dispose();
  });
}
