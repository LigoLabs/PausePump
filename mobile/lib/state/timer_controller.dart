import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../models/app_settings.dart';
import '../models/enums.dart';
import '../services/audio_service.dart';
import '../services/foreground_service.dart';
import '../services/live_activity_service.dart';
import '../services/notification_service.dart';
import '../services/storage.dart';
import '../services/wakelock_service.dart';
import '../services/watch_sync_service.dart';

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
    required this.foreground,
    required this.liveActivity,
    required this.watchSync,
  }) {
    _settings = storage.loadSettings();
    _lastPause = storage.loadLastPause();
    mode = storage.loadMode() == 'effort' ? SessionMode.effort : SessionMode.pause;
    seriesSel = storage.loadSeries();
    effortSel = storage.loadEffort();
    restSel = storage.loadRest();
    effortAuto = storage.loadEffortAuto();
    WidgetsBinding.instance.addObserver(this);
    liveActivity.end(); // activité orpheline d'un lancement précédent
    notifications.cancelAll(); // notif de fin orpheline d'un timer tué
    audio.prepareAlarm(_settings.alarm); // bip prêt → part sans délai
    _pushWatchContext();
  }

  final Storage storage;
  final AudioService audio;
  final NotificationService notifications;
  final WakelockService wakelock;
  final ForegroundService foreground;
  final LiveActivityService liveActivity;
  final WatchSyncService watchSync;

  // ---- Config & réglages ----
  late AppSettings _settings;
  AppSettings get settings => _settings;

  SessionMode mode = SessionMode.pause;
  bool effortAuto = true;

  int _lastPause = 60;
  int effortSel = 60;
  int restSel = 60;
  int seriesSel = 3; // dernier nombre de séries choisi (persisté)

  /// Durées proposées dans les grilles : les timers enregistrés, triés.
  List<int> get timers => _settings.sortedTimers;

  /// Message éphémère à afficher (snackbar) — consommé par l'UI.
  String? toastMessage;
  String? consumeToast() {
    final m = toastMessage;
    toastMessage = null;
    return m;
  }

  // ---- État de séance ----
  bool inSession = false;
  SessionStep step = SessionStep.duration;
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
  VoidCallback? _countdownDone;

  int get lastPause => _lastPause;
  bool get isEnding => remaining <= 5 && remaining > 0;
  int get currentSeries {
    final t = seriesTotal == 0 ? 1 : seriesTotal;
    // Mode pause : les points suivent la validation des séries (tlDots).
    // Mode effort : dérivé du compteur (parité avec le web).
    final raw = mode == SessionMode.effort ? t - seriesRemaining + 1 : tlDots + 1;
    return raw.clamp(1, t).toInt();
  }

  // ===========================================================================
  //  Réglages
  // ===========================================================================
  Future<void> updateSettings(AppSettings s) async {
    final old = _settings;
    _settings = s;
    await storage.saveSettings(s);
    if (s.alarm != old.alarm) audio.prepareAlarm(s.alarm);
    // Effets immédiats, comme sur le web (wake lock, notif replanifiée…).
    if (!s.keepAwake) {
      wakelock.disable();
    } else if (running) {
      wakelock.enable();
    }
    if (!s.notify) {
      notifications.cancelEnd();
    } else if (running && _endTime != null && !_foreground) {
      _scheduleEndNotification(); // nouveau son / réglage de notif pris en compte
    }
    if (s.notify && !old.notify) notifications.requestPermission();
    _pushWatchContext();
    notifyListeners();
  }

  // ===========================================================================
  //  Démarrage d'une séance
  // ===========================================================================
  Future<void> setMode(SessionMode m) async {
    mode = m;
    await storage.saveMode(m.name);
    _pushWatchContext();
    notifyListeners();
  }

  void setSeriesSel(int n) {
    seriesSel = n;
    storage.saveSeries(n);
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
      step = SessionStep.setup; // on règle effort + pause puis on lance
    } else {
      _showDurationPick(Phase.effort); // étape par étape : on commence par l'effort
    }
    notifyListeners();
  }

  void setEffortAuto(bool v) {
    effortAuto = v;
    storage.saveEffortAuto(v);
    notifyListeners();
  }

  void setEffortSel(int d) {
    effortSel = d;
    storage.saveEffort(d);
    notifyListeners();
  }

  void setRestSel(int d) {
    restSel = d;
    storage.saveRest(d);
    notifyListeners();
  }

  /// Démarre l'enchaînement auto (depuis l'écran setup).
  void startEffortAuto() {
    _runCountdown(kCountdownAuto, () => _startPhase(Phase.effort, effortSel));
  }

  /// Démarre le mode étape par étape depuis l'écran setup (l'utilisateur a
  /// désactivé l'enchaînement auto) : on choisit d'abord la durée d'effort.
  void startEffortManual() {
    _showDurationPick(Phase.effort);
  }

  void _showDoSet() {
    _stopTicker();
    foreground.stop();
    step = SessionStep.doSet;
    liveActivity.idle(
      label: 'Fais ta ${_ordinal(currentSeries)} série 💪',
      seriesCurrent: currentSeries,
      seriesTotal: seriesTotal,
    );
    notifyListeners();
  }

  void _showDurationPick(Phase forPhase) {
    foreground.stop();
    _pickPhase = forPhase;
    step = SessionStep.duration;
    liveActivity.idle(
      label: durationTitle,
      seriesCurrent: currentSeries,
      seriesTotal: seriesTotal,
    );
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
      _pushWatchContext();
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
      storage.saveEffort(d);
      if (_settings.prepCountdown) {
        _runCountdown(kCountdownPrep, () => _startPhase(Phase.effort, d));
      } else {
        _startPhase(Phase.effort, d);
      }
    } else {
      restSel = d;
      storage.saveRest(d);
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
    step = SessionStep.timer;
    _resume();
    notifyListeners();
  }

  void _resume() {
    if (running) return;
    running = true;
    _endTime = DateTime.now().add(
      Duration(milliseconds: (remaining * 1000).round()),
    );
    // Re-précharge le bip (un aperçu dans les réglages a pu charger un autre
    // son) : la fin de phase doit sonner sans délai.
    if (_settings.sound) audio.prepareAlarm(_settings.alarm);
    // La notif de fin n'est armée qu'en arrière-plan (comme le web au
    // visibilitychange) : au 1er plan le bip in-app sonne, et planifier une
    // notif au même instant créerait une course (bip + notif = double son).
    if (!_foreground) _scheduleEndNotification();
    // Chrono natif dans la notification persistante (Android).
    foreground.start(_endTime!, title: 'PausePump', label: _phaseLabel());
    // Chrono natif sur l'écran verrouillé / Dynamic Island (iOS).
    _liveActivityStart();
    if (_settings.keepAwake) wakelock.enable();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
  }

  void pause() {
    if (!running) return;
    running = false;
    _stopTicker();
    notifications.cancelEnd();
    foreground.stop();
    liveActivity.pause(
      remaining: remaining,
      label: _phaseLabel(),
      seriesCurrent: currentSeries,
      seriesTotal: seriesTotal,
      isEffort: _isEffortPhase,
    );
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
      if (!_foreground) _scheduleEndNotification();
      foreground.start(_endTime!, title: 'PausePump', label: _phaseLabel());
      _liveActivityStart();
    } else {
      // Timer en pause : la Live Activity doit refléter le restant remis à zéro.
      liveActivity.pause(
        remaining: remaining,
        label: _phaseLabel(),
        seriesCurrent: currentSeries,
        seriesTotal: seriesTotal,
        isEffort: _isEffortPhase,
      );
    }
    notifyListeners();
  }

  String _phaseLabel() {
    if (mode == SessionMode.pause) return 'Pause';
    return phase == Phase.effort ? 'Effort 💪' : 'Pause 😮‍💨';
  }

  bool get _isEffortPhase => mode == SessionMode.effort && phase == Phase.effort;

  void _liveActivityStart() {
    final end = _endTime;
    if (end == null) return;
    liveActivity.start(
      endTime: end,
      // Origine visuelle de la barre de progression : constante pour toute la
      // phase (y compris après une reprise), sinon la barre repart de zéro.
      startTime: end.subtract(Duration(seconds: durationSec)),
      label: _phaseLabel(),
      seriesCurrent: currentSeries,
      seriesTotal: seriesTotal,
      isEffort: _isEffortPhase,
    );
  }

  /// Republie l'état courant sur la Live Activity (après un +/- de séries…).
  void _pushLiveActivitySnapshot() {
    if (!inSession) return;
    if (running) {
      _liveActivityStart();
    } else if (step == SessionStep.timer) {
      liveActivity.pause(
        remaining: remaining,
        label: _phaseLabel(),
        seriesCurrent: currentSeries,
        seriesTotal: seriesTotal,
        isEffort: _isEffortPhase,
      );
    } else if (step == SessionStep.doSet) {
      liveActivity.idle(
        label: 'Fais ta ${_ordinal(currentSeries)} série 💪',
        seriesCurrent: currentSeries,
        seriesTotal: seriesTotal,
      );
    } else if (step == SessionStep.duration) {
      liveActivity.idle(
        label: durationTitle,
        seriesCurrent: currentSeries,
        seriesTotal: seriesTotal,
      );
    }
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

  /// [playAlarm] : false au rattrapage de retour au 1er plan — la fin a déjà
  /// sonné à l'heure pile en arrière-plan, on ne rejoue pas le bip.
  void _onPhaseComplete({bool playAlarm = true}) {
    running = false;
    _stopTicker();
    if (_foreground) {
      // 1er plan : le bip in-app sonne (flux média — l'app est visible, comme
      // le web) ; la notif planifiée n'a plus lieu d'être.
      notifications.cancelEnd();
      if (playAlarm && _settings.sound) {
        audio.playAlarm(_settings.alarm, _settings.volume);
      }
      if (_settings.vibrate) HapticFeedback.heavyImpact();
    } else if (playAlarm && !kIsWeb && Platform.isAndroid && !_settings.notify) {
      // Arrière-plan, notifs désactivées : aucune notif armée — le bip in-app
      // (process vivant sous le foreground service) reste le seul signal.
      if (_settings.sound) {
        audio.playAlarm(_settings.alarm, _settings.volume);
      }
    }
    // Arrière-plan avec notifs : on ne touche à RIEN — la notif planifiée
    // délivrée par l'OS porte le son (canal alarme → flux ALARME, audible
    // écran verrouillé et volume média à zéro). L'ancien comportement
    // (cancelEnd + bip in-app sur le flux MÉDIA) coupait le son d'alarme
    // au bout de quelques ms et le remplaçait par un bip souvent inaudible.
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
        _syncEffortTimeline();
        sessionEnd = seriesRemaining <= 0;
        if (!sessionEnd) autoNext = Phase.effort;
      }
    } else {
      if (phase == Phase.effort) {
        manualNext = Phase.pause;
      } else {
        _adjustSeries(-1);
        _syncEffortTimeline();
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

  /// ⟲ Durée : revient au choix de durée de l'étape en cours (port de
  /// `backToChoice` web) sans faire avancer la séance.
  void backToChoice() {
    pause();
    if (mode == SessionMode.pause) {
      _showDurationPick(Phase.pause);
      return;
    }
    if (effortAuto) {
      step = SessionStep.setup;
      notifyListeners();
    } else {
      _showDurationPick(phase); // re-choisir la durée de l'étape en cours
    }
  }

  void _finish() {
    _stopTicker();
    running = false;
    // En arrière-plan, la notif de fin vient d'être délivrée (c'est elle qui
    // sonne) : l'annuler ici couperait le bip. Le retour au 1er plan purge.
    if (_foreground) notifications.cancelAll();
    foreground.stop();
    liveActivity.end();
    wakelock.disable();
    if (_settings.endScreen) {
      step = SessionStep.done;
    } else {
      inSession = false; // retour accueil
      toastMessage = 'Séance terminée 🎉';
    }
    notifyListeners();
  }

  /// Relance une séance avec le même total (ajustements +/- inclus) — choix
  /// assumé, léger écart avec le web qui repart de la sélection d'origine ;
  /// même sémantique que le moteur watch (WorkoutEngine.restart).
  void restart() {
    startSession(seriesTotal);
  }

  void quitToHome() {
    pause();
    notifications.cancelAll();
    foreground.stop();
    liveActivity.end();
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

  /// Mode effort : la timeline suit le compteur (une série = effort + pause).
  void _syncEffortTimeline() {
    tlDots = (seriesTotal - seriesRemaining).clamp(0, 1 << 31).toInt();
    tlBars = tlDots;
  }

  void addSeries() {
    seriesTotal += 1;
    _adjustSeries(1);
    _pushLiveActivitySnapshot();
    notifyListeners();
  }

  void removeSeries() {
    if (seriesRemaining <= 0) return;
    seriesTotal = (seriesTotal - 1).clamp(1, 1 << 31).toInt();
    _adjustSeries(-1);
    _pushLiveActivitySnapshot();
    notifyListeners();
  }

  // ===========================================================================
  //  Décompte « 3, 2, 1, GO »
  // ===========================================================================
  void _runCountdown(int from, VoidCallback onDone) {
    _countdownTimer?.cancel();
    _countdownDone = onDone;
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
        // Timer (et non Future.delayed) : annulable par skip/dispose, sinon
        // un callback périmé pourrait relancer après coup.
        _countdownTimer = Timer(const Duration(milliseconds: 550), _launchCountdown);
      } else {
        countdownValue = v;
        _countBeep(false);
        _haptic();
        notifyListeners();
      }
    });
  }

  /// Tap sur l'overlay : on démarre tout de suite (comme le web).
  void skipCountdown() => _launchCountdown();

  void _launchCountdown() {
    final done = _countdownDone;
    if (done == null) return; // déjà lancé
    _countdownDone = null;
    _countdownTimer?.cancel();
    countdownValue = null;
    notifyListeners();
    done();
  }

  // ===========================================================================
  //  Cycle de vie applicatif
  // ===========================================================================
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _foreground;
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      // Passage en arrière-plan : on arme la notif de fin maintenant (émise
      // une seule fois, comme le web sur visibilitychange).
      if (wasForeground && running && _endTime != null) {
        _scheduleEndNotification();
      }
      return;
    }
    notifications.cancelAll();
    if (running && _endTime != null) {
      // Rattrapage : le décompte a pu se figer en arrière-plan.
      remaining = _endTime!.difference(DateTime.now()).inMilliseconds / 1000.0;
      if (remaining <= 0) {
        remaining = 0;
        _onPhaseComplete(playAlarm: false); // la notif a déjà sonné
      } else {
        notifyListeners();
      }
    }
  }

  // ===========================================================================
  //  Helpers
  // ===========================================================================
  /// Corps de la notif de fin pour la phase EN COURS (avant transition).
  String get _endBody {
    final label = mode == SessionMode.effort
        ? (phase == Phase.effort ? 'Effort terminé 💪' : 'Pause terminée 😮‍💨')
        : 'Pause terminée';
    return '$label • à toi de jouer !';
  }

  void _scheduleEndNotification() {
    if (!_settings.notify || _endTime == null) return;
    notifications.scheduleEnd(
      _endTime!,
      body: _endBody,
      // Bip perso activé → la notif joue le bip de l'app, quel que soit le
      // réglage « Son à la notification » (qui ne gouverne que la tonalité
      // système de secours) — parité web : le bip perso sonne toujours.
      alarm: _settings.sound ? _settings.alarm : null,
      playSound: _settings.sound || _settings.notifySound,
    );
  }

  void _pushWatchContext() {
    watchSync.pushContext(
      lastPause: _lastPause,
      mode: mode.name,
      alarm: _settings.alarm.name,
      vibrate: _settings.vibrate,
      sound: _settings.sound,
      volume: _settings.volume,
    );
  }

  String _ordinal(int n) => n == 1 ? '1re' : '${n}e';

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
