// Checks every store visual's layout in the browser: the title on two lines
// and the subtitle on one, every overlay (pop, tag, note, brand) inside the
// canvas with a margin, the title block in the same place everywhere, and
// overlays that collide.
//   node qa.mjs
import { readdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { chromium } from 'playwright-core';

const here = path.dirname(fileURLToPath(import.meta.url));
const pages = readdirSync(here).filter((f) => /^\d\d_.+\.html$/.test(f)).sort();
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM ?? '/usr/bin/chromium-browser' });
const page = await browser.newPage({ viewport: { width: 1080, height: 1920 } });
let problems = 0;
for (const file of pages) {
  await page.goto(pathToFileURL(path.join(here, file)).href, { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);
  const r = await page.evaluate(() => {
    const box = (el) => { const b = el.getBoundingClientRect(); return { l: Math.round(b.left), t: Math.round(b.top), r: Math.round(b.right), b: Math.round(b.bottom) }; };
    const lines = (el) => Math.round(el.getBoundingClientRect().height / parseFloat(getComputedStyle(el).lineHeight));
    const title = document.querySelector('.title'), sub = document.querySelector('.subtitle');
    const overlays = [...document.querySelectorAll('.pop, .tag, .note, .brand')].map((el) => ({ kind: el.className, ...box(el) }));
    return { titleLines: lines(title), subLines: lines(sub), head: box(document.querySelector('.head')), sub: box(sub), overlays, phones: [...document.querySelectorAll('.phone')].map(box) };
  });
  const issues = [];
  if (r.titleLines !== 2) issues.push(`titre sur ${r.titleLines} lignes`);
  if (r.subLines !== 1) issues.push(`sous-titre sur ${r.subLines} lignes`);
  if (r.head.t !== 116) issues.push(`bloc titre en ${r.head.t}px`);
  for (const o of r.overlays) {
    if (o.l < 24 || o.r > 1056 || o.t < r.sub.b + 20 || o.b > 1896) issues.push(`${o.kind} hors marges (${o.l},${o.t})-(${o.r},${o.b})`);
  }
  for (let i = 0; i < r.overlays.length; i++) {
    for (let j = i + 1; j < r.overlays.length; j++) {
      const a = r.overlays[i], b = r.overlays[j];
      const w = Math.min(a.r, b.r) - Math.max(a.l, b.l), h = Math.min(a.b, b.b) - Math.max(a.t, b.t);
      if (w > 0 && h > 0 && !(a.kind.includes('round') && b.kind.includes('round'))) issues.push(`${a.kind} et ${b.kind} se chevauchent (${w}×${h})`);
    }
  }
  problems += issues.length;
  console.log(`${file}: titre ${r.titleLines} l., sous-titre ${r.subLines} l. (bas ${r.sub.b}px), téléphones ${r.phones.map((p) => `${p.l}→${p.r}`).join(' / ')}${issues.length ? '\n  ⚠ ' + issues.join('\n  ⚠ ') : '  ✓'}`);
}
await browser.close();
process.exitCode = problems ? 1 : 0;
