"""Procedural fight SFX. Run: python3 tools/gen_sfx.py  -> assets/audio/*.wav"""
import math
import os
import random
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
random.seed(7)


def write(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    gain = 0.89 / peak
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * gain)) * 32767)) for s in samples))
    print("wrote", path)


def n(sec):
    return int(sec * RATE)


def lowpass(xs, a):
    y = 0.0
    out = []
    for x in xs:
        y += a * (x - y)
        out.append(y)
    return out


def noise(sec):
    return [random.uniform(-1, 1) for _ in range(n(sec))]


def env_exp(i, total, k):
    return math.exp(-k * i / total)


def sweep(f0, f1, sec, k=6.0):
    out = []
    ph = 0.0
    total = n(sec)
    for i in range(total):
        t = i / total
        f = f0 * (f1 / f0) ** t
        ph += 2 * math.pi * f / RATE
        out.append(math.sin(ph) * env_exp(i, total, k))
    return out


def mix(*tracks):
    length = max(len(t) for t, _ in tracks)
    out = [0.0] * length
    for t, g in tracks:
        for i, s in enumerate(t):
            out[i] += s * g
    return out


def shaped_noise(sec, a, k):
    xs = lowpass(noise(sec), a)
    total = len(xs)
    return [x * env_exp(i, total, k) for i, x in enumerate(xs)]


def soft_clip(xs, drive):
    return [math.tanh(x * drive) for x in xs]


def hit_light():
    body = sweep(180, 70, 0.11, 9)
    crack = shaped_noise(0.04, 0.6, 14)
    return soft_clip(mix((body, 1.0), (crack, 0.8)), 2.2)


def hit_heavy():
    body = sweep(130, 38, 0.32, 6)
    crack = shaped_noise(0.07, 0.5, 10)
    thud = shaped_noise(0.25, 0.05, 7)
    return soft_clip(mix((body, 1.0), (crack, 0.9), (thud, 1.6)), 2.8)


def whoosh(sec=0.2):
    raw = noise(sec)
    out = []
    y = 0.0
    total = len(raw)
    for i, x in enumerate(raw):
        t = i / total
        a = 0.02 + 0.25 * math.sin(math.pi * t)
        y += a * (x - y)
        out.append(y * math.sin(math.pi * t) ** 1.5)
    return out


def block():
    tock = sweep(720, 420, 0.07, 12)
    click = shaped_noise(0.02, 0.8, 20)
    thud = sweep(160, 90, 0.09, 10)
    return mix((tock, 0.7), (click, 0.5), (thud, 0.8))


def clash():
    total = n(0.45)
    out = []
    for i in range(total):
        t = i / RATE
        e = env_exp(i, total, 7)
        s = sum(math.sin(2 * math.pi * f * t) / (k + 1) for k, f in enumerate((820, 1234, 1876, 2690)))
        out.append(s * e)
    return mix((out, 0.8), (shaped_noise(0.05, 0.7, 12), 0.7), (sweep(140, 60, 0.15, 8), 0.8))


def teleport():
    total = n(0.16)
    out = []
    ph = 0.0
    for i in range(total):
        t = i / total
        f = 300 * (6.0 ** t)
        ph += 2 * math.pi * f / RATE
        trem = 0.6 + 0.4 * math.sin(2 * math.pi * 45 * i / RATE)
        out.append(math.sin(ph) * trem * math.sin(math.pi * t))
    return mix((out, 0.6), (whoosh(0.16), 0.9))


def blast():
    rumble = shaped_noise(0.55, 0.04, 4)
    tone = sweep(260, 70, 0.5, 4)
    fizz = shaped_noise(0.3, 0.35, 6)
    return soft_clip(mix((rumble, 1.8), (tone, 0.7), (fizz, 0.5)), 2.0)


def charge_loop():
    total = n(1.0)
    out = []
    hiss = lowpass(noise(1.0), 0.08)
    for i in range(total):
        t = i / RATE
        vib = 1.0 + 0.004 * math.sin(2 * math.pi * 5 * t)
        s = math.sin(2 * math.pi * 90 * vib * t) + 0.5 * math.sin(2 * math.pi * 180 * t) + 0.25 * math.sin(2 * math.pi * 270 * t)
        out.append(s * 0.5 + hiss[i] * 1.2)
    fade = n(0.02)
    for i in range(fade):
        g = i / fade
        out[i] *= g
        out[-1 - i] *= g
    return out


def kiai():
    """Short vocal-ish shout: formant-ish saw burst."""
    total = n(0.22)
    out = []
    ph = 0.0
    for i in range(total):
        t = i / total
        f = 210 * (1.0 - 0.25 * t)
        ph += f / RATE
        saw = 2 * (ph % 1.0) - 1
        out.append(saw * math.sin(math.pi * min(1.0, t * 3)) * (1 - t))
    return lowpass(lowpass(out, 0.18), 0.3)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write("hit_light", hit_light())
    write("hit_heavy", hit_heavy())
    write("whoosh", whoosh())
    write("whoosh_big", whoosh(0.32))
    write("block", block())
    write("clash", clash())
    write("teleport", teleport())
    write("blast", blast())
    write("charge_loop", charge_loop())
    write("kiai", kiai())
