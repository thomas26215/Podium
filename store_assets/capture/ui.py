#!/usr/bin/env python3
"""Drives the demo app on the emulator: ls | tap REGEX [n] | shot NAME | cmp NAME | swipe x1 y1 x2 y2 [ms] | key CODE | type TEXT"""
import html, re, subprocess, sys, os
S = os.path.dirname(os.path.abspath(__file__))  # new/ (captures) and view.png land here
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
cmd, *args = sys.argv[1:]
if cmd == 'ls':
    for label, c, b, cls, sc in nodes():
        if label or sc: print(('*' if c else ' ') + ('S' if sc else ' '), repr(label[:70]), b)
elif cmd == 'tap':
    pat, n = re.compile(args[0]), int(args[1]) if len(args) > 1 else 0
    hits = [x for x in nodes() if x[0] and pat.search(x[0])]
    if len(hits) <= n: sys.exit(f'no match for {args[0]!r}: {[h[0][:40] for h in hits]}')
    label, _, b, _, _ = hits[n]
    x, y = (b[0] + b[2]) // 2, (b[1] + b[3]) // 2
    sh('adb', 'shell', 'input', 'tap', str(x), str(y)); print('tap', repr(label[:50]), x, y)
elif cmd == 'shot':
    name = args[0]
    png = subprocess.run(['adb', 'exec-out', 'screencap', '-p'], capture_output=True).stdout
    open(f'{S}/new/{name}.png', 'wb').write(png)
    sh('magick', f'{S}/new/{name}.png', '-resize', '360x', f'{S}/view.png'); print('shot', name)
elif cmd == 'view':
    png = subprocess.run(['adb', 'exec-out', 'screencap', '-p'], capture_output=True).stdout
    open(f'{S}/cur.png', 'wb').write(png)
    sh('magick', f'{S}/cur.png', '-resize', '360x', f'{S}/view.png'); print('view')
elif cmd == 'cmp':
    name = args[0]
    sh('magick', f'{RAW}/{name}.png', f'{S}/new/{name}.png', '-resize', '360x', '+append', f'{S}/view.png')
    # layout check: edges of both, compared in grey
    e = [f'{S}/e_old.png', f'{S}/e_new.png']
    for src, dst in zip([f'{RAW}/{name}.png', f'{S}/new/{name}.png'], e):
        sh('magick', src, '-crop', '1080x2280+0+120', '+repage', '-colorspace', 'gray', '-edge', '1', '-threshold', '20%', dst)
    r = sh('magick', e[0], e[1], '-compose', 'difference', '-composite', '-format', '%[fx:mean]', 'info:')
    print(f'layout drift: {float(r.stdout) * 100:.2f} % of edge pixels differ (0 = same layout)')
elif cmd == 'swipe':
    sh('adb', 'shell', 'input', 'swipe', *args)
elif cmd == 'key':
    sh('adb', 'shell', 'input', 'keyevent', args[0])
elif cmd == 'type':
    sh('adb', 'shell', 'input', 'text', args[0].replace(' ', '%s'))
