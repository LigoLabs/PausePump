import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../models/app_settings.dart';
import '../models/enums.dart';
import '../services/audio_service.dart';
import '../services/notification_service.dart';
import '../services/storage.dart';
import '../services/wakelock_service.dart';

/// Durées de timer proposées (secondes).
const List<int> kDurations = [30, 45, 60, 90, 120, 150, 180, 300];
const List<int> kSeriesChoices = [1, 2, 3, 4, 5, 6];
const int kCountdownPrep = 3;
const int kCountdownAuto = 3;

String formatTime(num totalSeconds) {
  final s = totalSeconds.round().clamp(0, 1 << 31);
  final m = s ~/ 60;
  final sec = s % 60;
  if (m == 0) return '${sec}s';
  return '$m:${sec.toString().padLeft(2, '0')}';
}

/// Source de vérité de la séance : machine à états (port de `advancePhase` web)
/// + progression de la timeline + pilotage des services (son, notif, wakelock).
class TimerController extends ChangeNotifier with WidgetsBindingObserver {
  TimerController({
    required this.storage,
    required this.audio,
    required this.notifications,
    required this.wakelock,
  }) {
    _settings = storage.loadSettings();
    _lastPause = storage.loadLastPause();
    mode = storage.loadMode() == 'effort' ? SessionMode.effort : SessionMode.pause;
    WidgetsBinding.instance.addObserver(this);
  }

  final Storage storage;
  final AudioService audio;
  final NotificationService notifications;
  final WakelockService wakelock;

  // ---- Config & réglages ----
  late AppSettings _settings;
  AppSettings get settings => _settings;

  SessionMode mode = SessionMode.pause;
  bool effortAuto = true;

  int _lastPause = 60;
  int effortSel = 60;
  int restSel = 60;

  // ---- État de séance ----
  bool inSession = false;
  Step step = Step.duration;
  Phase phase = Phase.pause;
  Phase _pickPhase = Phase.pause; // en manuel : quelle phase on choisit

  int seriesTotal = 0;
  int seriesRemaining = 0;

  // ---- Timeline ----
  int tlDots = 0; // séries validées (points pleins)
  int tlBars = 0; // pauses terminées (barres pleines)
  double tlFrac = 0; // remplissage 0..1 de la barre en cours

  // ---- Décompte ----
  int durationSec = 0;
  double remaining = 0;
  bool running = false;
  Timer? _ticker;
  DateTime? _endTime;
  bool _foreground = true;

  // ---- Overlay « 3, 2, 1 » ----
  int? countdownValue; // null = pas de décompte ; -1 = « GO »
  Timer? _countdownTimer;

  int get lastPause => _lastPause;
  bool get isEnding => remaining <= 5 && remaining > 0;
  int get currentSeries {
    final t = seriesTotal == 0 ? 1 : seriesTotal;
    return (tlDots + 1).clamp(1, t).toInt();
  }

  // ===========================================================================
  //  Réglages
  // ===========================================================================
  Future<void> updateSettings(AppSettings s) async {
    _settings = s;
    await storage.saveSettings(s);
    notifyListeners();
  }

  // ===========================================================================
  //  Démarrage d'une séance
  // ===========================================================================
  Future<void> setMode(SessionMode m) async {
    mode = m;
    await storage.saveMode(m.name);
    notifyListeners();
  }

  void startSession(int series) {
    inSession = true;
    seriesTotal = series;
    seriesRemaining = series;
    tlDots = 0;
    tlBars = 0;
    tlFrac = 0;
    if (_settings.notify) notifications.requestPermission();

    if (mode == SessionMode.pause) {
      if (_settings.doSetScreen) {
        _showDoSet();
      } else {
        _showDurationPick(Phase.pause);
      }
    } else if (effortAuto) {
      step = Step.setup; // on règle effort + pause puis on lance
    } else {
      _showDurationPick(Phase.effort); // étape par étape : on commence par l'effort
    }
    notifyListeners();
  }

  void setEffortAuto(bool v) {
    effortAuto = v;
    notifyListeners();
  }

  void setEffortSel(int d) {
    effortSel = d;
    notifyListeners();
  }

  void setRestSel(int d) {
    restSel = d;
    notifyListeners();
  }

  /// Démarre l'enchaînement auto (depuis l'écran setup).
  void startEffortAuto() {
    _runCountdown(kCountdownAuto, () => _startPhase(Phase.effort, effortSel));
  }

  void _showDoSet() {
    _stopTicker();
    step = Step.doSet;
    notifyListeners();
  }

  void _showDurationPick(Phase forPhase) {
    _pickPhase = forPhase;
    step = Step.duration;
    notifyListeners();
  }

  /// Dernière durée par défaut pour la phase en cours (raccourci « relancer »).
  int defaultDuration() {
    if (mode == SessionMode.pause) return _lastPause;
    return _pickPhase == Phase.effort ? effortSel : restSel;
  }

  String get durationTitle {
    if (mode == SessionMode.pause) return 'Choisis ta pause';
    return _pickPhase == Phase.effort
        ? '💪 Effort — choisis la durée'
        : '😮‍💨 Pause — choisis la durée';
  }

  // ===========================================================================
  //  Validation d'une série / choix de durée
  // ===========================================================================
  /// Bouton « J'ai fait ma série » (Pause seule, écran activé).
  void validateSet() {
    tlDots = (tlDots + 1).clamp(0, seriesTotal).toInt();
    _adjustSeries(-1); // compteur −1 dès la validation
    _haptic();
    _showDurationPick(Phase.pause);
  }

  void pickDuration(int d) {
    if (mode == SessionMode.pause) {
      _lastPause = d;
      storage.saveLastPause(d);
      if (!_settings.doSetScreen) {
        tlDots = (tlDots + 1).clamp(0, seriesTotal).toInt();
        _adjustSeries(-1);
      }
      _startPhase(Phase.pause, d);
      return;
    }
    // Effort + Pause, étape par étape
    if (_pickPhase == Phase.effort) {
      effortSel = d;
      if (_settings.prepCountdown) {
        _runCountdown(kCountdownPrep, () => _startPhase(Phase.effort, d));
      } else {
        _startPhase(Phase.effort, d);
      }
    } else {
      restSel = d;
      _startPhase(Phase.pause, d);
    }
  }

  /// Raccourci clavier Espace : relance la dernière durée.
  void quickLaunchDefault() => pickDuration(defaultDuration());

  // ===========================================================================
  //  Minuteur
  // ===========================================================================
  void _startPhase(Phase p, int dur) {
    phase = p;
    durationSec = dur;
    remaining = dur.toDouble();
    step = Step.timer;
    _resume();
    notifyListeners();
  }

  void _resume() {
    if (running) return;
    running = true;
    _endTime = DateTime.now().add(
      Duration(milliseconds: (remaining * 1000).round()),
    );
    _scheduleEndNotification();
    if (_settings.keepAwake) wakelock.enable();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
  }

  void pause() {
    if (!running) return;
    running = false;
    _stopTicker();
    notifications.cancelEnd();
    wakelock.disable();
    notifyListeners();
  }

  void togglePlayPause() {
    if (running) {
      pause();
    } else {
      _resume();
      notifyListeners();
    }
  }

  void resetPhase() {
    remaining = durationSec.toDouble();
    if (running) {
      _endTime = DateTime.now().add(Duration(seconds: durationSec));
      _scheduleEndNotification();
    }
    notifyListeners();
  }

  void _tick() {
    final end = _endTime;
    if (end == null) return;
    remaining = end.difference(DateTime.now()).inMilliseconds / 1000.0;
    if (remaining <= 0) {
      remaining = 0;
      _onPhaseComplete();
      return;
    }
    if (mode == SessionMode.pause) {
      tlFrac = durationSec > 0 ? 1 - (remaining / durationSec) : 0.0;
    }
    notifyListeners();
  }

  void _onPhaseComplete() {
    running = false;
    _stopTicker();
    // En 1er plan, on joue le bip et on annule la notif (sinon double son).
    if (_foreground) {
      notifications.cancelEnd();
      if (_settings.sound) audio.playAlarm(_settings.alarm, _settings.volume);
      if (_settings.vibrate) HapticFeedback.heavyImpact();
    }
    _advancePhase();
  }

  // ===========================================================================
  //  Transition de phase — source unique de vérité (port de `advancePhase`)
  // ===========================================================================
  void _advancePhase() {
    bool sessionEnd = false;
    Phase? autoNext;
    Phase? manualNext;

    if (mode == SessionMode.pause) {
      tlBars = tlDots; // la pause est finie → barre pleine
      tlFrac = 0;
      sessionEnd = seriesRemaining <= 0;
    } else if (effortAuto) {
      if (phase == Phase.effort) {
        autoNext = Phase.pause;
      } else {
        _adjustSeries(-1);
        sessionEnd = seriesRemaining <= 0;
        if (!sessionEnd) autoNext = Phase.effort;
      }
    } else {
      if (phase == Phase.effort) {
        manualNext = Phase.pause;
      } else {
        _adjustSeries(-1);
        sessionEnd = seriesRemaining <= 0;
        if (!sessionEnd) manualNext = Phase.effort;
      }
    }

    if (sessionEnd) {
      _finish();
      return;
    }
    if (autoNext != null) {
      _startPhase(autoNext, autoNext == Phase.pause ? restSel : effortSel);
      return;
    }
    wakelock.disable();
    if (manualNext != null) {
      _showDurationPick(manualNext);
    } else if (_settings.doSetScreen) {
      _showDoSet(); // Pause seule : « Fais ta série » avant la prochaine pause
    } else {
      _showDurationPick(Phase.pause);
    }
  }

  /// ⏭ Suivante : même logique qu'une fin de phase naturelle.
  void skip() {
    pause();
    _advancePhase();
  }

  void _finish() {
    _stopTicker();
    running = false;
    notifications.cancelAll();
    wakelock.disable();
    if (_settings.endScreen) {
      step = Step.done;
    } else {
      inSession = false; // retour accueil
    }
    notifyListeners();
  }

  void restart() {
    startSession(seriesTotal);
  }

  void quitToHome() {
    pause();
    notifications.cancelAll();
    wakelock.disable();
    inSession = false;
    notifyListeners();
  }

  // ===========================================================================
  //  Compteur de séries
  // ===========================================================================
  void _adjustSeries(int delta) {
    seriesRemaining = (seriesRemaining + delta).clamp(0, 1 << 31).toInt();
  }

  void addSeries() {
    seriesTotal += 1;
    _adjustSeries(1);
    notifyListeners();
  }

  void removeSeries() {
    if (seriesRemaining <= 0) return;
    seriesTotal = (seriesTotal - 1).clamp(1, 1 << 31).toInt();
    _adjustSeries(-1);
    notifyListeners();
  }

  // ===========================================================================
  //  Décompte « 3, 2, 1, GO »
  // ===========================================================================
  void _runCountdown(int from, VoidCallback onDone) {
    _countdownTimer?.cancel();
    countdownValue = from;
    _countBeep(false);
    _haptic();
    notifyListeners();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final v = (countdownValue ?? 1) - 1;
      if (v <= 0) {
        t.cancel();
        countdownValue = -1; // « GO »
        _countBeep(true);
        if (_settings.vibrate) HapticFeedback.mediumImpact();
        notifyListeners();
        Future.delayed(const Duration(milliseconds: 550), () {
          countdownValue = null;
          notifyListeners();
          onDone();
        });
      } else {
        countdownValue = v;
        _countBeep(false);
        _haptic();
        notifyListeners();
      }
    });
  }

  // ===========================================================================
  //  Cycle de vie applicatif
  // ===========================================================================
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      notifications.cancelAll();
      if (running && _endTime != null) {
        // Rattrapage : le décompte a pu se figer en arrière-plan.
        remaining = _endTime!.difference(DateTime.now()).inMilliseconds / 1000.0;
        if (remaining <= 0) {
          remaining = 0;
          _onPhaseComplete();
        } else {
          notifyListeners();
        }
      }
    }
  }

  // ===========================================================================
  //  Helpers
  // ===========================================================================
  void _scheduleEndNotification() {
    if (!_settings.notify || _endTime == null) return;
    final label = mode == SessionMode.effort
        ? (phase == Phase.effort ? 'Effort terminé 💪' : 'Pause terminée 😮‍💨')
        : 'Pause terminée';
    notifications.scheduleEnd(_endTime!, body: '$label • à toi de jouer !');
  }

  void _countBeep(bool go) {
    if (_settings.volume <= 0) return;
    if (go) {
      audio.go(_settings.volume);
    } else {
      audio.tick(_settings.volume);
    }
  }

  void _haptic() {
    if (_settings.vibrate) HapticFeedback.selectionClick();
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _stopTicker();
    _countdownTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
