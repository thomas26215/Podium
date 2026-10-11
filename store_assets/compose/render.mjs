// Renders the store visuals (NN_*.html, 1080 × 1920) and the feature
// graphic (presentation_*.html, 1024 × 500) to PNGs in ../final/ with
// Playwright, on the system's Chromium. A page sets its own size with
// <meta name="canvas" content="WxH"> (1080x1920 without one).
//   npm install                    (once)
//   node render.mjs                everything
//   node render.mjs 01 presentation  only those
// CHROMIUM=/path/to/chrome overrides the browser.
import { readdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { chromium } from 'playwright-core';

const here = path.dirname(fileURLToPath(import.meta.url));
const out = path.join(here, '..', 'final');
const wanted = process.argv.slice(2);
const pages = readdirSync(here)
  .filter((f) => /^(\d\d_|presentation_).+\.html$/.test(f))
  .filter((f) => wanted.length === 0 || wanted.some((w) => f.startsWith(w)))
  .sort();

const browser = await chromium.launch({ executablePath: process.env.CHROMIUM ?? '/usr/bin/chromium-browser' });
const page = await browser.newPage({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
for (const file of pages) {
  await page.goto(pathToFileURL(path.join(here, file)).href, { waitUntil: 'load' });
  const [width, height] = await page.evaluate(() => (document.querySelector('meta[name=canvas]')?.content ?? '1080x1920').split('x').map(Number));
  await page.setViewportSize({ width, height });
  await page.evaluate(async () => {
    await document.fonts.ready;
    await Promise.all([...document.images].map((img) => img.decode().catch(() => {})));
  });
  // CSS backgrounds (the panorama, the crops) are decoded on paint.
  await page.waitForTimeout(400);
  const png = path.join(out, file.replace(/\.html$/, '.png'));
  await page.screenshot({ path: png, clip: { x: 0, y: 0, width, height } });
  console.log(`→ ${path.relative(path.join(here, '..'), png)}`);
}
await browser.close();
