'use strict';

/* ====================================================================
   PausePump — minuteur de pauses & efforts pour la muscu.
   Vanilla JS, mobile-first, installable, hors-ligne (PWA).
   ==================================================================== */

const SERIES_CHOICES = [1, 2, 3, 4, 5, 6];
const DEFAULT_TIMERS = [30, 45, 60, 90, 120, 150, 180, 300]; // secondes
const ENDING_THRESHOLD = 5;            // s : passage au rouge
const RING_CIRCUMFERENCE = 2 * Math.PI * 100;

// Sons de bip disponibles (générés via Web Audio, sans fichier).
// Chaque son est synthétisé avec un timbre riche : plusieurs partiels (harmoniques
// ou inharmoniques pour les cloches/marimbas) + enveloppe percussive naturelle.
// Inspiré des minuteurs de salle/boxe : net, présent, jamais grêle.
const TIMBRE = {
  pure:    [{ r: 1, g: 1 }],
  soft:    [{ r: 1, g: 1 }, { r: 2, g: 0.16 }],
  // Partiels inharmoniques d'une cloche réelle → rendu métallique chaud.
  bell:    [{ r: 1, g: 1 }, { r: 2.01, g: 0.5 }, { r: 2.76, g: 0.33 }, { r: 3.94, g: 0.22 }, { r: 5.42, g: 0.15 }, { r: 8.2, g: 0.08 }],
  // Marimba/bois : fondamentale + harmoniques impaires qui s'éteignent vite.
  marimba: [{ r: 1, g: 1 }, { r: 3, g: 0.4 }, { r: 6, g: 0.12 }],
};

const SOUNDS = {
  triple:  { label: 'Triple bip',      type: 'square',   timbre: 'soft',    peak: 0.30,
             notes: [{ f: 880, t: 0, d: 0.13 }, { f: 880, t: 0.18, d: 0.13 }, { f: 1175, t: 0.36, d: 0.22 }] },
  marimba: { label: 'Marimba',         type: 'sine',     timbre: 'marimba', peak: 0.5,
             notes: [{ f: 784, t: 0, d: 0.4 }, { f: 1047, t: 0.13, d: 0.55 }] },
  cloche:  { label: 'Cloche de salle', type: 'sine',     timbre: 'bell',    peak: 0.3,
             notes: [{ f: 660, t: 0, d: 1.3 }, { f: 660, t: 0.3, d: 1.6 }] },
  carillon:{ label: 'Carillon',        type: 'sine',     timbre: 'bell',    peak: 0.26,
             notes: [{ f: 523, t: 0, d: 0.9 }, { f: 659, t: 0.13, d: 0.9 }, { f: 784, t: 0.26, d: 1.3 }] },
  aigu:    { label: 'Double aigu',     type: 'sine',     timbre: 'soft',    peak: 0.34,
             notes: [{ f: 1320, t: 0, d: 0.11 }, { f: 1320, t: 0.16, d: 0.13 }] },
  grave:   { label: 'Grave',           type: 'triangle', timbre: 'soft',    peak: 0.45,
             notes: [{ f: 392, t: 0, d: 0.22 }, { f: 294, t: 0.27, d: 0.34 }] },
  montee:  { label: 'Montée',          type: 'sine',     timbre: 'soft',    peak: 0.4,
             notes: [{ from: 523, to: 1047, t: 0, d: 0.5 }] },
};

const STORE_SETTINGS = 'pausepump.settings.v1';
const STORE_SESSION = 'pausepump.session.v1';

// Version de build (injectée par la CI). Sert à afficher la version et gérer les MAJ.
const APP_VERSION = '__BUILD_VERSION__';
function versionLabel() { return APP_VERSION.indexOf('BUILD_VERSION') !== -1 ? 'dev' : APP_VERSION; }

// ---- Réglages (persistés) ----
const DEFAULT_SETTINGS = {
  keepAwake: true,
  vibrate: true,
  sound: true,
  volume: 1,
  soundId: 'triple',
  notify: true,
  notifySound: true,
  prepCountdown: true, // décompte « 3, 2, 1 » avant l'effort (mode étape par étape)
  doSetScreen: true,   // écran « Fais ta série » avant chaque pause (mode Pause seule)
  endScreen: true,     // écran de fin quand toutes les séries sont faites
  timers: DEFAULT_TIMERS.slice(),
};
let settings = loadSettings();

// ---- Session (persistée) : dernière config utilisée ----
const DEFAULT_SESSION = { mode: 'pause', series: 3, effort: 60, rest: 60, pause: 60, effortAuto: true };
let session = loadSession();

// ---- État runtime ----
const rt = {
  seriesRemaining: 0,
  seriesTotal: 0,      // nombre total de séries de la séance (pour la timeline)
  tlDots: 0,           // séries validées (points pleins de la timeline)
  tlBars: 0,           // pauses terminées (barres pleines de la timeline)
  tlFrac: 0,           // remplissage 0..1 de la barre en cours (pendant la pause)
  phase: 'pause',      // 'effort' | 'pause'
  duration: 0,
  remaining: 0,
  running: false,
  intervalId: null,
  lastTick: 0,
  finished: false,
  pickPhase: 'pause',  // en mode manuel : quelle phase on choisit (effort/pause)
};

let selectedSeries = 0;
let selectedEffort = 0;
let selectedRest = 0;

// ---- DOM ----
const $ = (s) => document.querySelector(s);
const screens = { home: $('#screen-home'), main: $('#screen-main') };
const views = { setup: $('#setup-view'), duration: $('#duration-view'), doset: $('#doset-view'), timer: $('#timer-view'), done: $('#done-view') };

// =====================================================================
//  Persistance
// =====================================================================
function loadSettings() {
  try {
    const raw = JSON.parse(localStorage.getItem(STORE_SETTINGS));
    const s = Object.assign({}, DEFAULT_SETTINGS, raw || {});
    if (!Array.isArray(s.timers) || !s.timers.length) s.timers = DEFAULT_TIMERS.slice();
    return s;
  } catch (_) { return Object.assign({}, DEFAULT_SETTINGS); }
}
function saveSettings() { try { localStorage.setItem(STORE_SETTINGS, JSON.stringify(settings)); } catch (_) {} }
function loadSession() {
  try { return Object.assign({}, DEFAULT_SESSION, JSON.parse(localStorage.getItem(STORE_SESSION)) || {}); }
  catch (_) { return Object.assign({}, DEFAULT_SESSION); }
}
function saveSession() { try { localStorage.setItem(STORE_SESSION, JSON.stringify(session)); } catch (_) {} }

// =====================================================================
//  Navigation
// =====================================================================
function showScreen(name) {
  Object.values(screens).forEach((s) => s.classList.remove('is-active'));
  screens[name].classList.add('is-active');
}
function showView(name) {
  Object.values(views).forEach((v) => v.classList.remove('is-active'));
  views[name].classList.add('is-active');
}

// =====================================================================
//  Accueil
// =====================================================================
function buildHome() {
  const grid = $('#series-grid');
  grid.innerHTML = '';
  SERIES_CHOICES.forEach((n) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'series-cell';
    b.textContent = n;
    b.setAttribute('role', 'radio');
    b.addEventListener('click', () => selectSeries(n));
    grid.appendChild(b);
  });

  document.querySelectorAll('.seg').forEach((seg) => {
    seg.addEventListener('click', () => selectMode(seg.dataset.mode));
  });

  // Restaure la dernière config
  selectMode(session.mode);
  selectSeries(session.series);
}

function selectMode(mode) {
  session.mode = mode;
  document.querySelectorAll('.seg').forEach((s) => s.classList.toggle('selected', s.dataset.mode === mode));
  saveSession();
}

function selectSeries(n) {
  selectedSeries = n;
  session.series = n;
  document.querySelectorAll('.series-cell').forEach((c) => {
    const on = Number(c.textContent) === n;
    c.classList.toggle('selected', on);
    c.setAttribute('aria-checked', on ? 'true' : 'false');
  });
  $('#start-btn').disabled = selectedSeries < 1;
  saveSession();
}

// =====================================================================
//  Grilles de durées (depuis les timers enregistrés)
// =====================================================================
function formatTime(totalSeconds) {
  const s = Math.max(0, Math.round(totalSeconds));
  const m = Math.floor(s / 60);
  const sec = s % 60;
  if (m === 0) return `${sec}s`;
  return `${m}:${String(sec).padStart(2, '0')}`;
}

function sortedTimers() { return settings.timers.slice().sort((a, b) => a - b); }

function buildDurationGrid(gridEl, onPick, getSelected) {
  gridEl.innerHTML = '';
  sortedTimers().forEach((d) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'duration-cell';
    b.textContent = formatTime(d);
    b.dataset.dur = d;
    if (getSelected && getSelected() === d) b.classList.add('selected');
    b.addEventListener('click', () => onPick(d, b));
    gridEl.appendChild(b);
  });
}

function buildAllGrids() {
  // Grille principale : un tap lance la phase courante (pause seule, ou étape effort/pause manuelle)
  buildDurationGrid($('#duration-grid'), (d) => pickDuration(d));
  // Mode Effort + Pause : sélection effort + pause puis Démarrer
  buildDurationGrid($('#effort-grid'),
    (d, b) => { selectedEffort = d; session.effort = d; saveSession(); markSelected('#effort-grid', b); },
    () => selectedEffort);
  buildDurationGrid($('#rest-grid'),
    (d, b) => { selectedRest = d; session.rest = d; saveSession(); markSelected('#rest-grid', b); },
    () => selectedRest);
}
function markSelected(gridSel, btn) {
  document.querySelectorAll(`${gridSel} .duration-cell`).forEach((c) => c.classList.remove('selected'));
  btn.classList.add('selected');
}

// =====================================================================
//  Démarrage d'une séance
// =====================================================================
function startSession() {
  rt.seriesRemaining = selectedSeries;
  rt.seriesTotal = selectedSeries;
  rt.tlDots = 0;
  rt.tlBars = 0;
  rt.tlFrac = 0;
  rt.finished = false;
  updateSeriesReadout();
  showScreen('main');
  if (settings.notify) ensureNotifPermission();

  if (session.mode === 'effort') {
    selectedEffort = session.effort;
    selectedRest = session.rest;
    buildAllGrids(); // applique la sélection mémorisée
    $('#opt-effortauto').checked = session.effortAuto;
    applyEffortAutoUI();
    showView('setup');
  } else {
    buildAllGrids();
    // Pause seule : on commence par « Fais ta série » (si activé), puis le choix de durée.
    if (settings.doSetScreen) showDoSet();
    else showPauseChoice();
  }
  saveSession();
}

// Affiche/masque les grilles selon le mode auto/manuel
function applyEffortAutoUI() {
  const auto = session.effortAuto;
  $('#setup-grids').hidden = !auto;
  $('#setup-auto-hint').hidden = !auto;
  $('#setup-manual-hint').hidden = auto;
}

// Étape de choix d'une durée
function showPauseChoice() {
  rt.pickPhase = 'pause';
  $('#duration-title').textContent = 'Choisis ta pause';
  showView('duration');
  markDurationDefault();
}
function showManualChoice(phase) {
  rt.pickPhase = phase;
  $('#duration-title').textContent = phase === 'effort'
    ? '💪 Effort — choisis la durée'
    : '😮‍💨 Pause — choisis la durée';
  showView('duration');
  markDurationDefault();
}
// Dernière durée sélectionnée pour la phase en cours (= ce que lance la touche Espace).
function currentDefaultDuration() {
  if (session.mode === 'pause') return session.pause;
  return rt.pickPhase === 'effort' ? session.effort : session.rest;
}
// Surligne la durée par défaut dans la grille + affiche l'indice « Espace ».
function markDurationDefault() {
  const d = currentDefaultDuration();
  $('#duration-grid').querySelectorAll('.duration-cell').forEach((c) => {
    c.classList.toggle('selected', Number(c.dataset.dur) === d);
  });
  const hint = $('#duration-hint');
  if (hint) {
    hint.innerHTML = d
      ? `<span class="hint-desktop"><kbd>Espace</kbd> relancer ${formatTime(d)}</span>`
        + `<span class="hint-touch">Double tap pour relancer ${formatTime(d)}</span>`
      : '';
  }
}
// Mode Pause seule : écran « Fais ta série » avant de lancer la pause.
function showDoSet() {
  stopKeepAlive();
  clearTimerNotification();
  const total = Math.max(rt.seriesTotal || 0, rt.seriesRemaining || 0);
  const current = Math.min(total, (rt.tlDots || 0) + 1); // la série qu'on va faire
  const ord = current === 1 ? '1re' : current + 'e';
  $('#doset-title').textContent = `Fais ta ${ord} série`;
  showView('doset');
}

// Tap sur une durée dans la grille principale
function pickDuration(d) {
  if (session.mode === 'pause') {
    session.pause = d;
  } else if (rt.pickPhase === 'effort') {
    session.effort = d;
  } else {
    session.rest = d;
  }
  saveSession();
  // Pause seule sans écran « Fais ta série » : la série est validée au choix de durée.
  if (session.mode === 'pause' && !settings.doSetScreen) {
    rt.tlDots = Math.min(rt.seriesTotal, (rt.tlDots || 0) + 1);
    adjustSeries(-1);
  }
  // Mode étape par étape : petit décompte de préparation avant de lancer l'effort.
  if (rt.pickPhase === 'effort' && session.mode === 'effort' && !session.effortAuto && settings.prepCountdown) {
    runCountdown(COUNTDOWN_PREP, () => startPhase('effort', d));
    return;
  }
  startPhase(rt.pickPhase, d);
}

function updateSeriesReadout() {
  $('#series-remaining').textContent = rt.seriesRemaining;
  $('#series-minus').disabled = rt.seriesRemaining <= 0;
  renderTimeline();
}

// Timeline des séries : ronds reliés. (Re)construit la structure quand le nombre
// change, sinon met juste à jour le remplissage (pour des transitions fluides).
function renderTimeline() {
  const el = $('#series-timeline');
  if (!el) return;
  const total = Math.max(rt.seriesTotal || 0, rt.seriesRemaining || 0);
  rt.seriesTotal = total;
  if (total <= 0) { el.innerHTML = ''; el.hidden = true; return; }
  el.hidden = false;
  if (el.querySelectorAll('.tl-dot').length !== total) {
    let html = '';
    for (let i = 0; i < total; i++) {
      if (i > 0) html += '<span class="tl-bar"><span class="tl-bar-fill"></span></span>';
      html += '<span class="tl-dot"></span>';
    }
    el.innerHTML = html;
  }
  updateTimelineProgress();
}

// Calcule le remplissage de la timeline selon le mode.
function timelineState() {
  const total = rt.seriesTotal;
  if (session.mode === 'pause') {
    // Le point se remplit quand la série est validée ; la barre vers le point
    // suivant se remplit progressivement pendant le timer de pause.
    const dots = Math.min(total, rt.tlDots || 0);
    const bars = Math.min(total, rt.tlBars || 0);
    // Barre en cours = pause commencée (série validée) mais pas encore terminée.
    const restActive = (rt.tlBars || 0) < (rt.tlDots || 0);
    const frac = restActive ? Math.max(0, Math.min(1, rt.tlFrac || 0)) : 0;
    return { dots, bars, frac, activeBar: restActive ? bars : -1 };
  }
  // Effort + Pause : un point par série terminée.
  const done = Math.min(total, Math.max(0, total - rt.seriesRemaining));
  return { dots: done, bars: done, frac: 0, activeBar: -1 };
}

function updateTimelineProgress() {
  const el = $('#series-timeline');
  if (!el || el.hidden) return;
  const { dots, bars, frac, activeBar } = timelineState();
  el.querySelectorAll('.tl-dot').forEach((d, i) => {
    d.classList.toggle('done', i < dots);
    d.classList.toggle('current', i === dots);
  });
  el.querySelectorAll('.tl-bar').forEach((b, i) => {
    const fill = b.firstElementChild;
    if (!fill) return;
    const w = (i < bars) ? 1 : (i === activeBar ? frac : 0);
    fill.style.width = (w * 100) + '%';
  });
}

function adjustSeries(delta) {
  rt.seriesRemaining = Math.max(0, rt.seriesRemaining + delta);
  updateSeriesReadout();
}

// =====================================================================
//  Minuteur
// =====================================================================
function startPhase(phase, duration) {
  rt.phase = phase;
  rt.duration = duration;
  rt.remaining = duration;
  rt.finished = false;
  updatePhaseUI();
  showView('timer');
  updateTimerUI();
  resumeTimer();
  if (settings.keepAwake) requestWakeLock();
}

// ---- Décompte « 5, 4, 3… » avant de lancer l'effort ----
const COUNTDOWN_AUTO = 3; // avant le 1er effort en enchaînement auto
const COUNTDOWN_PREP = 3; // préparation avant chaque effort (mode étape par étape)
let countdownTimer = null;
function cancelCountdown() {
  if (countdownTimer) { clearInterval(countdownTimer); countdownTimer = null; }
  const overlay = $('#countdown-overlay');
  if (overlay) { overlay.classList.remove('show'); overlay.hidden = true; }
}
// Petit bip de décompte (réutilise le moteur audio). `go` = tonalité de départ.
function countdownBeep(go) {
  const ctx = getAudioCtx();
  if (!ctx) return;
  if (ctx.state === 'suspended') ctx.resume();
  const vol = Math.max(0, Math.min(1, settings.volume));
  if (vol <= 0) return;
  const def = go
    ? { type: 'sine', timbre: 'soft', peak: 0.55 }
    : { type: 'sine', timbre: 'soft', peak: 0.32 };
  const note = go ? { from: 880, to: 1320, t: 0, d: 0.35 } : { f: 740, t: 0, d: 0.12 };
  scheduleVoice(ctx, def, note, ctx.currentTime + 0.01, vol, getMaster(ctx));
}
// Affiche un décompte plein écran de `from` à GO !, puis exécute `onDone`.
function runCountdown(from, onDone) {
  getAudioCtx(); // débloque l'audio dans le geste utilisateur
  const overlay = $('#countdown-overlay');
  const numEl = $('#countdown-num');
  let launched = false;
  const launch = () => {
    if (launched) return;
    launched = true;
    cancelCountdown();
    onDone();
  };
  if (!overlay || !numEl) { launch(); return; }

  let n = from;
  const render = (txt, go) => {
    numEl.textContent = txt;
    numEl.classList.toggle('go', !!go);
    numEl.classList.remove('pop'); void numEl.offsetWidth; numEl.classList.add('pop');
  };

  overlay.hidden = false;
  requestAnimationFrame(() => overlay.classList.add('show'));
  overlay.onclick = launch; // tap → on démarre tout de suite

  render(n, false);
  countdownBeep(false);
  if (settings.vibrate) vibrate(30);

  countdownTimer = setInterval(() => {
    n -= 1;
    if (n <= 0) {
      clearInterval(countdownTimer); countdownTimer = null;
      render('GO !', true);
      countdownBeep(true);
      if (settings.vibrate) vibrate(90);
      setTimeout(launch, 550);
      return;
    }
    render(n, false);
    countdownBeep(false);
    if (settings.vibrate) vibrate(30);
  }, 1000);
}

function updatePhaseUI() {
  const badge = $('#phase-badge');
  const ring = $('#ring-progress');
  const isEffort = rt.phase === 'effort';
  badge.textContent = isEffort ? '💪 Effort' : '😮‍💨 Pause';
  badge.classList.toggle('phase-effort', isEffort);
  badge.classList.toggle('phase-pause', !isEffort);
  ring.classList.toggle('phase-effort', isEffort);
  ring.classList.toggle('phase-pause', !isEffort);
  // En mode "pause seule", badge plus discret
  if (session.mode === 'pause') badge.textContent = 'Pause';
}

function resumeTimer() {
  if (rt.running) return;
  rt.running = true;
  rt.lastTick = performance.now();
  setPlayPause(true);
  $('#timer-state').textContent = 'En cours';
  startKeepAlive();             // garde le moteur audio actif en arrière-plan
  scheduleAlarm(rt.remaining);  // programme le bip de fin sur l'horloge audio
  rt.intervalId = setInterval(loop, 200);
  showTimerNotification();      // si on est déjà en arrière-plan (ex. enchaînement effort→pause)
}
function pauseTimer() {
  if (!rt.running) return;
  rt.running = false;
  clearInterval(rt.intervalId);
  cancelAlarm();
  stopKeepAlive();
  setPlayPause(false);
  $('#timer-state').textContent = 'En pause';
}
function togglePlayPause() { rt.running ? pauseTimer() : resumeTimer(); }

function resetTimer() {
  rt.remaining = rt.duration;
  rt.finished = false;
  updateTimerUI();
  if (rt.running) { rt.lastTick = performance.now(); scheduleAlarm(rt.remaining); }
  else $('#timer-state').textContent = 'En pause';
}

function backToChoice() {
  pauseTimer();
  clearTimerNotification();
  releaseWakeLock();
  if (session.mode === 'pause') { showPauseChoice(); return; }
  if (session.effortAuto) {
    $('#opt-effortauto').checked = session.effortAuto;
    applyEffortAutoUI();
    showView('setup');
  } else {
    showManualChoice(rt.phase); // re-choisir la durée de l'étape en cours
  }
}

function loop() {
  const now = performance.now();
  const dt = (now - rt.lastTick) / 1000;
  rt.lastTick = now;
  rt.remaining -= dt;
  if (rt.remaining <= 0) {
    rt.remaining = 0;
    updateTimerUI();
    onPhaseComplete();
    return;
  }
  updateTimerUI();
}

function updateTimerUI() {
  const secs = Math.ceil(rt.remaining);
  $('#time-display').textContent = formatTime(secs);
  const frac = rt.duration > 0 ? rt.remaining / rt.duration : 0;
  const ring = $('#ring-progress');
  ring.style.strokeDashoffset = RING_CIRCUMFERENCE * (1 - frac);
  const ending = secs <= ENDING_THRESHOLD && rt.remaining > 0;
  ring.classList.toggle('is-ending', ending);
  $('#time-display').classList.toggle('is-ending', ending);
  // Pause seule : la barre de la timeline se remplit au rythme du timer.
  if (session.mode === 'pause') {
    rt.tlFrac = 1 - frac;
    updateTimelineProgress();
  }
}

// Fin d'une phase (effort ou pause) : le temps est écoulé
function onPhaseComplete() {
  rt.running = false;
  clearInterval(rt.intervalId);
  if (rt.finished) return;
  rt.finished = true;
  alarmNodes = []; // l'alarme de fin est en train de sonner : on libère les refs sans la couper

  const bg = document.hidden;
  playEndFeedback(bg);
  advancePhase(bg);
}

// Passe à l'étape suivante selon le mode et la phase en cours.
// effort → pause (même série) ; pause → série suivante (−1) ou fin.
function advancePhase(bg) {
  let sessionEnd = false;
  let autoNext = null;    // enchaînement automatique (effort auto)
  let manualNext = null;  // étape suivante à choisir à la main

  if (session.mode === 'pause') {
    // Le compteur a déjà été décrémenté à la validation de la série (pas ici).
    rt.tlBars = rt.tlDots; // la pause est finie → la barre en cours devient pleine
    rt.tlFrac = 0;
    updateTimelineProgress();
    sessionEnd = rt.seriesRemaining <= 0;
  } else if (session.effortAuto) { // Effort + Pause, enchaîné
    if (rt.phase === 'effort') {
      autoNext = 'pause';
    } else {
      adjustSeries(-1);
      sessionEnd = rt.seriesRemaining <= 0;
      if (!sessionEnd) autoNext = 'effort';
    }
  } else { // Effort + Pause, à chaque étape
    if (rt.phase === 'effort') {
      manualNext = 'pause';
    } else {
      adjustSeries(-1);
      sessionEnd = rt.seriesRemaining <= 0;
      if (!sessionEnd) manualNext = 'effort';
    }
  }

  if (sessionEnd) {
    if (bg) showFinishNotification(); else clearTimerNotification();
    finishSession();
    return;
  }
  if (autoNext) {
    startPhase(autoNext, autoNext === 'pause' ? session.rest : session.effort);
    return;
  }
  // On revient à un choix de durée (pause seule, ou étape manuelle) → on arrête le moteur
  stopKeepAlive();
  if (bg) showFinishNotification(); else clearTimerNotification();
  if (manualNext) showManualChoice(manualNext);
  else if (settings.doSetScreen) showDoSet(); // mode Pause seule : « Fais ta série »
  else showPauseChoice();                     // option désactivée : on choisit la durée
}

// ⏭ Suivante : passe à l'étape suivante (en effort → lance la pause ; en pause →
// série suivante). Coupe le timer/alarme en cours et applique la même logique
// que la fin naturelle d'une phase.
function skipSeries() {
  pauseTimer();        // stoppe le minuteur + annule l'alarme programmée
  rt.finished = true;  // évite tout double-déclenchement
  advancePhase(false); // au 1er plan : pas de notif de fin, juste l'enchaînement
}

function finishSession() {
  pauseTimer();
  stopKeepAlive();
  releaseWakeLock();
  clearAllNotifications();
  if (settings.endScreen) {
    showDone();
  } else {
    showScreen('home');
    showSnackbar('Séance terminée 🎉');
  }
}

// Écran de fin : toutes les séries sont faites.
function showDone() {
  const total = selectedSeries;
  const plural = total > 1 ? 's' : '';
  const modeLabel = session.mode === 'effort' ? 'Effort + Pause' : 'Pause seule';
  $('#done-sub').textContent = `${total} série${plural} bouclée${plural} · ${modeLabel} 💪`;
  showScreen('main');
  showView('done');
}

function setPlayPause(running) {
  $('#playpause-ico').textContent = running ? '⏸' : '▶';
  $('#playpause-txt').textContent = running ? 'Pause' : 'Reprendre';
}

// =====================================================================
//  Retour sensoriel : son, vibration, notification
// =====================================================================
function playEndFeedback(bg) {
  // Le bip de fin est joué par l'alarme programmée (scheduleAlarm), donc fiable même
  // en arrière-plan. Ici on ne gère que la vibration au 1er plan (en arrière-plan,
  // c'est la notification qui vibre).
  if (bg) return;
  if (settings.vibrate) vibrate([200, 100, 200, 100, 200]);
}

// ---- Web Audio ----
let audioCtx = null;
function getAudioCtx() {
  if (!audioCtx) {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (AC) audioCtx = new AC();
  }
  return audioCtx;
}
// Bus master : compresseur léger pour un son punchy et sans saturation quand
// plusieurs partiels se superposent. Créé une fois par contexte audio.
let masterBus = null;
function getMaster(ctx) {
  if (masterBus && masterBus.context === ctx) return masterBus;
  const comp = ctx.createDynamicsCompressor();
  comp.threshold.value = -12;
  comp.knee.value = 18;
  comp.ratio.value = 4;
  comp.attack.value = 0.002;
  comp.release.value = 0.18;
  const g = ctx.createGain();
  g.gain.value = 0.95;
  comp.connect(g).connect(ctx.destination);
  masterBus = comp;
  return masterBus;
}

// Synthétise une note (avec son timbre multi-partiels et son enveloppe
// percussive) à l'instant absolu `base + n.t`. Renvoie les oscillateurs créés.
function scheduleVoice(ctx, def, n, base, vol, out) {
  const partials = TIMBRE[def.timbre] || TIMBRE.pure;
  const t = base + n.t;
  const atk = 0.006;
  const created = [];
  partials.forEach((p) => {
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = def.type || 'sine';
    if (n.from != null) {
      osc.frequency.setValueAtTime(n.from * p.r, t);
      osc.frequency.exponentialRampToValueAtTime(n.to * p.r, t + n.d);
    } else {
      osc.frequency.setValueAtTime(n.f * p.r, t);
    }
    const peak = Math.max(0.0002, (def.peak || 0.4) * p.g * vol);
    gain.gain.setValueAtTime(0.0001, t);
    gain.gain.exponentialRampToValueAtTime(peak, t + atk);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + n.d);
    osc.connect(gain).connect(out);
    osc.start(t);
    osc.stop(t + n.d + 0.05);
    created.push(osc);
  });
  return created;
}

function playSound(id) {
  const ctx = getAudioCtx();
  if (!ctx) return;
  if (ctx.state === 'suspended') ctx.resume();
  const vol = Math.max(0, Math.min(1, settings.volume));
  if (vol <= 0) return;
  const def = SOUNDS[id] || SOUNDS.triple;
  const out = getMaster(ctx);
  const base = ctx.currentTime + 0.02;
  def.notes.forEach((n) => scheduleVoice(ctx, def, n, base, vol, out));
}

function vibrate(pattern) {
  if (navigator.vibrate) { try { navigator.vibrate(pattern); } catch (_) {} }
}

// ---- Maintien audio + alarme programmée (son fiable en arrière-plan) ----
// Sur mobile, le minuteur JS est gelé dès qu'on quitte l'app. Pour qu'un son
// joue à la fin du timer même en arrière-plan, on garde le moteur audio actif
// (keep-alive quasi inaudible) et on programme le bip à l'avance sur l'horloge
// audio (sample-accurate, insensible au gel du thread JS).
let keepAliveSrc = null;
function startKeepAlive() {
  const ctx = getAudioCtx();
  if (!ctx) return;
  if (ctx.state === 'suspended') ctx.resume();
  if (keepAliveSrc) return;
  const buf = ctx.createBuffer(1, Math.round(ctx.sampleRate * 0.5), ctx.sampleRate);
  const data = buf.getChannelData(0);
  for (let i = 0; i < data.length; i++) data[i] = (Math.random() * 2 - 1) * 0.0025;
  const src = ctx.createBufferSource();
  src.buffer = buf; src.loop = true;
  const g = ctx.createGain();
  g.gain.value = 0.0006; // quasi inaudible, juste pour garder le pipeline actif
  src.connect(g).connect(ctx.destination);
  try { src.start(); } catch (_) {}
  keepAliveSrc = src;
}
function stopKeepAlive() {
  if (!keepAliveSrc) return;
  try { keepAliveSrc.stop(); } catch (_) {}
  try { keepAliveSrc.disconnect(); } catch (_) {}
  keepAliveSrc = null;
}

let alarmNodes = [];
function cancelAlarm() {
  alarmNodes.forEach((n) => { try { n.stop(); } catch (_) {} try { n.disconnect(); } catch (_) {} });
  alarmNodes = [];
}
// Programme le bip de fin dans `delaySec` secondes (horloge audio).
function scheduleAlarm(delaySec) {
  cancelAlarm();
  if (!settings.sound) return; // « Jouer un son à la fin » désactivé
  const ctx = getAudioCtx();
  if (!ctx) return;
  if (ctx.state === 'suspended') ctx.resume();
  const vol = Math.max(0, Math.min(1, settings.volume));
  if (vol <= 0) return;
  const def = SOUNDS[settings.soundId] || SOUNDS.triple;
  const start = ctx.currentTime + Math.max(0, delaySec);
  const out = getMaster(ctx);
  def.notes.forEach((n) => {
    scheduleVoice(ctx, def, n, start, vol, out).forEach((osc) => alarmNodes.push(osc));
  });
}

// ---- Wake Lock ----
let wakeLock = null;
async function requestWakeLock() {
  if (!settings.keepAwake || !('wakeLock' in navigator)) return;
  try { wakeLock = await navigator.wakeLock.request('screen'); } catch (_) {}
}
function releaseWakeLock() {
  if (wakeLock) { wakeLock.release().catch(() => {}); wakeLock = null; }
}

// ---- Notifications ----
async function ensureNotifPermission() {
  if (!('Notification' in window)) return false;
  if (Notification.permission === 'granted') return true;
  if (Notification.permission === 'denied') return false;
  try { return (await Notification.requestPermission()) === 'granted'; } catch (_) { return false; }
}
function notifReady() {
  return ('Notification' in window) && Notification.permission === 'granted' && navigator.serviceWorker;
}
// Notif « en cours » : affichée UNE fois (à la mise en arrière-plan ou au
// changement de phase), jamais ré-écrite chaque seconde. En arrière-plan le JS
// est gelé : un décompte ré-écrit saute / se « relance ». On montre plutôt
// l'HEURE DE FIN (absolue), que le système n'a pas à recalculer → toujours juste.
async function showTimerNotification() {
  if (!settings.notify || !notifReady() || !document.hidden || !rt.running) return;
  const reg = await navigator.serviceWorker.ready.catch(() => null);
  if (!reg || !document.hidden || !rt.running) return; // état peut avoir changé pendant l'await
  const label = session.mode === 'effort' ? (rt.phase === 'effort' ? 'Effort 💪' : 'Pause 😮‍💨') : 'Pause';
  const total = Math.max(rt.seriesTotal || 0, rt.seriesRemaining || 0);
  const serie = Math.min(total, total - rt.seriesRemaining + 1);
  const endMs = Date.now() + Math.max(0, rt.remaining) * 1000;
  const endClock = new Date(endMs).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
  reg.showNotification('PausePump ⏱️', {
    tag: 'pausepump-timer',
    body: `${label} • fin à ${endClock} • série ${serie}/${total}`,
    silent: true, renotify: false, requireInteraction: false,
    timestamp: endMs,
    icon: 'icons/icon-192.png', badge: 'icons/badge-96.png',
  });
}
async function clearTimerNotification() {
  if (!('serviceWorker' in navigator)) return;
  const reg = await navigator.serviceWorker.ready.catch(() => null);
  if (!reg) return;
  (await reg.getNotifications({ tag: 'pausepump-timer' })).forEach((n) => n.close());
}
// Ferme TOUTES les notifications de l'app (minuteur + fin) — au retour sur l'app.
async function clearAllNotifications() {
  if (!('serviceWorker' in navigator)) return;
  // 1) On demande au SW de fermer ses notifs (méthode la plus fiable selon le navigateur).
  if (navigator.serviceWorker.controller) {
    navigator.serviceWorker.controller.postMessage({ type: 'CLEAR_NOTIFS' });
  }
  // 2) On ferme aussi depuis la page (repli).
  const reg = await navigator.serviceWorker.ready.catch(() => null);
  if (!reg) return;
  if (reg.active) reg.active.postMessage({ type: 'CLEAR_NOTIFS' });
  (await reg.getNotifications()).forEach((n) => n.close());
}
// Nettoie tout de suite puis ré-essaie brièvement : une notif peut être affichée
// par le système juste au moment où l'on revient au premier plan (course).
function clearAllNotificationsSoon() {
  clearAllNotifications();
  setTimeout(clearAllNotifications, 250);
  setTimeout(clearAllNotifications, 700);
}
async function showFinishNotification() {
  if (!notifReady() || !document.hidden) return; // si on est revenu sur l'app entre-temps, pas de notif
  const reg = await navigator.serviceWorker.ready.catch(() => null);
  if (!reg) return;
  (await reg.getNotifications({ tag: 'pausepump-timer' })).forEach((n) => n.close());
  reg.showNotification('PausePump ✅', {
    tag: 'pausepump-done',
    body: 'Temps écoulé !',
    renotify: true, requireInteraction: false,
    // Le bip perso (alarme) joue déjà le son → on rend la notif silencieuse pour
    // éviter le double son. La tonalité système ne sert que si le bip est coupé.
    silent: settings.sound || !settings.notifySound,
    vibrate: settings.vibrate ? [200, 100, 200] : undefined,
    icon: 'icons/icon-192.png', badge: 'icons/badge-96.png',
  });
}

// Quand l'app revient au premier plan : on enlève la notif et on reprend le wake lock
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible') {
    clearAllNotificationsSoon(); // au retour sur l'app : on enlève toutes ses notifs
    if (rt.running) requestWakeLock();
  } else if (rt.running) {
    showTimerNotification(); // mise en arrière-plan pendant un décompte
  }
});
window.addEventListener('focus', clearAllNotificationsSoon);
window.addEventListener('pageshow', clearAllNotificationsSoon);

// Action « la suite » — mémorise la dernière durée choisie et enchaîne :
// - écran « Fais ta série » → valide la série
// - écran de choix de durée → lance la dernière durée sélectionnée
// - écran de fin de séance → recommence la séance
// Deux déclencheurs : la touche Espace (desktop / clicker Bluetooth à la salle)
// et le double tap (mobile). Renvoie true si quelque chose a été déclenché.
function quickAdvance() {
  if (!$('#settings-modal').hidden) return false;      // modale options ouverte
  if (!$('#screen-main').classList.contains('is-active')) return false;
  if (views.doset.classList.contains('is-active')) {
    $('#doset-done').click();                          // valide la série
    return true;
  }
  if (views.duration.classList.contains('is-active')) {
    getAudioCtx();
    pickDuration(currentDefaultDuration());            // lance la dernière durée
    return true;
  }
  if (views.done.classList.contains('is-active')) {
    $('#done-restart').click();                        // recommence la séance
    return true;
  }
  return false;
}

document.addEventListener('keydown', (e) => {
  if (e.code !== 'Space' && e.key !== ' ' && e.key !== 'Spacebar') return;
  const t = e.target;
  const tag = (t && t.tagName || '').toLowerCase();
  if (tag === 'input' || tag === 'textarea' || tag === 'select' || (t && t.isContentEditable)) return;
  if (quickAdvance()) e.preventDefault();
});

// Double tap n'importe où sur l'écran de séance = équivalent tactile d'Espace.
// On ignore les taps sur un élément interactif (bouton, cellule de durée…),
// qui font déjà leur propre action au premier tap.
const DOUBLE_TAP_MS = 400;      // délai max entre les deux taps
const DOUBLE_TAP_PX = 60;       // écart max entre les deux points
let lastTap = { t: 0, x: 0, y: 0 };
$('#screen-main').addEventListener('click', (e) => {
  if (e.target.closest('button, a, input, select, textarea, label, [role="button"], .duration-cell')) {
    lastTap = { t: 0, x: 0, y: 0 };
    return;
  }
  const now = Date.now();
  const x = e.clientX, y = e.clientY;
  const isDouble = now - lastTap.t < DOUBLE_TAP_MS
    && Math.abs(x - lastTap.x) < DOUBLE_TAP_PX
    && Math.abs(y - lastTap.y) < DOUBLE_TAP_PX;
  if (isDouble) {
    lastTap = { t: 0, x: 0, y: 0 };                    // pas de triple tap
    quickAdvance();
  } else {
    lastTap = { t: now, x, y };
  }
});

// =====================================================================
//  Snackbar
// =====================================================================
let snackTimer = null;
function showSnackbar(msg, ms = 2600) {
  const el = $('#snackbar');
  el.textContent = msg;
  el.hidden = false;
  requestAnimationFrame(() => el.classList.add('show'));
  clearTimeout(snackTimer);
  snackTimer = setTimeout(() => {
    el.classList.remove('show');
    setTimeout(() => { el.hidden = true; }, 280);
  }, ms);
}

// =====================================================================
//  Installation PWA (« Ajouter à l'écran d'accueil »)
// =====================================================================
let deferredPrompt = null;
const isIos = /iphone|ipad|ipod/i.test(navigator.userAgent);
const isStandalone = window.matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;

function setupInstall() {
  const btns = document.querySelectorAll('.install-btn');
  if (isStandalone) return; // déjà installée → on ne montre rien

  // Android / Chromium : on capture l'invite native et on révèle le bouton
  window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    deferredPrompt = e;
    btns.forEach((b) => { b.hidden = false; });
  });
  window.addEventListener('appinstalled', () => {
    deferredPrompt = null;
    btns.forEach((b) => { b.hidden = true; });
    showSnackbar('Installée ! 🎉');
  });
  // iOS : aucune invite automatique → on montre le bouton avec les instructions
  if (isIos) btns.forEach((b) => { b.hidden = false; });

  btns.forEach((b) => b.addEventListener('click', async () => {
    if (deferredPrompt) {
      deferredPrompt.prompt();
      await deferredPrompt.userChoice;
      deferredPrompt = null;
      btns.forEach((x) => { x.hidden = true; });
    } else if (isIos) {
      showSnackbar('Partager ⬆️ puis « Sur l\'écran d\'accueil »', 6000);
    } else {
      showSnackbar('Menu du navigateur → « Installer / Ajouter à l\'écran d\'accueil »', 5000);
    }
  }));
}

// =====================================================================
//  Options (modale)
// =====================================================================
function openSettings() { $('#settings-modal').hidden = false; }
function closeSettings() { $('#settings-modal').hidden = true; }

function buildSoundSelect(sel, current) {
  sel.innerHTML = '';
  Object.entries(SOUNDS).forEach(([id, def]) => {
    const o = document.createElement('option');
    o.value = id; o.textContent = def.label;
    if (id === current) o.selected = true;
    sel.appendChild(o);
  });
}

function applySettingsToUI() {
  $('#opt-keepawake').checked = settings.keepAwake;
  $('#opt-vibrate').checked = settings.vibrate;
  $('#opt-sound').checked = settings.sound;
  $('#opt-volume').value = Math.round(settings.volume * 100);
  $('#vol-val').textContent = Math.round(settings.volume * 100) + '%';
  buildSoundSelect($('#opt-soundid'), settings.soundId);
  $('#opt-notify').checked = settings.notify;
  $('#opt-notifysound').checked = settings.notifySound;
  $('#opt-prepcountdown').checked = settings.prepCountdown;
  $('#opt-dosetscreen').checked = settings.doSetScreen;
  $('#opt-endscreen').checked = settings.endScreen;
  updateNotifStatus();
}

function updateNotifStatus() {
  const el = $('#notif-status');
  if (!('Notification' in window)) { el.textContent = 'Notifications non supportées par ce navigateur.'; return; }
  if (Notification.permission === 'denied') el.textContent = '⚠️ Notifications bloquées dans les réglages du navigateur.';
  else if (Notification.permission === 'granted') el.textContent = '✓ Notifications autorisées.';
  else el.textContent = 'Autorisation demandée au démarrage d\'un timer.';
}

function wireSettings() {
  document.querySelectorAll('.options-btn').forEach((btn) =>
    btn.addEventListener('click', () => { getAudioCtx(); openSettings(); }));
  $('#settings-close').addEventListener('click', closeSettings);
  $('#settings-modal').addEventListener('click', (e) => { if (e.target.id === 'settings-modal') closeSettings(); });

  document.querySelectorAll('.tab').forEach((tab) => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.tab').forEach((t) => t.classList.toggle('is-active', t === tab));
      document.querySelectorAll('.tab-panel').forEach((p) => p.classList.toggle('is-active', p.dataset.panel === tab.dataset.tab));
    });
  });

  $('#opt-keepawake').addEventListener('change', (e) => {
    settings.keepAwake = e.target.checked; saveSettings();
    if (settings.keepAwake && rt.running) requestWakeLock(); else if (!settings.keepAwake) releaseWakeLock();
  });
  $('#opt-vibrate').addEventListener('change', (e) => { settings.vibrate = e.target.checked; saveSettings(); if (e.target.checked) vibrate(80); });
  $('#opt-sound').addEventListener('change', (e) => { settings.sound = e.target.checked; saveSettings(); if (rt.running) scheduleAlarm(rt.remaining); });
  $('#opt-volume').addEventListener('input', (e) => {
    settings.volume = Number(e.target.value) / 100;
    $('#vol-val').textContent = e.target.value + '%';
    saveSettings();
    if (rt.running) scheduleAlarm(rt.remaining);
  });
  $('#opt-soundid').addEventListener('change', (e) => { settings.soundId = e.target.value; saveSettings(); playSound(settings.soundId); if (rt.running) scheduleAlarm(rt.remaining); });
  $('#preview-sound').addEventListener('click', () => { getAudioCtx(); playSound(settings.soundId); });

  $('#opt-notify').addEventListener('change', async (e) => {
    settings.notify = e.target.checked; saveSettings();
    if (e.target.checked) { await ensureNotifPermission(); updateNotifStatus(); }
  });
  $('#opt-notifysound').addEventListener('change', (e) => { settings.notifySound = e.target.checked; saveSettings(); });
  $('#opt-prepcountdown').addEventListener('change', (e) => { settings.prepCountdown = e.target.checked; saveSettings(); });
  $('#opt-dosetscreen').addEventListener('change', (e) => { settings.doSetScreen = e.target.checked; saveSettings(); });
  $('#opt-endscreen').addEventListener('change', (e) => { settings.endScreen = e.target.checked; saveSettings(); });

  $('#timer-add').addEventListener('click', () => {
    settings.timers.push(60);
    saveSettings(); buildTimersEditor(); rebuildGridsKeepSel();
  });
  $('#timers-reset').addEventListener('click', () => {
    settings.timers = DEFAULT_TIMERS.slice();
    saveSettings(); buildTimersEditor(); rebuildGridsKeepSel();
  });

  $('#app-version').textContent = versionLabel();
  $('#check-update').addEventListener('click', async () => {
    if (!swRegistration) { showSnackbar('Mises à jour indisponibles ici'); return; }
    showSnackbar('Recherche de mise à jour…');
    try { await swRegistration.update(); } catch (_) {}
    setTimeout(() => {
      const pending = swRegistration.waiting || $('#update-banner').classList.contains('show');
      if (!pending) showSnackbar('Tu es à jour ✓');
    }, 1500);
  });
}

// ---- Éditeur de timers ----
function buildTimersEditor() {
  const list = $('#timers-list');
  list.innerHTML = '';
  settings.timers.forEach((sec, idx) => {
    const row = document.createElement('div');
    row.className = 'timer-edit-row';

    const fields = document.createElement('div');
    fields.className = 't-fields';
    const min = document.createElement('input');
    min.type = 'number'; min.className = 't-input'; min.min = 0; min.max = 99;
    min.value = Math.floor(sec / 60); min.inputMode = 'numeric';
    const sep = document.createElement('span'); sep.className = 't-sep'; sep.textContent = ':';
    const s = document.createElement('input');
    s.type = 'number'; s.className = 't-input'; s.min = 0; s.max = 59;
    s.value = String(sec % 60).padStart(2, '0'); s.inputMode = 'numeric';

    const commit = () => {
      let m = Math.max(0, Math.min(99, parseInt(min.value, 10) || 0));
      let ss = Math.max(0, Math.min(59, parseInt(s.value, 10) || 0));
      let total = m * 60 + ss;
      if (total < 5) total = 5; // minimum 5 s
      settings.timers[idx] = total;
      min.value = Math.floor(total / 60);
      s.value = String(total % 60).padStart(2, '0');
      saveSettings();
      rebuildGridsKeepSel();
    };
    min.addEventListener('change', commit);
    s.addEventListener('change', commit);

    fields.appendChild(min);
    fields.appendChild(sep);
    fields.appendChild(s);

    const del = document.createElement('button');
    del.type = 'button'; del.className = 't-del'; del.textContent = '🗑';
    del.setAttribute('aria-label', 'Supprimer ce timer');
    del.addEventListener('click', () => {
      if (settings.timers.length <= 1) { showSnackbar('Garde au moins un timer'); return; }
      settings.timers.splice(idx, 1);
      saveSettings(); buildTimersEditor(); rebuildGridsKeepSel();
    });

    row.appendChild(fields);
    row.appendChild(del);
    list.appendChild(row);
  });
}
function rebuildGridsKeepSel() { buildAllGrids(); }

// =====================================================================
//  Câblage
// =====================================================================
function wireEvents() {
  $('#start-btn').addEventListener('click', () => {
    if (selectedSeries < 1) return;
    getAudioCtx();
    startSession();
  });
  $('#home-btn').addEventListener('click', () => { pauseTimer(); clearTimerNotification(); releaseWakeLock(); showScreen('home'); });
  // Les boutons +/- modifient le total prévu (et pas seulement le restant).
  $('#series-minus').addEventListener('click', () => {
    if (rt.seriesRemaining <= 0) return;
    rt.seriesTotal = Math.max(1, rt.seriesTotal - 1);
    adjustSeries(-1);
  });
  $('#series-plus').addEventListener('click', () => {
    rt.seriesTotal += 1;
    adjustSeries(1);
  });
  $('#opt-effortauto').addEventListener('change', (e) => {
    session.effortAuto = e.target.checked;
    saveSession();
    applyEffortAutoUI();
  });
  $('#setup-start').addEventListener('click', () => {
    if (session.effortAuto) {
      if (!selectedEffort || !selectedRest) { showSnackbar('Choisis effort et pause'); return; }
      saveSession();
      runCountdown(COUNTDOWN_AUTO, () => startPhase('effort', selectedEffort)); // décompte avant le 1er effort
    } else {
      // Mode à chaque étape : on commence par choisir la durée d'effort
      saveSession();
      showManualChoice('effort');
    }
  });
  $('#playpause-btn').addEventListener('click', togglePlayPause);
  $('#reset-btn').addEventListener('click', resetTimer);
  $('#skip-btn').addEventListener('click', skipSeries);
  $('#change-btn').addEventListener('click', backToChoice);
  $('#doset-done').addEventListener('click', () => {
    getAudioCtx();
    rt.tlDots = Math.min(rt.seriesTotal, (rt.tlDots || 0) + 1); // série validée → point plein
    adjustSeries(-1);                                            // compteur −1 dès la validation
    showPauseChoice();
  });
  $('#done-restart').addEventListener('click', () => { getAudioCtx(); startSession(); });
  $('#done-home').addEventListener('click', () => { showScreen('home'); });
  wireSettings();
}

// =====================================================================
//  Init
// =====================================================================
function init() {
  buildHome();
  buildAllGrids();
  buildTimersEditor();
  applySettingsToUI();
  wireEvents();
  setupInstall();
  showScreen('home');
  clearAllNotificationsSoon(); // ouverture de l'app : on nettoie d'éventuelles notifs restantes
}
init();

// =====================================================================
//  Gestion des versions / mises à jour de la PWA
// =====================================================================
let updateAccepted = false;
let swRegistration = null;

function showUpdateBanner(onApply) {
  const banner = $('#update-banner');
  if (!banner) return;
  banner.hidden = false;
  // Réserve la place en haut (le bandeau est ancré en haut) : le contenu descend
  // un peu mais le bouton du bas, ancré en bas de l'écran, ne bouge pas.
  document.body.classList.add('has-update');
  requestAnimationFrame(() => banner.classList.add('show'));
  $('#update-apply').onclick = () => {
    $('#update-apply').disabled = true;
    $('#update-apply').textContent = 'Mise à jour…';
    onApply();
  };
}

if ('serviceWorker' in navigator) {
  // updateViaCache: 'none' → le sw.js est toujours re-téléchargé (jamais servi par
  // le cache HTTP) : une nouvelle version est détectée de façon fiable.

  // Recharge uniquement quand l'utilisateur a accepté la mise à jour.
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (updateAccepted) window.location.reload();
  });

  window.addEventListener('load', async () => {
    const reg = await navigator.serviceWorker.register('sw.js', { updateViaCache: 'none' }).catch(() => null);
    if (!reg) return;
    swRegistration = reg;

    const promptIfReady = (worker) => {
      // Il y avait déjà un contrôleur → c'est une vraie mise à jour (pas la 1re install)
      if (worker && navigator.serviceWorker.controller) {
        showUpdateBanner(() => { updateAccepted = true; worker.postMessage({ type: 'SKIP_WAITING' }); });
      }
    };

    if (reg.waiting) promptIfReady(reg.waiting);
    reg.addEventListener('updatefound', () => {
      const nw = reg.installing;
      if (!nw) return;
      nw.addEventListener('statechange', () => {
        if (nw.state === 'installed') promptIfReady(nw);
      });
    });

    // Vérifie les mises à jour : au chargement, périodiquement, et au retour sur l'app.
    const check = () => reg.update().catch(() => {});
    check();
    setInterval(check, 60 * 1000);
    document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible') check(); });
  });
}
