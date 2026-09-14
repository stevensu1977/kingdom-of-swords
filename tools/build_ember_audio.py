"""Original deterministic ambient music: modal bowed tones, bells, and wind."""
import os
import wave
import numpy as np

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rate, seconds = 24000, 48
t = np.arange(rate * seconds) / rate
rng = np.random.default_rng(44)
audio = np.zeros_like(t)
for freq, amount in [(73.416, .09), (110, .025), (146.832, .035), (220, .018)]:
    audio += np.sin(2 * np.pi * freq * t + .16 * np.sin(t * .25)) * amount * (.7 + .3 * np.sin(t * .19) ** 2)
for i, freq in enumerate([293.665, 440, 349.228, 261.626, 293.665, 220, 349.228, 440]):
    start = i * 6 + .3
    dt = np.maximum(t - start, 0)
    envelope = (t >= start) * (1 - np.exp(-dt * 3)) * np.exp(-dt * .60)
    audio += (.11 * np.sin(2 * np.pi * freq * dt) + .025 * np.sin(2 * np.pi * freq * 2.002 * dt)) * envelope
noise = np.convolve(rng.standard_normal(len(t)), np.ones(70) / 70, mode="same")
audio += noise * .09
audio *= np.minimum(t / 2, 1) * np.minimum((seconds - t) / 2, 1)
with wave.open(os.path.join(root, "tools/ember_ambience.wav"), "wb") as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(rate)
    f.writeframes((np.clip(audio, -1, 1) * 32767).astype("<i2").tobytes())
