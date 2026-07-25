// Met des captures d'écran brutes aux normes des stores.
//
// Pourquoi : Google Play plafonne les captures téléphone à un ratio de 2:1,
// or un Pixel 8 sort du 1080×2400 (2,22:1) → refusé tel quel. On coupe la
// barre d'état (elle expose aussi les notifications personnelles, à ne pas
// publier) puis on complète à gauche/droite avec le fond de l'app jusqu'à
// tomber exactement sur 2:1 — le fond étant uni, le remplissage est invisible
// et AUCUN contenu n'est perdu (contrairement à un recadrage vertical).
//
// Usage : node scripts/crop_screenshots.js <entrée.png> [...] (sortie dans
// store/screenshots/, numérotée dans l'ordre des arguments).
const fs = require('fs');
const path = require('path');
const { encodePNG, decodePNG } = require('./png');

// Hauteur de la barre d'état, en fraction de la largeur : mesurée à 140 px sur
// une capture 1080 de large, elle grandit avec la définition (les captures
// tablette sont prises en 1440).
const STATUS_BAR_RATIO = 140 / 1080;
const BG = [15, 18, 25];         // #0f1219, le fond de l'app

function toStoreFormat(buf) {
  const src = decodePNG(buf);
  const top = Math.min(Math.round(src.width * STATUS_BAR_RATIO), src.height - 1);
  // Play exige un ratio 9:16 EXACT en portrait. On rogne la hauteur au
  // multiple de 16 inférieur, ce qui donne une largeur entière (h/16*9), puis
  // on complète les côtés avec le fond de l'app — invisible, et aucun contenu
  // perdu (un recadrage vertical, lui, couperait des boutons).
  const h = Math.floor((src.height - top) / 16) * 16;
  const w = (h / 16) * 9;
  if (w < src.width) {
    throw new Error(`capture trop large pour un 9:16 sans perte : ${src.width}px > ${w}px`);
  }
  const padLeft = Math.floor((w - src.width) / 2);

  const out = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const d = (y * w + x) * 4;
      const sx = x - padLeft;
      if (sx < 0 || sx >= src.width) {
        out[d] = BG[0]; out[d + 1] = BG[1]; out[d + 2] = BG[2]; out[d + 3] = 255;
      } else {
        const s = ((y + top) * src.width + sx) * 4;
        out[d] = src.data[s];
        out[d + 1] = src.data[s + 1];
        out[d + 2] = src.data[s + 2];
        out[d + 3] = 255; // les stores refusent la transparence
      }
    }
  }
  return { png: encodePNG(w, h, out), w, h };
}

// --out=<sous-dossier> range les sorties ailleurs que dans screenshots/
// (Play veut des jeux distincts pour téléphone, tablette 7" et tablette 10").
const args = process.argv.slice(2);
const outArg = args.find((a) => a.startsWith('--out='));
const inputs = args.filter((a) => !a.startsWith('--'));
if (!inputs.length) {
  console.error('usage : node scripts/crop_screenshots.js [--out=<dossier>] <entrée.png> [...]');
  process.exit(1);
}
const outDir = path.join(
  __dirname, '..', 'store', outArg ? outArg.slice(6) : 'screenshots');
fs.mkdirSync(outDir, { recursive: true });

inputs.forEach((input, i) => {
  const { png, w, h } = toStoreFormat(fs.readFileSync(input));
  // Le nom d'entrée sert de libellé : « cap2_doset.png » → « 02-doset.png ».
  const label = path.basename(input, '.png').replace(/^cap\d+_?/, '') || 'ecran';
  const name = `${String(i + 1).padStart(2, '0')}-${label}.png`;
  fs.writeFileSync(path.join(outDir, name), png);
  console.log(`${name} — ${w}×${h} (ratio ${(h / w).toFixed(3)}:1)`);
});
