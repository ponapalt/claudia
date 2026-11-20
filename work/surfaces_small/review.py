"""Contact sheet of the composed surfaces of shell/small (overlay parts pasted on their base, as SSP does).

  python work/surfaces_small/review.py [zoom] [r,g,b] [columns] [out.png]
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__)).replace(chr(92), '/')
sys.path.insert(0, HERE)
import tools as t  # noqa: E402

ROOT = HERE.rsplit('/work/', 1)[0]
OUT = ROOT + '/shell/small'
info = json.load(open(HERE + '/build-info.json'))


def L(n):
    return np.array(Image.open(f'{OUT}/{n}.png').convert('RGBA'))


def over(base, name):
    p = L(name)
    x, y = info[name][:2]
    b = base.copy()
    h, w = p.shape[:2]
    reg = b[y:y + h, x:x + w].astype(float)
    pa = p[..., 3:4] / 255.0
    rgb = np.round(p[..., :3] * pa + reg[..., :3] * (1 - pa))
    al = np.maximum(p[..., 3:4], reg[..., 3:4])
    b[y:y + h, x:x + w] = np.concatenate([rgb, al], -1).astype(np.uint8)
    return b


s0 = L('surface0')
s7 = L('surface7')
S = {'0': s0, '1': over(s0, 'claudia_eyes_1'), '2': L('surface2'), '3': over(s0, 'claudia_eyes_3'), '4': L('surface4'),
     '5': L('surface5'), '6': over(s0, 'surface1000'), '7': s7, '8': L('surface8'),
     '9': over(s0, 'claudia_eyes_9'), '25': over(s0, 'claudia_eyes_25'), '26': over(s0, 'claudia_eyes_26'),
     '27': L('surface27'), '28a(1010)': L('surface1010'), '28b(1011)': L('surface1011'), '29': L('surface29'),
     'blink0(1001)': over(s0, 'surface1001'), 'blink7(1700)': over(s7, 'surface1700'), 'blink7(1701)': over(s7, 'surface1701')}
a10 = L('surface10')
A = {'10': a10, '11': over(a10, 'anthony_eyes11'), '19': L('surface19')}
zoom = int(sys.argv[1]) if len(sys.argv) > 1 else 2
bg = tuple(int(v) for v in (sys.argv[2].split(',') if len(sys.argv) > 2 else (255, 255, 255)))
cols = int(sys.argv[3]) if len(sys.argv) > 3 else 8
tiles = [(k, t.on_bg(v, bg, zoom)) for k, v in list(S.items()) + list(A.items())]
w = max(im.width for _, im in tiles)
h = max(im.height for _, im in tiles)
rows = (len(tiles) + cols - 1) // cols
W = Image.new('RGB', (cols * w, rows * (h + 14)), bg)
d = ImageDraw.Draw(W)
for i, (k, im) in enumerate(tiles):
    x, y = (i % cols) * w, (i // cols) * (h + 14)
    W.paste(im, (x, y + 14))
    d.text((x + 3, y + 1), k, fill=(255, 0, 0))
out = sys.argv[4] if len(sys.argv) > 4 else HERE + '/review.png'
W.save(out)
print(W.size, out)
