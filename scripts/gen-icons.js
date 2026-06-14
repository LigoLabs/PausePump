// Minimal PNG icon generator (no external deps).
// Draws the PausePump icon: dark rounded square, accent ring, pause bars.
const zlib = require('zlib');
const fs = require('fs');
const path = require('path');

function makePNG(size) {
  const w = size, h = size;
  const buf = Buffer.alloc(w * h * 4);

  const cx = w / 2, cy = h / 2;
  const ringOuter = size * 0.40;
  const ringInner = size * 0.32;
  const corner = size * 0.22; // rounded square radius

  // colors
  const bg = [15, 18, 25];        // #0f1219 dark
  const ring = [34, 211, 167];    // teal/green accent
  const ringDim = [30, 41, 55];   // ring track
  const bar = [233, 240, 245];    // light bars

  function setPx(x, y, c, a = 255) {
    const i = (y * w + x) * 4;
    const inv = (255 - a) / 255, fa = a / 255;
    buf[i] = c[0] * fa + buf[i] * inv;
    buf[i + 1] = c[1] * fa + buf[i + 1] * inv;
    buf[i + 2] = c[2] * fa + buf[i + 2] * inv;
    buf[i + 3] = 255;
  }

  // rounded-square background mask
  function inRoundedSquare(x, y) {
    const dx = Math.max(Math.abs(x - cx) - (w / 2 - corner), 0);
    const dy = Math.max(Math.abs(y - cy) - (h / 2 - corner), 0);
    return Math.sqrt(dx * dx + dy * dy) <= corner;
  }

  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      // transparent outside rounded square
      if (!inRoundedSquare(x, y)) {
        const i = (y * w + x) * 4;
        buf[i + 3] = 0;
        continue;
      }
      setPx(x, y, bg);

      const dx = x - cx, dy = y - cy;
      const dist = Math.sqrt(dx * dx + dy * dy);

      // ring track + progress arc
      if (dist >= ringInner && dist <= ringOuter) {
        // angle from top, clockwise
        let ang = Math.atan2(dx, -dy); // 0 at top
        if (ang < 0) ang += Math.PI * 2;
        const frac = ang / (Math.PI * 2);
        if (frac <= 0.72) setPx(x, y, ring);
        else setPx(x, y, ringDim);
      }
    }
  }

  // pause bars in center
  const barW = size * 0.07;
  const barH = size * 0.20;
  const gap = size * 0.05;
  function drawBar(bx) {
    for (let y = cy - barH / 2; y < cy + barH / 2; y++) {
      for (let x = bx - barW / 2; x < bx + barW / 2; x++) {
        setPx(Math.round(x), Math.round(y), bar);
      }
    }
  }
  drawBar(cx - gap / 2 - barW / 2);
  drawBar(cx + gap / 2 + barW / 2);

  // encode PNG
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0; // filter none
    buf.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4);
  }
  const idat = zlib.deflateSync(raw, { level: 9 });

  function chunk(type, data) {
    const len = Buffer.alloc(4);
    len.writeUInt32BE(data.length, 0);
    const t = Buffer.from(type, 'ascii');
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(crc32(Buffer.concat([t, data])) >>> 0, 0);
    return Buffer.concat([len, t, data, crc]);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8;  // bit depth
  ihdr[9] = 6;  // RGBA
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  return Buffer.concat([sig, chunk('IHDR', ihdr), chunk('IDAT', idat), chunk('IEND', Buffer.alloc(0))]);
}

// CRC32
const crcTable = (() => {
  const t = new Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();
function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = crcTable[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

const out = path.join(__dirname, '..', 'icons');
for (const s of [192, 512]) {
  fs.writeFileSync(path.join(out, `icon-${s}.png`), makePNG(s));
  console.log(`wrote icon-${s}.png`);
}
// maskable (same art, ample padding already)
fs.writeFileSync(path.join(out, 'maskable-512.png'), makePNG(512));
fs.writeFileSync(path.join(out, 'apple-touch-icon.png'), makePNG(180));
console.log('done');
