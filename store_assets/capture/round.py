#!/usr/bin/env python3
"""Drives the demo app on the emulator: ls | tap REGEX [n] | shot NAME | cmp NAME | swipe x1 y1 x2 y2 [ms] | key CODE | type TEXT"""
import html, re, subprocess, sys, os, time
S = os.path.dirname(os.path.abspath(__file__))
RAW = '/home/thomas/Programmation/Projets/podium/store_assets/raw'
def sh(*a, **k): return subprocess.run(list(a), capture_output=True, text=k.get('text', True))
def nodes():
    sh('adb', 'shell', 'uiautomator', 'dump', '/sdcard/ui.xml')
    x = sh('adb', 'shell', 'cat', '/sdcard/ui.xml').stdout
    out = []
    for m in re.finditer(r'<node ([^>]*?)/?>', x):
        a = dict(re.findall(r'([\w-]+)="([^"]*)"', m.group(1)))
        label = html.unescape(a.get('content-desc') or a.get('text') or '').replace('\n', ' | ')
        b = list(map(int, re.findall(r'\d+', a.get('bounds', '[0,0][0,0]'))))
        out.append((label, a.get('clickable') == 'true', b, a.get('class', ''), a.get('scrollable') == 'true'))
    return out

vals = sys.argv[1:5]
rows = {}
for label, c, b, cls, sc in nodes():
    if label in ('Léa', 'Hugo', 'Inès', 'Malik') and label not in rows: rows[label] = (b[1] + b[3]) // 2
assert len(rows) == 4, rows
for name, v in zip(('Léa', 'Hugo', 'Inès', 'Malik'), vals):
    sh('adb', 'shell', 'input', 'tap', '910', str(rows[name])); time.sleep(0.4)
    sh('adb', 'shell', 'input', 'keyevent', 'KEYCODE_MOVE_END')
    for _ in range(3): sh('adb', 'shell', 'input', 'keyevent', 'KEYCODE_DEL')
    sh('adb', 'shell', 'input', 'text', v); time.sleep(0.3)
print('round', vals, rows)
