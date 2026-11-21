"""Gera os sons de batalha (sintetizados aqui, sem direitos de terceiros): tiros, rajada de
metralhadora e explosões. Saída em audio/sfx/*.ogg (precisa do ffmpeg).
Uso: python3 tools/audio/gen_sfx.py"""
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np
from scipy import signal

SR = 44100
OUT = Path(__file__).resolve().parents[2] / "audio" / "sfx"
rng = np.random.default_rng(1936)


def env(n, attack, decay):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-t / decay)


def lowpass(x, hz, order=2):
    b, a = signal.butter(order, hz / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def bandpass(x, lo, hi):
    b, a = signal.butter(2, [lo / (SR / 2), hi / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def reverb(x, amount=0.35, length=1.2):
    n = int(SR * length)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / SR / (length / 5))
    ir = lowpass(ir, 2500)
    wet = signal.fftconvolve(x, ir)
    wet = np.pad(wet, (0, max(0, len(x) + n - len(wet))))[: len(x) + n]
    wet /= np.max(np.abs(wet)) + 1e-9
    dry = np.concatenate([x, np.zeros(n)])
    return dry + wet * amount * np.max(np.abs(x))


def shot(distance=0.0):
    n = int(SR * 0.6)
    noise = rng.standard_normal(n)
    crack = bandpass(noise, 900, 7000) * env(n, 0.0005, 0.012)
    body = lowpass(noise, 1400) * env(n, 0.001, 0.09) * 0.8
    thump = np.sin(2 * np.pi * 95 * np.arange(n) / SR) * env(n, 0.001, 0.04) * 0.5
    x = crack * (1 - distance) + body + thump
    if distance > 0:
        x = lowpass(x, 2500 - 1800 * distance)
    return reverb(x, 0.3 + 0.4 * distance, 0.9)


def mg_burst(count, gap):
    one = shot(0.35)
    n = int(SR * (gap * count + 0.05)) + len(one)
    x = np.zeros(n)
    for i in range(count):
        s = max(0, int(SR * (i * gap + rng.uniform(-0.006, 0.006))))
        g = rng.uniform(0.75, 1.0)
        m = min(len(one), n - s)
        x[s:s + m] += one[:m] * g
    return x


def explosion(size=1.0):
    n = int(SR * 3.0)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    rumble = lowpass(noise, 160 + 120 * size, 3) * env(n, 0.004, 0.55 * size) * 3.0
    blast = lowpass(noise, 2200) * env(n, 0.001, 0.06) * 1.2
    f = 55 * np.exp(-t * 3) + 28
    boom = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, 0.003, 0.35 * size) * 1.6
    debris = bandpass(noise * (rng.random(n) < 0.004), 1500, 6000) * env(n, 0.05, 0.4) * 4
    return reverb(rumble + blast + boom + debris, 0.45, 1.8)


def save(name, x):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.9
    fade = int(SR * 0.05)
    x[-fade:] *= np.linspace(1, 0, fade)
    with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
        with wave.open(tmp.name, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((x * 32767).astype(np.int16).tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-c:a", "libvorbis", "-q:a", "4",
                        str(OUT / (name + ".ogg"))], check=True)


OUT.mkdir(parents=True, exist_ok=True)
for i in range(3):
    save("tiro_%d" % (i + 1), shot(rng.uniform(0.1, 0.5)))
save("rajada_1", mg_burst(9, 0.075))
save("rajada_2", mg_burst(14, 0.07))
for i, s in enumerate([0.8, 1.0, 1.3]):
    save("explosao_%d" % (i + 1), explosion(s))
print("ok", sorted(p.name for p in OUT.glob("*.ogg")))
