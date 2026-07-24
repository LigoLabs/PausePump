#!/usr/bin/env node
'use strict';

/* ====================================================================
   Génère les bips de PausePump en WAV (44,1 kHz, mono, 16 bits) dans
   mobile/assets/sounds/ — portage hors-ligne du synthé Web Audio de
   js/app.js (mêmes timbres multi-partiels, mêmes enveloppes, mêmes notes).

   Chaque WAV est aussi copié dans android/app/src/main/res/raw/ : c'est le
   son joué par la notification de fin quand l'app est en arrière-plan
   (le son d'un canal de notification Android doit être une ressource raw).

   Usage :  node gen_sounds.js            # ne crée que les fichiers absents
            node gen_sounds.js --force    # régénère tout

   Pur Node, aucune dépendance (même esprit que scripts/gen-icons.js).
   ==================================================================== */

const fs = require('fs');
const path = require('path');

const SAMPLE_RATE = 44100;
const OUT_DIR = path.join(__dirname, '..', 'assets', 'sounds');
const RAW_DIR = path.join(__dirname, '..', 'android', 'app', 'src', 'main', 'res', 'raw');

// --- Copie conforme de TIMBRE / SOUNDS (js/app.js) ---
const TIMBRE = {
  pure:    [{ r: 1, g: 1 }],
  soft:    [{ r: 1, g: 1 }, { r: 2, g: 0.16 }],
  bell:    [{ r: 1, g: 1 }, { r: 2.01, g: 0.5 }, { r: 2.76, g: 0.33 }, { r: 3.94, g: 0.22 }, { r: 5.42, g: 0.15 }, { r: 8.2, g: 0.08 }],
  marimba: [{ r: 1, g: 1 }, { r: 3, g: 0.4 }, { r: 6, g: 0.12 }],
};

const SOUNDS = {
  triple:  { type: 'square',   timbre: 'soft',    peak: 0.30,
             notes: [{ f: 880, t: 0, d: 0.13 }, { f: 880, t: 0.18, d: 0.13 }, { f: 1175, t: 0.36, d: 0.22 }] },
  marimba: { type: 'sine',     timbre: 'marimba', peak: 0.5,
             notes: [{ f: 784, t: 0, d: 0.4 }, { f: 1047, t: 0.13, d: 0.55 }] },
  bell:    { type: 'sine',     timbre: 'bell',    peak: 0.3, // « cloche » côté web
             notes: [{ f: 660, t: 0, d: 1.3 }, { f: 660, t: 0.3, d: 1.6 }] },
  carillon:{ type: 'sine',     timbre: 'bell',    peak: 0.26,
             notes: [{ f: 523, t: 0, d: 0.9 }, { f: 659, t: 0.13, d: 0.9 }, { f: 784, t: 0.26, d: 1.3 }] },
  aigu:    { type: 'sine',     timbre: 'soft',    peak: 0.34,
             notes: [{ f: 1320, t: 0, d: 0.11 }, { f: 1320, t: 0.16, d: 0.13 }] },
  grave:   { type: 'triangle', timbre: 'soft',    peak: 0.45,
             notes: [{ f: 392, t: 0, d: 0.22 }, { f: 294, t: 0.27, d: 0.34 }] },
  montee:  { type: 'sine',     timbre: 'soft',    peak: 0.4,
             notes: [{ from: 523, to: 1047, t: 0, d: 0.5 }] },
};

// Oscillateurs à bande limitée (additif, harmoniques sous Nyquist) pour éviter
// l'aliasing des formes square/triangle aux fréquences des bips.
function oscSample(type, phase, freq) {
  if (type === 'square') {
    let v = 0;
    for (let k = 1; k * freq < SAMPLE_RATE / 2; k += 2) v += Math.sin(k * phase) / k;
    return v * (4 / Math.PI);
  }
  if (type === 'triangle') {
    let v = 0, sign = 1;
    for (let k = 1; k * freq < SAMPLE_RATE / 2; k += 2, sign = -sign) v += sign * Math.sin(k * phase) / (k * k);
    return v * (8 / (Math.PI * Math.PI));
  }
  return Math.sin(phase);
}

// Rampe exponentielle façon Web Audio : v(t) = v0 * (v1/v0)^(t/T)
function expRamp(v0, v1, t, T) {
  if (t <= 0) return v0;
  if (t >= T) return v1;
  return v0 * Math.pow(v1 / v0, t / T);
}

// Rend une note (tous ses partiels) dans `buf` — équivalent de scheduleVoice().
function renderNote(buf, def, n) {
  const partials = TIMBRE[def.timbre] || TIMBRE.pure;
  const atk = 0.006;
  const start = Math.floor(n.t * SAMPLE_RATE);
  const len = Math.floor((n.d + 0.05) * SAMPLE_RATE);
  for (const p of partials) {
    const peak = Math.max(0.0002, (def.peak || 0.4) * p.g);
    let phase = 0;
    for (let i = 0; i < len; i++) {
      const t = i / SAMPLE_RATE;
      // Fréquence : fixe, ou glissando exponentiel (note { from, to }).
      const f = n.from != null
        ? expRamp(n.from * p.r, n.to * p.r, Math.min(t, n.d), n.d)
        : n.f * p.r;
      phase += (2 * Math.PI * f) / SAMPLE_RATE;
      // Enveloppe percussive : attaque exp. 6 ms puis décroissance exp. vers ~0.
      const env = t < atk
        ? expRamp(0.0001, peak, t, atk)
        : expRamp(peak, 0.0001, t - atk, n.d - atk);
      const idx = start + i;
      if (idx < buf.length) buf[idx] += oscSample(def.type, phase, f) * env;
    }
  }
}

function renderSound(def) {
  const total = Math.max(...def.notes.map((n) => n.t + n.d)) + 0.3;
  const buf = new Float64Array(Math.ceil(total * SAMPLE_RATE));
  def.notes.forEach((n) => renderNote(buf, def, n));
  // Légère saturation douce en garde-fou (le bus master web a un compresseur).
  for (let i = 0; i < buf.length; i++) buf[i] = Math.tanh(buf[i] * 0.95);
  return buf;
}

function writeWav(file, samples) {
  const dataLen = samples.length * 2;
  const b = Buffer.alloc(44 + dataLen);
  b.write('RIFF', 0); b.writeUInt32LE(36 + dataLen, 4); b.write('WAVE', 8);
  b.write('fmt ', 12); b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20); // PCM
  b.writeUInt16LE(1, 22);                       // mono
  b.writeUInt32LE(SAMPLE_RATE, 24);
  b.writeUInt32LE(SAMPLE_RATE * 2, 28);         // byte rate
  b.writeUInt16LE(2, 32); b.writeUInt16LE(16, 34);
  b.write('data', 36); b.writeUInt32LE(dataLen, 40);
  for (let i = 0; i < samples.length; i++) {
    const v = Math.max(-1, Math.min(1, samples[i]));
    b.writeInt16LE(Math.round(v * 32767), 44 + i * 2);
  }
  fs.writeFileSync(file, b);
}

const force = process.argv.includes('--force');
fs.mkdirSync(RAW_DIR, { recursive: true });
for (const [id, def] of Object.entries(SOUNDS)) {
  const file = path.join(OUT_DIR, `${id}.wav`);
  if (force || !fs.existsSync(file)) {
    writeWav(file, renderSound(def));
    console.log(`+ ${id}.wav`);
  } else {
    console.log(`= ${id}.wav (déjà présent)`);
  }
  const raw = path.join(RAW_DIR, `${id}.wav`);
  if (force || !fs.existsSync(raw)) fs.copyFileSync(file, raw);
}
