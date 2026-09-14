"""Original bow draw, release, and arrow impact cues from deterministic synthesis."""
from pathlib import Path
import wave
import numpy as np

RATE = 24000
OUT = Path(__file__).resolve().parents[1] / "assets/audio"
rng = np.random.default_rng(20260914)


def write(name, signal):
    signal *= .55 / max(1, np.max(np.abs(signal)))
    with wave.open(str(OUT/(name+".wav")), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes((signal * 32767).astype("<i2").tobytes())


t = np.arange(int(RATE*.65))/RATE
noise = rng.normal(0, 1, len(t))
smooth = np.convolve(noise, np.ones(25)/25, mode="same")
write("bow_draw", (.32*np.sin(2*np.pi*(110*t+70*t*t)) + smooth*.45)
      * np.sin(np.pi*t/.65)**2 * .7)
t = np.arange(int(RATE*.28))/RATE
noise = rng.normal(0, 1, len(t))
write("bow_release", (np.sin(2*np.pi*(280*t-150*t*t))*.8 + noise*.2)
      * np.exp(-t*22) * np.minimum(t*900, 1))
t = np.arange(int(RATE*.19))/RATE
noise = rng.normal(0, 1, len(t))
write("arrow_impact", (noise*.45 + np.sin(2*np.pi*760*t)*.3)
      * np.exp(-t*38) * np.minimum(t*1200, 1))
