"""Builds shell/small/*.png from the generated sources in work/surfaces_small/src.

  python work/surfaces_small/build.py                  (from the ghost root; needs Pillow, numpy, scipy)
  python work/surfaces_small/build.py --import-picks   (copy the PICKS out of draft/ into src/ first)

src/ holds only the picked images (draft/ is every candidate, ~140 MB, and is not committed).
The face edits are stored as crops around the face (CROPS) and pasted back onto their base at build time.

Every character has one transform, fixed by its base image (claudia_0.png / anthony_10.png):
  Claudia  scale 148/1024 (the figure is 200 px tall), canvas 192x208, feet at y=204, centre x=96
  Anthony  scale 104/1024 (the figure is 120 px tall), canvas 112x128, feet at y=124, centre x=56
PICKS maps each source in src/ to the candidate it came from (draft/<prefix>-<date>-<n>.png).
Expressions that only change the face are made as parts: the face rectangle of the edited image
is pasted onto the base image, and the rectangle is cut out of the scaled result.
"""
import glob
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__)).replace('\\', '/')
sys.path.insert(0, HERE)
import tools as t  # noqa: E402

ROOT = HERE.rsplit('/work/', 1)[0]
OUT = ROOT + '/shell/small'
DRAFT = HERE + '/draft'
SRC = HERE + '/src'

CL = dict(scale=148, canvas=(192, 208), foot=(96, 204))
AN = dict(scale=104, canvas=(112, 128), foot=(56, 124))

# picked candidates: key -> (prefix, number)
PICKS = {
    'e01': ('e01', 1), 'e03': ('e03b', 1), 'e06': ('e06', 2), 'e07': ('e07', 1), 'e09': ('e09', 2),
    'e25': ('e25', 1), 'e26': ('e26c', 2), 'e1001': ('e1001c', 3), 'e1700': ('e1700c', 2), 'e1701': ('e1701c', 2),
    'p02': ('p02', 1), 'p04': ('p04', 1), 'p05': ('p05', 1), 'p08': ('p08', 1), 'p27': ('p27', 1),
    'p29': ('p29', 1), 'p1010': ('p1010c', 2), 'p1011': ('p1011b', 2),
    'a11': ('a11', 1), 'a19': ('a19', 1),
}


# face edits are stored as crops (x0, y0, x1, y1 of the 1024x1536 frame): the compositing rectangle
# (t.FACE_RECT / t.EYE_RECT / Anthony's) plus a margin for t.match_tone
CROPS = {k: (290, 396, 760, 650) for k in ('e01', 'e03', 'e06', 'e09', 'e25', 'e26',
                                           'e1001', 'e1700', 'e1701')}
CROPS['a11'] = (330, 380, 720, 590)


def import_picks():
    import shutil
    os.makedirs(SRC, exist_ok=True)
    for key, (prefix, n) in PICKS.items():
        fs = sorted(glob.glob(f'{DRAFT}/{prefix}-*-{n}.png'))
        if not fs:
            raise SystemExit('missing draft for ' + key)
        if key in CROPS:
            a, _ = t.clean(t.load(fs[-1]))
            x0, y0, x1, y1 = CROPS[key]
            t.save(a[y0:y1, x0:x1].copy(), f'{SRC}/{key}.png')
        else:
            shutil.copyfile(fs[-1], f'{SRC}/{key}.png')
        print('imported', key, '<-', os.path.basename(fs[-1]))


def read(key, base=None):
    """A picked source as a full 1024x1536 array; crops are pasted onto `base`."""
    a = t.load(f'{SRC}/{key}.png')
    if key not in CROPS:
        return a
    x0, y0, x1, y1 = CROPS[key]
    out = base.copy()
    out[y0:y1, x0:x1] = a
    return out


class Char:
    def __init__(self, cfg, base_path):
        self.cfg = cfg
        self.base, _ = t.clean(t.load(base_path))
        self.anchor = t.anchor(self.base, 40 if cfg is AN else 60)
        s = cfg['scale']
        self.off = (round(cfg['foot'][0] - self.anchor[0] * s / 1024),
                    round(cfg['foot'][1] - (self.anchor[1] + 1) * s / 1024))
        ys, xs = np.where(self.base[..., 3] > 0)
        self.top = ys.min()

    def cell(self, arr, dy_src=0):
        a = t.shift(arr, 0, dy_src) if dy_src else arr
        return finish(t.to_cell(a, self.cfg['scale'], self.cfg['canvas'], self.off))

    def place(self, arr, mode='feet', min_top=1.0):
        """Align a full pose image to the base: by the feet, or by the head top (floating poses).
        The figure is lowered if the top would be cut off (less than min_top px from the top edge)."""
        arr, _ = t.clean(arr)
        s = self.cfg['scale'] / 1024
        ax, ay = t.anchor(arr, 40 if self.cfg is AN else 60)
        ys, _xs = np.where(arr[..., 3] > 0)
        dx = int(round(self.anchor[0] - ax))
        if mode == 'feet':
            dy = int(self.anchor[1] - ay)
        else:  # head top
            dy = int(self.top - ys.min())
        # top margin in the cell after the shift
        top_px = (ys.min() + dy) * s + self.off[1]
        if top_px < min_top:
            dy += int(np.ceil((min_top - top_px) / s))
        return t.shift(arr, dx, dy), (dx, dy)


def finish(cell):
    """Alpha of 8 or less is dropped by SSP and 9-15 is the faint tail of the scaling; make both plain
    transparent (the same cut as t.ALPHA_CUT for the sources), keep the colours of the rest."""
    c = cell.copy()
    c[c[..., 3] < t.ALPHA_CUT] = 0
    # the generator leaves the inside of the figures at alpha 252-253; make it 255 (same as work/surfaces/fix-alpha.ps1)
    c[..., 3] = np.where(c[..., 3] >= 240, 255, c[..., 3])
    return c


def part(cell_base, cell_new, rect_src, char):
    """Cut the rect (source coordinates) out of cell_new; returns (array, x, y) with 2 px of margin."""
    s = char.cfg['scale'] / 1024
    x0 = int(np.floor(rect_src[0] * s + char.off[0])) - 2
    y0 = int(np.floor(rect_src[1] * s + char.off[1])) - 2
    x1 = int(np.ceil(rect_src[2] * s + char.off[0])) + 2
    y1 = int(np.ceil(rect_src[3] * s + char.off[1])) + 2
    return cell_new[y0:y1, x0:x1].copy(), x0, y0


def main():
    os.makedirs(OUT, exist_ok=True)
    info = {}
    cl = Char(CL, SRC + '/claudia_0.png')
    c0 = cl.cell(cl.base)
    t.save(c0, f'{OUT}/surface0.png')

    # ---- face parts of Claudia ---------------------------------------------------------
    def face(key, rect, base=None, name=None):
        b = cl.base if base is None else base
        e = read(key, b)
        comp = t.comp(b, e, rect, 12)
        p, x, y = part(None, cl.cell(comp), rect, cl)
        t.save(p, f'{OUT}/{name}.png')
        info[name] = (x, y, p.shape[1], p.shape[0])
        return comp

    for key, name in (('e01', 'claudia_eyes_1'), ('e03', 'claudia_eyes_3'),
                      ('e09', 'claudia_eyes_9'), ('e25', 'claudia_eyes_25'), ('e26', 'claudia_eyes_26')):
        face(key, t.FACE_RECT, name=name)
    face('e06', t.EYE_RECT, name='surface1000')
    face('e1001', t.EYE_RECT, name='surface1001')
    # 7 is a full pose (the generator redraws the chin and the cheek hair, so a pasted face leaves seams);
    # its blink parts are cut against the 7 image, shifted by the same amount
    a7, shift7 = cl.place(read('e07'), 'feet')
    c7 = cl.cell(a7)
    t.save(c7, f'{OUT}/surface7.png')
    ys, xs = np.nonzero(c7[..., 3] > 8)
    info['surface7'] = (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max()))
    print('surface7 shift', shift7, 'bbox', info['surface7'])
    for key, name in (('e1700', 'surface1700'), ('e1701', 'surface1701')):
        e, _ = t.clean(read(key, read('e07')))
        e = t.shift(e, *shift7)
        comp = t.comp(a7, e, t.EYE_RECT, 12)
        p, x, y = part(None, cl.cell(comp), t.EYE_RECT, cl)
        t.save(p, f'{OUT}/{name}.png')
        info[name] = (x, y, p.shape[1], p.shape[0])

    # ---- full poses of Claudia ---------------------------------------------------------
    for key, name, mode in (('p02', 'surface2', 'feet'), ('p04', 'surface4', 'feet'), ('p05', 'surface5', 'feet'),
                            ('p08', 'surface8', 'feet'), ('p27', 'surface27', 'feet'), ('p29', 'surface29', 'head'),
                            ('p1010', 'surface1010', 'feet'), ('p1011', 'surface1011', 'feet')):
        a, shift_ = cl.place(read(key), mode)
        c = cl.cell(a)
        t.save(c, f'{OUT}/{name}.png')
        ys, xs = np.nonzero(c[..., 3] > 8)
        info[name] = (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max()))
        print(name, 'shift', shift_, 'bbox', info[name])

    # ---- Anthony -----------------------------------------------------------------------
    an = Char(AN, SRC + '/anthony_10.png')
    t.save(an.cell(an.base), f'{OUT}/surface10.png')
    e = read('a11', an.base)
    arect = (360, 405, 690, 565)
    comp = t.comp(an.base, e, arect, 8)
    p, x, y = part(None, an.cell(comp), arect, an)
    t.save(p, f'{OUT}/anthony_eyes11.png')
    info['anthony_eyes11'] = (x, y, p.shape[1], p.shape[0])
    a, shift_ = an.place(read('a19'), 'head')
    c = an.cell(a)
    t.save(c, f'{OUT}/surface19.png')
    ys, xs = np.nonzero(c[..., 3] > 8)
    info['surface19'] = (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max()))
    ys, xs = np.nonzero(an.cell(an.base)[..., 3] > 8)
    info['surface10'] = (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max()))
    info['surface0'] = tuple(int(v) for v in (lambda yx: (yx[1].min(), yx[0].min(), yx[1].max(), yx[0].max()))(np.nonzero(c0[..., 3] > 8)))

    with open(HERE + '/build-info.json', 'w') as f:
        json.dump(info, f, indent=1)
    for k, v in info.items():
        print(k, v)


if __name__ == '__main__':
    if '--import-picks' in sys.argv:
        import_picks()
    main()
