# Notification sounds for the tea timer and pomodoro (yaya_teatimer.dic).
# Usage (from the repository root): python work/sounds/make_timer_sounds.py ghost/master
# Writes tm_tea.wav, tm_timer.wav, tm_break.wav, tm_work.wav and tm_set.wav.

import math, struct, sys, wave, os

# Same method as cc_bell / cc_done: additive synthesis, 44.1 kHz mono 16-bit.
RATE = 44100

def note(name):
    # 'C5' -> Hz (A4 = 440)
    names = {'C': -9, 'D': -7, 'E': -5, 'F': -4, 'G': -2, 'A': 0, 'B': 2}
    semi = names[name[0]]
    rest = name[1:]
    if rest.startswith('#'):
        semi += 1
        rest = rest[1:]
    return 440.0 * 2 ** ((semi + (int(rest) - 4) * 12) / 12)

def render(path, events, total, level, attack_s=0.004):
    # events: (start seconds, frequency, gain, partials [(ratio, amp, decay)])
    n = int(RATE * total)
    buf = [0.0] * n
    for start, f0, gain, partials in events:
        s0 = int(RATE * start)
        for i in range(s0, n):
            t = (i - s0) / RATE
            env = min(1.0, t / attack_s)
            s = 0.0
            for r, a, d in partials:
                s += a * math.exp(-t / d) * math.sin(2 * math.pi * f0 * r * t)
            buf[i] += gain * env * s
    fade = int(RATE * 0.4)
    for i in range(n - fade, n):
        buf[i] *= (n - i) / fade
    peak = max(abs(x) for x in buf)
    scale = level * 32767 / peak
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(x * scale)) for x in buf))

# Porcelain teacup struck with a spoon: bright, inharmonic, short.
CUP = [(1.000, 1.00, 0.45), (2.320, 0.45, 0.25), (4.250, 0.25, 0.12), (6.800, 0.10, 0.06)]
# Soft chime (like cc_done): mostly the fundamental.
CHIME = [(1.0, 1.00, 0.80), (2.0, 0.12, 0.30), (3.0, 0.04, 0.15)]
# Clearer bell for "back to work": a little more upper colour than CHIME.
CLEAR = [(1.0, 1.00, 0.70), (2.0, 0.30, 0.35), (3.0, 0.10, 0.18), (4.0, 0.05, 0.10)]
# Desk bell (reception bell) for the plain timer.
DESK = [(1.000, 1.00, 0.90), (2.710, 0.50, 0.50), (5.120, 0.25, 0.25), (8.300, 0.10, 0.12)]

out = sys.argv[1]

# Tea is ready: two light clinks on a cup, the second a little softer.
render(os.path.join(out, 'tm_tea.wav'),
       [(0.00, 1760.0, 1.0, CUP), (0.16, 1760.0, 0.7, CUP)],
       1.6, 0.45, 0.002)

# Plain timer: desk bell, twice.
render(os.path.join(out, 'tm_timer.wav'),
       [(0.00, 1318.5, 1.0, DESK), (0.35, 1318.5, 0.9, DESK)],
       2.6, 0.55, 0.002)

# Focus is over, take a break: gentle descending G5-E5-C5.
render(os.path.join(out, 'tm_break.wav'),
       [(0.00, note('G5'), 1.0, CHIME), (0.22, note('E5'), 0.9, CHIME), (0.44, note('C5'), 0.9, CHIME)],
       2.8, 0.40, 0.012)

# Break is over, back to work: brisk ascending C5-E5-G5.
render(os.path.join(out, 'tm_work.wav'),
       [(0.00, note('C5'), 0.9, CLEAR), (0.14, note('E5'), 0.9, CLEAR), (0.28, note('G5'), 1.0, CLEAR)],
       2.4, 0.45, 0.006)

# A full set of pomodoros is done: C5-E5-G5 then a held C6 on top.
render(os.path.join(out, 'tm_set.wav'),
       [(0.00, note('C5'), 0.8, CLEAR), (0.13, note('E5'), 0.8, CLEAR), (0.26, note('G5'), 0.8, CLEAR),
        (0.42, note('C6'), 1.0, CHIME), (0.42, note('G5'), 0.4, CHIME), (0.42, note('E5'), 0.4, CHIME)],
       3.2, 0.50, 0.006)
