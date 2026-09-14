"""Rebuild original sword and evade cues using deterministic synthesis."""
from pathlib import Path
import wave
import numpy as np

OUT = Path(__file__).resolve().parents[1] / "assets/audio"
RATE = 24000


def write(name, duration, kind, seed):
    rng = np.random.default_rng(seed)
    t = np.arange(round(duration * RATE)) / RATE
    noise = rng.standard_normal(len(t))
    if kind == "swing":
        noise = np.convolve(noise, np.ones(8) / 8, mode="same")
        signal = noise * np.sin(np.pi * t / duration) ** 2
        signal += 0.12 * np.sin(2 * np.pi * (180 * t - 100 * t * t)) * np.exp(-t * 10)
    elif kind == "impact":
        signal = (noise * 0.3 + np.sin(2 * np.pi * 880 * t) * 0.2
                  + np.sin(2 * np.pi * 1327 * t) * 0.12) * np.exp(-t * 28)
    else:
        smooth = np.convolve(noise, np.ones(18) / 18, mode="same")
        signal = smooth * np.sin(np.pi * t / duration) ** 1.5
    signal *= np.minimum(t * 900, 1) * np.minimum((duration - t) * 100, 1)
    signal *= 0.48 / max(1.0, np.max(np.abs(signal)))
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes((signal * 32767).astype("<i2").tobytes())


if __name__ == "__main__":
    write("sword_swing", 0.28, "swing", 410)
    write("sword_impact", 0.22, "impact", 411)
    write("dodge", 0.24, "dodge", 412)
