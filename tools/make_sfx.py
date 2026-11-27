"""Generate the game's placeholder sound effects and ambient music as WAV files.

Everything is synthesized (sine/triangle tones, filtered noise), so there are
no licensing questions. Replace any file in sfx/ with a real recording later;
the game picks it up by name.

Usage: python3 tools/make_sfx.py   (writes into sfx/)
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "sfx")
random.seed(7)


def tone(freq, dur, vol=0.5, shape="sine", attack=0.005, decay=None, slide=0.0):
    n = int(RATE * dur)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / RATE
        f = freq + slide * t / dur
        ph += 2 * math.pi * f / RATE
        if shape == "sine":
            s = math.sin(ph)
        elif shape == "tri":
            s = 2 / math.pi * math.asin(math.sin(ph))
        else:  # soft square
            s = math.tanh(3 * math.sin(ph))
        env = min(1.0, t / attack) if attack > 0 else 1.0
        if decay:
            env *= math.exp(-t / decay)
        else:
            env *= max(0.0, 1 - t / dur)
        out.append(s * env * vol)
    return out


def noise(dur, vol=0.4, decay=0.05, lowpass=0.2):
    out, prev = [], 0.0
    for i in range(int(RATE * dur)):
        prev += lowpass * (random.uniform(-1, 1) - prev)
        out.append(prev * vol * math.exp(-(i / RATE) / decay))
    return out


def mix(*parts, offsets=None):
    offsets = offsets or [0.0] * len(parts)
    n = max(int(o * RATE) + len(p) for p, o in zip(parts, offsets))
    out = [0.0] * n
    for p, o in zip(parts, offsets):
        k = int(o * RATE)
        for i, s in enumerate(p):
            out[k + i] += s
    return out


def save(name, samples):
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in samples))


def music():
    # Slow noir loop: Am7 - Dm7 - E7 - Am7, soft electric-piano chords over a walking bass and brushed noise.
    bpm, beats = 72, 32
    beat = 60 / bpm
    total = beat * beats
    n = int(RATE * total)
    out = [0.0] * n
    chords = [[57, 60, 64, 67], [50, 53, 57, 60], [52, 56, 59, 62], [57, 60, 64, 67]]
    bass = [45, 48, 52, 50, 38, 41, 45, 48, 40, 44, 47, 46, 45, 43, 40, 44]

    def midi(m):
        return 440 * 2 ** ((m - 69) / 12)

    def add(samples, at):
        k = int(at * RATE)
        for i, s in enumerate(samples):
            if k + i < n:
                out[k + i] += s

    for bar, ch in enumerate(chords * 2):
        t0 = bar * 4 * beat
        for j, m in enumerate(ch):
            add(tone(midi(m), beat * 3.5, 0.05, "sine", attack=0.02 + j * 0.01, decay=1.4), t0 + j * 0.02)
            add(tone(midi(m) * 2, beat * 2, 0.012, "sine", decay=0.5), t0 + j * 0.02)
    for i in range(beats):
        m = bass[i % len(bass)]
        add(tone(midi(m), beat * 0.9, 0.16, "tri", attack=0.01, decay=0.35), i * beat)
        add(noise(0.25, 0.05, 0.08, 0.6), i * beat + beat / 2)
    # a lonely melody every other bar
    melody = [(4, 76, 1.5), (6, 74, 0.5), (7, 72, 1), (12, 71, 2), (20, 76, 1.5), (22, 79, 0.5), (23, 77, 1), (28, 76, 3)]
    for b, m, d in melody:
        add(tone(midi(m), beat * d + 0.4, 0.06, "tri", attack=0.03, decay=0.6), b * beat)
    return out


def main():
    save("blip", tone(880, 0.03, 0.25, "square", decay=0.012))
    save("click", mix(tone(1200, 0.02, 0.3, decay=0.006), noise(0.02, 0.3, 0.004, 0.8)))
    save("pickup", mix(tone(784, 0.09, 0.35, "tri", decay=0.06), tone(1175, 0.25, 0.35, "tri", decay=0.12), offsets=[0, 0.07]))
    save("door", mix(noise(0.35, 0.6, 0.12, 0.05), tone(90, 0.3, 0.4, decay=0.08), tone(140, 0.1, 0.3, decay=0.03), offsets=[0, 0, 0.22]))
    save("deduce", mix(tone(523, 0.12, 0.3, "tri", decay=0.1), tone(659, 0.12, 0.3, "tri", decay=0.1),
                       tone(784, 0.4, 0.3, "tri", decay=0.2), offsets=[0, 0.09, 0.18]))
    save("wrong", mix(tone(220, 0.18, 0.35, "square", decay=0.1, slide=-30), tone(165, 0.3, 0.35, "square", decay=0.15, slide=-30), offsets=[0, 0.15]))
    save("solve", mix(*[tone(f, 0.9 - i * 0.1, 0.22, "tri", decay=0.4) for i, f in enumerate([392, 494, 587, 784])],
                      offsets=[0, 0.12, 0.24, 0.36]))
    save("eye", mix(tone(400, 0.5, 0.25, "sine", attack=0.05, decay=0.3, slide=800), noise(0.4, 0.15, 0.2, 0.9)))
    save("music", music())


if __name__ == "__main__":
    main()
