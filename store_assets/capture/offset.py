# offset.py NAME [range]: vertical shift (px) of new/NAME.png against the old raw capture, from grey edges.
import sys
from PIL import Image, ImageFilter, ImageChops, ImageStat
RAW = '/home/thomas/Programmation/Projets/podium/store_assets/raw'
def edges(p): return Image.open(p).convert('L').filter(ImageFilter.FIND_EDGES).point(lambda v: 255 if v > 40 else 0)
name = sys.argv[1]; R = int(sys.argv[2]) if len(sys.argv) > 2 else 40
a, b = edges(f'{RAW}/{name}.png'), edges(f'new/{name}.png')
top = int(sys.argv[3]) if len(sys.argv) > 3 else 140
y0, y1 = top + R, 2250 - R
ref = a.crop((0, y0, 1080, y1))
scores = []
for d in range(-R, R + 1):
    diff = ImageChops.difference(ref, b.crop((0, y0 + d, 1080, y1 + d)))
    scores.append((ImageStat.Stat(diff).mean[0] / 2.55, d))
s, d = min(scores)
print(f'{name}: new = old shifted by {d:+d}px (residual {s:.2f}%)')
