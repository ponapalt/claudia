"""Helpers for building the small (chibi) shell from the generated 1024x1536 sources.

All sources of one character share the same framing as the base image (claudia_0.png /
anthony_10.png), so one transform (scale + anchor) is used for every surface of that character.
Run build.py to make shell/small/*.png.
"""
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

HERE = __file__.replace('\\', '/').rsplit('/', 1)[0]
SRC = HERE + '/src'

ALPHA_CUT = 16      # alpha below this is the generator's faint halo; made fully transparent
KEEP_ISLAND = 3000  # islands (touching groups of pixels) smaller than this are dropped (full size)


def load(path):
    return np.array(Image.open(path).convert('RGBA'))


def clean(arr):
    """Zero the faint halo and drop small stray islands. Returns (array, dropped islands)."""
    a = arr.copy()
    a[a[..., 3] < ALPHA_CUT] = 0
    lab, n = ndi.label(a[..., 3] > 0)
    dropped = []
    if n:
        sizes = ndi.sum(a[..., 3] > 0, lab, range(1, n + 1))
        for i, s in enumerate(sizes, 1):
            if s < KEEP_ISLAND:
                ys, xs = np.where(lab == i)
                dropped.append((int(xs.min()), int(ys.min()), int(s)))
                a[lab == i] = 0
    return a, dropped


def anchor(arr, shoe_rows=60):
    """(center x of the shoes, bottom y) of the visible figure."""
    ys, xs = np.where(arr[..., 3] > 0)
    y1 = ys.max()
    sel = ys > y1 - shoe_rows
    return (xs[sel].min() + xs[sel].max()) / 2.0, int(y1)


def shift(arr, dx, dy):
    out = np.zeros_like(arr)
    h, w = arr.shape[:2]
    xs0, xs1 = max(0, dx), min(w, w + dx)
    ys0, ys1 = max(0, dy), min(h, h + dy)
    out[ys0:ys1, xs0:xs1] = arr[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
    return out


def align(arr, ref_anchor):
    ax, ay = anchor(arr)
    dx, dy = int(round(ref_anchor[0] - ax)), int(ref_anchor[1] - ay)
    return shift(arr, dx, dy), (dx, dy)


def resize_premul(arr, size, resample=Image.Resampling.LANCZOS):
    f = arr.astype(np.float32) / 255.0
    f[..., :3] *= f[..., 3:4]
    chans = []
    for c in range(4):
        chans.append(np.array(Image.fromarray(f[..., c], mode='F').resize(size, resample)))
    o = np.stack(chans, -1)
    o = np.clip(o, 0, 1)
    al = o[..., 3:4]
    rgb = np.where(al > 1e-6, o[..., :3] / np.maximum(al, 1e-6), 0)
    out = np.concatenate([np.clip(rgb, 0, 1), al], -1)
    return np.round(out * 255).astype(np.uint8)


def to_cell(arr, scale_w, canvas, offset, resample=Image.Resampling.LANCZOS):
    """Scale the whole source frame (1024x1536) to scale_w wide and paste it on a canvas (w,h) at offset."""
    h, w = arr.shape[:2]
    size = (scale_w, int(round(h * scale_w / w)))
    small = resize_premul(arr, size, resample)
    out = np.zeros((canvas[1], canvas[0], 4), np.uint8)
    ox, oy = offset
    ys0, xs0 = max(0, oy), max(0, ox)
    ys1, xs1 = min(canvas[1], oy + size[1]), min(canvas[0], ox + size[0])
    out[ys0:ys1, xs0:xs1] = small[ys0 - oy:ys1 - oy, xs0 - ox:xs1 - ox]
    return out


def save(arr, path):
    Image.fromarray(arr, 'RGBA').save(path)


def on_bg(arr, color=(255, 255, 255), zoom=1):
    im = Image.fromarray(arr, 'RGBA')
    bg = Image.new('RGBA', im.size, color + (255,))
    bg.alpha_composite(im)
    bg = bg.convert('RGB')
    if zoom != 1:
        bg = bg.resize((bg.width * zoom, bg.height * zoom), Image.Resampling.NEAREST)
    return bg


# ---- face compositing -------------------------------------------------------------------
FACE_RECT = (336, 432, 712, 618)   # eyes + mouth + cheeks (full face expressions)
EYE_RECT = (336, 432, 712, 580)    # eyes and brows only (blink parts)


def match_tone(base, edit, rect, ring=28):
    """Shift the colours of `edit` so that a ring just outside `rect` matches `base` (the generator
    re-renders the whole picture with slightly different skin and hair tones; this hides the seam)."""
    x0, y0, x1, y1 = rect
    h, w = base.shape[:2]
    m = np.zeros((h, w), bool)
    m[max(0, y0 - ring):min(h, y1 + ring), max(0, x0 - ring):min(w, x1 + ring)] = True
    m[y0:y1, x0:x1] = False
    m &= (base[..., 3] == 255) & (edit[..., 3] == 255)
    if m.sum() < 100:
        return edit
    off = (base[m][:, :3].astype(float) - edit[m][:, :3].astype(float)).mean(0)
    out = edit.copy()
    out[..., :3] = np.clip(edit[..., :3].astype(float) + off, 0, 255).astype(np.uint8)
    return out


def comp(base, edit, rect, feather=8, match=True):
    """Paste the rect of `edit` onto `base` with a soft edge."""
    from PIL import ImageFilter
    if match:
        edit = match_tone(base, edit, rect)
    x0, y0, x1, y1 = rect
    m = np.zeros(base.shape[:2], np.float32)
    m[y0:y1, x0:x1] = 1
    m = np.array(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(feather / 2)), np.float32) / 255
    out = base.astype(np.float32) * (1 - m[..., None]) + edit.astype(np.float32) * m[..., None]
    return np.round(out).astype(np.uint8)


def cell_params(base, scale_w=148, canvas=(192, 208), foot=(96, 204)):
    ax, ay = anchor(base)
    return scale_w, canvas, (round(foot[0] - ax * scale_w / 1024), round(foot[1] - (ay + 1) * scale_w / 1024))
