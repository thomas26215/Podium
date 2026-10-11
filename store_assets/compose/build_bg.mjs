// Builds bg.svg: the one panorama the 8 store visuals are cut from (8 × 1080
// wide, 1920 high), so the navy ground, the halos, the stars and the Elo-like
// line run on from one visual to the next. Each visual shows its 1080 px
// slice (see system.css, --panel).
//   node build_bg.mjs
import { writeFileSync } from 'node:fs';

const W = 8640, H = 1920, P = 1080;

// Deterministic randomness, so the stars never move between renders.
let seed = 20261007;
const rand = () => ((seed = (seed * 1664525 + 1013904223) % 4294967296) / 4294967296);

// Brand colours: the icon's night blue, mint meeple and gold crown; the
// app's mint accent (the icon's mint, darker); a cool blue for the cold
// moments.
const navy = '#0B1238', gold = '#F5A623', blue = '#4A90F2', mint = '#5FDDB6', accent = '#1DA578';

// Each visual's glow follows the story: the promise (gold), the problem
// (cold), the evening lighting up, the win (gold), the brand for the call to
// action.
const halos = [
  // [x, y, radius, colour, opacity]
  [540, 760, 760, gold, 0.30], [540, 1560, 620, accent, 0.20],
  [1620, 860, 760, '#6C7BA8', 0.22],
  [2700, 860, 760, blue, 0.30],
  [3780, 900, 760, blue, 0.18], [3900, 1450, 620, accent, 0.20],
  [4860, 880, 760, accent, 0.26], [4860, 1500, 600, gold, 0.16],
  [5940, 860, 760, gold, 0.28],
  [7020, 820, 760, '#2FA59C', 0.24], [7150, 1500, 600, gold, 0.16],
  [7900, 760, 620, blue, 0.26], [8360, 1350, 620, mint, 0.20], [8100, 520, 420, gold, 0.22],
];

// The line: an Elo curve across the series — it rises with the promise,
// gets lost on paper (visual 2), climbs through the evening and the
// tournament, and ends on the logo's crown in the last visual.
const pts = [
  // 1 — the promise: rising
  [-60, 1372], [180, 1330], [520, 1292], [860, 1266], [1080, 1250],
  // 2 — the problem: it gets lost on paper
  [1300, 1235], [1560, 1360], [1860, 1400], [2160, 1430],
  // 3 to 8: behind the phones it climbs, and it shows where they leave room —
  // the margins, and the free corner above the phone in front, which
  // alternates sides — rising overall, up to the logo's crown.
  [2260, 1400], [2560, 1100], [2780, 800], [2960, 735], [3240, 720],
  [3440, 700], [3640, 760], [3900, 960], [4150, 1120], [4320, 1180],
  [4420, 1150], [4700, 1000], [4980, 760], [5160, 700], [5400, 680],
  [5600, 660], [5800, 720], [6050, 900], [6300, 1010], [6480, 1050],
  [6580, 1020], [6860, 860], [7120, 700], [7330, 655], [7560, 640],
  [7700, 630], [7900, 606], [8150, 590], [8300, 562], [8400, 528],
];

// Catmull-Rom through the points, as cubic Béziers.
function smooth(points) {
  let d = `M ${points[0][0]} ${points[0][1]}`;
  for (let i = 0; i < points.length - 1; i++) {
    const p0 = points[Math.max(0, i - 1)], p1 = points[i], p2 = points[i + 1], p3 = points[Math.min(points.length - 1, i + 2)];
    const c1 = [p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6];
    const c2 = [p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6];
    d += ` C ${c1[0].toFixed(1)} ${c1[1].toFixed(1)}, ${c2[0].toFixed(1)} ${c2[1].toFixed(1)}, ${p2[0]} ${p2[1]}`;
  }
  return d;
}
const line = smooth(pts);
const area = `${line} L ${pts.at(-1)[0]} ${H} L ${pts[0][0]} ${H} Z`;

// Stars: four-point sparkles and dots, kept faint behind the titles.
const f = (n) => n.toFixed(1);
const sparkle = (x, y, r) => {
  const k = r * 0.18;
  return `M ${f(x)} ${f(y - r)} Q ${f(x + k)} ${f(y - k)} ${f(x + r)} ${f(y)} Q ${f(x + k)} ${f(y + k)} ${f(x)} ${f(y + r)} Q ${f(x - k)} ${f(y + k)} ${f(x - r)} ${f(y)} Q ${f(x - k)} ${f(y - k)} ${f(x)} ${f(y - r)} Z`;
};
const stars = [];
for (let panel = 0; panel < 8; panel++) {
  for (let i = 0; i < 34; i++) {
    const x = panel * P + 20 + rand() * (P - 40);
    const y = 40 + rand() * (H - 80);
    const local = x - panel * P;
    // Nothing behind the title and subtitle: a star between two letters
    // reads as a stray accent.
    if (y > 70 && y < 370 && local > 90 && local < 990) continue;
    const underTitle = y > 70 && y < 520 && local > 90 && local < 990;
    const colour = [ '#FFFFFF', '#FFFFFF', '#FFFFFF', gold, blue, mint ][Math.floor(rand() * 6)];
    const big = rand() < 0.28;
    const r = big ? 9 + rand() * 13 : 2 + rand() * 3;
    const opacity = (underTitle ? 0.18 : 0.35) + rand() * (underTitle ? 0.12 : 0.45);
    stars.push(big
      ? `<path d="${sparkle(x, y, r)}" fill="${colour}" opacity="${opacity.toFixed(2)}"/>`
      : `<circle cx="${f(x)}" cy="${f(y)}" r="${f(r)}" fill="${colour}" opacity="${opacity.toFixed(2)}"/>`);
  }
}

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  <defs>
    <linearGradient id="ground" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#070C27"/>
      <stop offset="0.55" stop-color="${navy}"/>
      <stop offset="1" stop-color="#111A49"/>
    </linearGradient>
    ${halos.map(([, , , c, o], i) => `<radialGradient id="h${i}"><stop offset="0" stop-color="${c}" stop-opacity="${o}"/><stop offset="0.55" stop-color="${c}" stop-opacity="${(o * 0.35).toFixed(3)}"/><stop offset="1" stop-color="${c}" stop-opacity="0"/></radialGradient>`).join('\n    ')}
    <linearGradient id="ink" x1="0" y1="0" x2="${W}" y2="0" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="${accent}"/>
      <stop offset="0.45" stop-color="${mint}"/>
      <stop offset="0.75" stop-color="${gold}"/>
      <stop offset="1" stop-color="#FFD27A"/>
    </linearGradient>
    <linearGradient id="fill" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${accent}" stop-opacity="0.10"/>
      <stop offset="1" stop-color="${accent}" stop-opacity="0"/>
    </linearGradient>
    <filter id="glow" x="-5%" y="-50%" width="110%" height="200%"><feGaussianBlur stdDeviation="14"/></filter>
  </defs>
  <rect width="${W}" height="${H}" fill="url(#ground)"/>
  ${halos.map(([x, y, r], i) => `<circle cx="${x}" cy="${y}" r="${r}" fill="url(#h${i})"/>`).join('\n  ')}
  ${stars.join('\n  ')}
  <path d="${area}" fill="url(#fill)"/>
  <path d="${line}" fill="none" stroke="url(#ink)" stroke-width="22" stroke-linecap="round" opacity="0.55" filter="url(#glow)"/>
  <path d="${line}" fill="none" stroke="url(#ink)" stroke-width="8" stroke-linecap="round"/>
</svg>
`;
writeFileSync(new URL('./bg.svg', import.meta.url), svg);
console.log(`bg.svg: ${W}×${H}, ${stars.length} étoiles`);
