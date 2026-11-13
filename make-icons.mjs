// Draws the addon's two icons and writes them as 64x64 TGA files, the format the game loads.
//   Media/icon.tga     the full badge (gold ring, three role gems), for the addon list and addon menu
//   Media/minimap.tga  the gems on a dark disc with no ring, since the minimap button adds its own ring
//
//   node make-icons.mjs

import { mkdirSync, writeFileSync } from 'node:fs';

const SIZE = 64;
const SS = 4; // samples per axis for smooth edges

const BG = [22, 18, 13];
const RING = [224, 184, 74];
const RING_DARK = [138, 109, 42];
const GEMS = [
  { x: 0.5, y: 0.34, c: [95, 168, 255] }, // tank
  { x: 0.34, y: 0.61, c: [79, 214, 122] }, // healer
  { x: 0.66, y: 0.61, c: [255, 107, 94] }, // dps
];

function gem(u, v, scale) {
  for (const g of GEMS) {
    const gx = 0.5 + (g.x - 0.5) * scale;
    const gy = 0.5 + (g.y - 0.5) * scale;
    const d = Math.hypot(u - gx, v - gy);
    const r = 0.11 * scale;
    if (d < r) {
      // A small highlight toward the top-left makes it read as a gem.
      const light = Math.max(0, 1 - Math.hypot(u - (gx - r * 0.3), v - (gy - r * 0.35)) / r);
      return g.c.map((c) => Math.min(255, Math.round(c * (0.75 + 0.5 * light))));
    }
  }
  return null;
}

function badge(u, v) {
  const d = Math.hypot(u - 0.5, v - 0.5);
  if (d > 0.49) return null;
  if (d > 0.4) return d > 0.455 ? RING_DARK : RING;
  return gem(u, v, 1) || BG;
}

function disc(u, v) {
  const d = Math.hypot(u - 0.5, v - 0.5);
  if (d > 0.5) return null;
  return gem(u, v, 1.3) || BG;
}

function render(sample) {
  // Uncompressed 32-bit TGA, rows stored bottom-up, pixels as BGRA.
  const header = Buffer.alloc(18);
  header[2] = 2;
  header.writeUInt16LE(SIZE, 12);
  header.writeUInt16LE(SIZE, 14);
  header[16] = 32;
  header[17] = 8;
  const pixels = Buffer.alloc(SIZE * SIZE * 4);
  for (let row = 0; row < SIZE; row++) {
    const y = SIZE - 1 - row;
    for (let x = 0; x < SIZE; x++) {
      let r = 0, g = 0, b = 0, a = 0;
      for (let sy = 0; sy < SS; sy++) {
        for (let sx = 0; sx < SS; sx++) {
          const c = sample((x + (sx + 0.5) / SS) / SIZE, (y + (sy + 0.5) / SS) / SIZE);
          if (c) {
            r += c[0];
            g += c[1];
            b += c[2];
            a += 1;
          }
        }
      }
      const o = (row * SIZE + x) * 4;
      if (a > 0) {
        pixels[o] = Math.round(b / a);
        pixels[o + 1] = Math.round(g / a);
        pixels[o + 2] = Math.round(r / a);
        pixels[o + 3] = Math.round((a / (SS * SS)) * 255);
      }
    }
  }
  return Buffer.concat([header, pixels]);
}

const out = new URL('./AntiSocial/Media/', import.meta.url);
mkdirSync(out, { recursive: true });
writeFileSync(new URL('icon.tga', out), render(badge));
writeFileSync(new URL('minimap.tga', out), render(disc));
console.log('wrote AntiSocial/Media/icon.tga and minimap.tga');
