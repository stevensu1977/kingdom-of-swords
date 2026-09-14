"""Original holy-skill chimes for Consecration and Divine Shield; no paid inputs."""
from pathlib import Path
import wave
import numpy as np

OUT = Path(__file__).resolve().parents[1] / "assets/audio"
RATE = 24000


def chime(name, length, notes, volume):
    time = np.arange(int(RATE * length)) / RATE
    signal = np.zeros_like(time)
    for index, frequency in enumerate(notes):
        envelope = (1 - np.exp(-time * 180)) * np.exp(-time * (5 + index * 1.5))
        signal += np.sin(2 * np.pi * frequency * time) * envelope / (index + 1)
    signal *= np.minimum(1, (length - time) / .04)
    signal *= volume / max(1, np.max(np.abs(signal)))
    with wave.open(str(OUT / (name + ".wav")), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes((signal * 32767).astype("<i2").tobytes())


chime("consecration", .85, [293.665, 440.0, 587.33, 880.0], .36)
chime("consecration_tick", .24, [587.33, 880.0, 1174.66], .16)
chime("divine_shield", .70, [440.0, 659.255, 880.0, 1318.51], .38)
chime("divine_shield_block", .18, [1318.51, 1760.0, 2217.46], .16)
