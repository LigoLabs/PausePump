'use strict';

/* ====================================================================
   PausePump — gestion des temps de repos entre séries de muscu.
   App vanilla JS, mobile-first, hors-ligne (PWA).
   ==================================================================== */

// ---- Données de configuration ----
const SERIES_CHOICES = [1, 2, 3, 4, 5, 6];
const DURATIONS = [30, 45, 60, 90, 120, 150, 180]; // en secondes
const ENDING_THRESHOLD = 5; // secondes : passage au rouge
const RING_CIRCUMFERENCE = 2 * Math.PI * 100; // r = 100

// ---- État ----
const state = {
  seriesRemaining: 0,
  duration: 0,       // durée choisie (s)
  remaining: 0,      // temps restant (s, flottant)
  running: false,
  rafId: null,
  lastTick: 0,
  finished: false,   // garde anti double-fin
};

// ---- Raccourcis DOM ----
const $ = (sel) => document.querySelector(sel);
const screens = {
  home: $('#screen-home'),
  main: $('#screen-main'),
  done: $('#screen-done'),
};
const views = {
  duration: $('#duration-view'),
  timer: $('#timer-view'),
};

let selectedSeries = 0;

// =====================================================================
//  Navigation entre écrans
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
//  Écran 1 — Accueil
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
    b.setAttribute('aria-checked', 'false');
    b.addEventListener('click', () => selectSeries(n, b));
    grid.appendChild(b);
  });
  updateStartBtn();
}

function selectSeries(n, btn) {
  selectedSeries = n;
  document.querySelectorAll('.series-cell').forEach((c) => {
    c.classList.remove('selected');
    c.setAttribute('aria-checked', 'false');
  });
  btn.classList.add('selected');
  btn.setAttribute('aria-checked', 'true');
  updateStartBtn();
}

function updateStartBtn() {
  $('#start-btn').disabled = selectedSeries < 1;
}

// =====================================================================
//  Écran 2 — Pauses
// =====================================================================
function buildDurations() {
  const grid = $('#duration-grid');
  grid.innerHTML = '';
  DURATIONS.forEach((d) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'duration-cell';
    b.textContent = formatTime(d);
    b.addEventListener('click', () => startTimer(d));
    grid.appendChild(b);
  });
}

function startSession() {
  state.seriesRemaining = selectedSeries;
  state.finished = false;
  updateSeriesReadout();
  showScreen('main');
  showView('duration');
}

function updateSeriesReadout() {
  $('#series-remaining').textContent = state.seriesRemaining;
  $('#series-minus').disabled = state.seriesRemaining <= 0;
}

function adjustSeries(delta) {
  state.seriesRemaining = Math.max(0, state.seriesRemaining + delta);
  updateSeriesReadout();
}

// =====================================================================
//  Timer
// =====================================================================
function startTimer(duration) {
  state.duration = duration;
  state.remaining = duration;
  state.finished = false;
  showView('timer');
  updateTimerUI();
  resumeTimer();
  requestWakeLock();
}

function resumeTimer() {
  if (state.running) return;
  state.running = true;
  state.lastTick = performance.now();
  setPlayPause(true);
  $('#timer-state').textContent = 'En cours';
  state.rafId = requestAnimationFrame(tick);
}

function pauseTimer() {
  if (!state.running) return;
  state.running = false;
  cancelAnimationFrame(state.rafId);
  setPlayPause(false);
  $('#timer-state').textContent = 'En pause';
}

function togglePlayPause() {
  state.running ? pauseTimer() : resumeTimer();
}

function resetTimer() {
  state.remaining = state.duration;
  state.finished = false;
  updateTimerUI();
  if (!state.running) {
    $('#timer-state').textContent = 'En pause';
  }
}

function backToDuration() {
  pauseTimer();
  releaseWakeLock();
  showView('duration');
}

function tick(now) {
  if (!state.running) return;
  const dt = (now - state.lastTick) / 1000;
  state.lastTick = now;
  state.remaining -= dt;

  if (state.remaining <= 0) {
    state.remaining = 0;
    updateTimerUI();
    onTimerComplete();
    return;
  }
  updateTimerUI();
  state.rafId = requestAnimationFrame(tick);
}

function updateTimerUI() {
  const remaining = state.remaining;
  const secsCeil = Math.ceil(remaining);
  $('#time-display').textContent = formatTime(secsCeil);

  const frac = state.duration > 0 ? remaining / state.duration : 0;
  const ring = $('#ring-progress');
  ring.style.strokeDashoffset = RING_CIRCUMFERENCE * (1 - frac);

  const ending = secsCeil <= ENDING_THRESHOLD && remaining > 0;
  ring.classList.toggle('is-ending', ending);
  $('#time-display').classList.toggle('is-ending', ending);
}

function onTimerComplete() {
  state.running = false;
  cancelAnimationFrame(state.rafId);
  if (state.finished) return;
  state.finished = true;

  beep();
  vibrate([200, 100, 200, 100, 200]);

  // une série de bouclée
  state.seriesRemaining = Math.max(0, state.seriesRemaining - 1);
  updateSeriesReadout();

  if (state.seriesRemaining <= 0) {
    releaseWakeLock();
    showScreen('done');
  } else {
    // retour auto au choix de durée pour la pause suivante
    showView('duration');
  }
}

// =====================================================================
//  Lecture des contrôles ▶ / ⏸
// =====================================================================
function setPlayPause(running) {
  $('#playpause-ico').textContent = running ? '⏸' : '▶';
  $('#playpause-txt').textContent = running ? 'Pause' : 'Reprendre';
}

// =====================================================================
//  Utilitaires
// =====================================================================
function formatTime(totalSeconds) {
  const s = Math.max(0, Math.round(totalSeconds));
  const m = Math.floor(s / 60);
  const sec = s % 60;
  if (m === 0) return `${sec}s`;
  return `${m}:${String(sec).padStart(2, '0')}`;
}

// ---- Son : 3 petits bips générés (Web Audio, sans fichier) ----
let audioCtx = null;
function getAudioCtx() {
  if (!audioCtx) {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (AC) audioCtx = new AC();
  }
  return audioCtx;
}
function beep() {
  const ctx = getAudioCtx();
  if (!ctx) return;
  if (ctx.state === 'suspended') ctx.resume();
  const now = ctx.currentTime;
  // 3 bips brefs
  for (let i = 0; i < 3; i++) {
    const t = now + i * 0.22;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(880, t);
    gain.gain.setValueAtTime(0.0001, t);
    gain.gain.exponentialRampToValueAtTime(0.5, t + 0.01);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.16);
    osc.connect(gain).connect(ctx.destination);
    osc.start(t);
    osc.stop(t + 0.18);
  }
}

function vibrate(pattern) {
  if (navigator.vibrate) {
    try { navigator.vibrate(pattern); } catch (_) {}
  }
}

// ---- Écran allumé (Wake Lock) ----
let wakeLock = null;
async function requestWakeLock() {
  if (!('wakeLock' in navigator)) return;
  try {
    wakeLock = await navigator.wakeLock.request('screen');
  } catch (_) { /* ignoré (batterie faible, perte de focus, etc.) */ }
}
function releaseWakeLock() {
  if (wakeLock) {
    wakeLock.release().catch(() => {});
    wakeLock = null;
  }
}
// Ré-acquérir le wake lock quand l'app revient au premier plan pendant un décompte
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible' && state.running) {
    requestWakeLock();
  }
});

// =====================================================================
//  Câblage des événements
// =====================================================================
function wireEvents() {
  $('#start-btn').addEventListener('click', () => {
    if (selectedSeries < 1) return;
    getAudioCtx(); // débloque l'audio sur le geste utilisateur
    startSession();
  });

  $('#home-btn').addEventListener('click', () => {
    pauseTimer();
    releaseWakeLock();
    showScreen('home');
  });

  $('#series-minus').addEventListener('click', () => adjustSeries(-1));
  $('#series-plus').addEventListener('click', () => adjustSeries(1));

  $('#playpause-btn').addEventListener('click', togglePlayPause);
  $('#reset-btn').addEventListener('click', resetTimer);
  $('#change-btn').addEventListener('click', backToDuration);

  $('#newsession-btn').addEventListener('click', () => {
    selectedSeries = 0;
    document.querySelectorAll('.series-cell').forEach((c) => {
      c.classList.remove('selected');
      c.setAttribute('aria-checked', 'false');
    });
    updateStartBtn();
    showScreen('home');
  });
}

// =====================================================================
//  Démarrage
// =====================================================================
function init() {
  buildHome();
  buildDurations();
  wireEvents();
  showScreen('home');
}
init();

// ---- Service worker (hors-ligne) ----
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('sw.js').catch(() => {});
  });
}
