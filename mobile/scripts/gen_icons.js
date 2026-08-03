// Génère toutes les icônes natives (Android + iOS + fiches store) à partir du
// design de la PWA (scripts/gen-icons.js à la racine) : carré sombre, anneau
// accent, barres de pause. Zéro dépendance (PNG encodé à la main), comme le
// reste du repo. Usage : node scripts/gen_icons.js (depuis mobile/).
//
// Variantes :
//  - full   : plein cadre OPAQUE (iOS exige des icônes sans alpha ; le Play
//             Store arrondit lui-même les coins de l'icône 512)
//  - legacy : carré arrondi transparent (mipmap ic_launcher, Android < 8)
//  - fg     : motif seul, réduit dans la « safe zone » adaptive (Android 8+)
//  - mono   : comme fg, tout blanc (icônes thématiques Android 13+)
const fs = require('fs');
const path = require('path');
const { encodePNG } = require('./png');

// -- Palette et géométrie : mêmes valeurs que la PWA -------------------------
const BG = [15, 18, 25];        // #0f1219
const RING = [34, 211, 167];    // accent
const RING_DIM = [30, 41, 55];  // piste de l'anneau
const BAR = [233, 240, 245];    // barres de pause
const WHITE = [255, 255, 255];

// Piste de l'anneau dans la variante montre : un teal assombri, qui reste
// lisible sur le fond accent sans virer au noir.
const WATCH_DIM = [17, 148, 118];

const SS = 4; // supersampling ×4 : les petites tailles (20 px iOS) restent nettes

function render(outW, outH, mode) {
  const w = outW * SS, h = outH * SS;
  const buf = Buffer.alloc(w * h * 4);
  const cx = w / 2, cy = h / 2;
  // Le motif est dimensionné sur le plus petit côté (bandeau 1024×500 inclus).
  const base = Math.min(w, h);
  // Adaptive : le contenu doit tenir dans un cercle de 66/108 du canevas.
  const scale = (mode === 'fg' || mode === 'mono') ? 0.72 : 1.0;
  const ringOuter = base * 0.40 * scale;
  const ringInner = base * 0.32 * scale;
  const corner = base * 0.22;
  // watch : palette inversée (fond accent, motif sombre). watchOS masque les
  // icônes en rond ; avec le fond sombre habituel, le disque se confondait
  // avec le cadran noir et l'app a été rejetée pour ça (guideline 4).
  const watch = mode === 'watch';
  const opaque = mode === 'full' || watch;
  const rounded = mode === 'legacy';
  const ink = mode === 'mono';

  const bgColor = watch ? RING : BG;
  const ringLit = watch ? BG : RING;
  const ringDim = watch ? WATCH_DIM : RING_DIM;
  const barColor = watch ? BG : BAR;

  function setPx(x, y, c) {
    const i = (y * w + x) * 4;
    buf[i] = c[0]; buf[i + 1] = c[1]; buf[i + 2] = c[2]; buf[i + 3] = 255;
  }
  function inRoundedSquare(x, y) {
    const dx = Math.max(Math.abs(x - cx) - (w / 2 - corner), 0);
    const dy = Math.max(Math.abs(y - cy) - (h / 2 - corner), 0);
    return Math.sqrt(dx * dx + dy * dy) <= corner;
  }

  const barW = base * 0.07 * scale;
  const barH = base * 0.20 * scale;
  const gap = base * 0.05 * scale;
  const bar1 = cx - gap / 2 - barW / 2;
  const bar2 = cx + gap / 2 + barW / 2;
  function inBar(x, y, bx) {
    return Math.abs(x - bx) <= barW / 2 && Math.abs(y - cy) <= barH / 2;
  }

  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      if (rounded && !inRoundedSquare(x, y)) continue; // transparent
      if (opaque || rounded) setPx(x, y, ink ? WHITE : bgColor);

      const dx = x - cx, dy = y - cy;
      const dist = Math.sqrt(dx * dx + dy * dy);
      if (dist >= ringInner && dist <= ringOuter) {
        let ang = Math.atan2(dx, -dy); // 0 en haut, sens horaire
        if (ang < 0) ang += Math.PI * 2;
        const lit = ang / (Math.PI * 2) <= 0.72;
        if (ink) { if (lit) setPx(x, y, WHITE); }
        else setPx(x, y, lit ? ringLit : ringDim);
      }
      if (inBar(x, y, bar1) || inBar(x, y, bar2)) setPx(x, y, ink ? WHITE : barColor);
    }
  }

  // Downscale SS×SS → moyenne par bloc (anti-aliasing).
  const out = Buffer.alloc(outW * outH * 4);
  for (let y = 0; y < outH; y++) {
    for (let x = 0; x < outW; x++) {
      let r = 0, g = 0, b = 0, a = 0;
      for (let sy = 0; sy < SS; sy++) {
        for (let sx = 0; sx < SS; sx++) {
          const i = ((y * SS + sy) * w + x * SS + sx) * 4;
          const pa = buf[i + 3] / 255;
          r += buf[i] * pa; g += buf[i + 1] * pa; b += buf[i + 2] * pa;
          a += buf[i + 3];
        }
      }
      const n = SS * SS, o = (y * outW + x) * 4;
      const pa = a / n / 255;
      out[o] = pa > 0 ? r / n / pa : 0;
      out[o + 1] = pa > 0 ? g / n / pa : 0;
      out[o + 2] = pa > 0 ? b / n / pa : 0;
      out[o + 3] = a / n;
    }
  }
  return encodePNG(outW, outH, out);
}

// -- Sorties -----------------------------------------------------------------
const root = path.join(__dirname, '..');
function write(rel, data) {
  const p = path.join(root, rel);
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, data);
  console.log('wrote', rel, `(${data.length} o)`);
}

// iOS : toutes les tailles du Contents.json (opaques — Apple refuse l'alpha).
const iosSet = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const contents = JSON.parse(
  fs.readFileSync(path.join(root, iosSet, 'Contents.json'), 'utf8'));
const done = new Set();
for (const img of contents.images) {
  if (!img.filename || done.has(img.filename)) continue;
  done.add(img.filename);
  const pts = parseFloat(img.size);           // "83.5x83.5" → 83.5
  const px = Math.round(pts * parseInt(img.scale)); // "2x" → 2
  write(path.join(iosSet, img.filename), render(px, px, 'full'));
}

// Android : legacy (toutes densités) + adaptive foreground/monochrome.
const density = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
for (const [d, k] of Object.entries(density)) {
  const res = `android/app/src/main/res/mipmap-${d}`;
  write(`${res}/ic_launcher.png`, render(48 * k, 48 * k, 'legacy'));
  write(`${res}/ic_launcher_foreground.png`, render(108 * k, 108 * k, 'fg'));
  write(`${res}/ic_launcher_monochrome.png`, render(108 * k, 108 * k, 'mono'));
}

// watchOS : une seule taille (1024, opaque), masquée en rond par le système.
// Variante « watch » à fond clair : Apple rejette (guideline 4) une icône
// watchOS à fond noir, qui ne se distingue pas du cadran une fois masquée.
write('ios/PausePumpWatch/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png',
  render(1024, 1024, 'watch'));

// Fiches store : icône Play 512 (opaque) + bandeau « feature graphic ».
write('store/play-icon-512.png', render(512, 512, 'full'));
write('store/feature-graphic-1024x500.png', render(1024, 500, 'full'));

console.log('done');
