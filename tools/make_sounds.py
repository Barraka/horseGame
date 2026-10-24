"""Makes the game's sounds and music from scratch (no recordings), as Ogg
files in assets/audio. Run from the project folder:

    python3 tools/make_sounds.py

Needs numpy and ffmpeg (with libvorbis). Everything here is synthesised, so
the results are ours to use freely. Change a recipe and run it again to
remake the files; Godot re-imports them on its own.
"""

import os
import subprocess
import tempfile
import wave

import numpy as np

RATE = 32000
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(7)


# --- Building blocks ------------------------------------------------------------

def seconds(length):
    return np.arange(int(length * RATE)) / RATE


def noise(length):
    return rng.standard_normal(int(length * RATE))


def shape(signal, low=0.0, high=RATE / 2, tilt=0.0):
    """Keep the frequencies between low and high (soft edges), and tilt the
    rest: tilt -1 makes pink-ish noise, darker as it goes down."""
    spectrum = np.fft.rfft(signal)
    f = np.fft.rfftfreq(len(signal), 1 / RATE)
    gain = 1 / (1 + (low / np.maximum(f, 1)) ** 4) / (1 + (f / high) ** 4)
    gain *= np.maximum(f, 20) ** (tilt / 2)
    return np.fft.irfft(spectrum * gain, len(signal))


def envelope(length, attack, decay):
    t = seconds(length)
    return np.minimum(t / max(attack, 1e-4), 1) * np.exp(-np.maximum(t - attack, 0) / decay)


def sweep(f0, f1, length, curve=1.0):
    """A sine sliding from f0 to f1 Hz."""
    t = seconds(length)
    f = f0 + (f1 - f0) * (t / length) ** curve
    return np.sin(2 * np.pi * np.cumsum(f) / RATE)


def normalise(signal, peak=0.9):
    return signal * peak / max(np.max(np.abs(signal)), 1e-9)


def fade(signal, start=0.005, end=0.02):
    a = int(start * RATE)
    b = int(end * RATE)
    signal = signal.copy()
    if a:
        signal[:a] *= np.linspace(0, 1, a)
    if b:
        signal[-b:] *= np.linspace(1, 0, b)
    return signal


def loop_seam(signal, overlap=1.0):
    """Cross-fade the end into the start so the sound loops without a click."""
    n = int(overlap * RATE)
    head = signal[:n] * np.linspace(0, 1, n) + signal[-n:] * np.linspace(1, 0, n)
    return np.concatenate([head, signal[n:-n]])


def reverb(signal, length=1.8, wet=0.25, loop=False):
    impulse = noise(length) * np.exp(-seconds(length) * 4.0 / length)
    impulse = shape(impulse, 200, 6000)
    impulse /= np.sqrt(np.sum(impulse ** 2))
    n = len(signal) + len(impulse)
    tail = np.fft.irfft(np.fft.rfft(signal, n) * np.fft.rfft(impulse, n), n)
    out = np.concatenate([signal, np.zeros(len(impulse))]) * (1 - wet) + tail * wet
    if loop:
        # The tail wraps round to the start, so the loop rings on seamlessly.
        out[: len(impulse)] += out[len(signal):]
        out = out[: len(signal)]
    return out


def pluck(freq, length, brightness=0.5, decay=0.996):
    """A plucked string (Karplus-Strong), like a harp or guitar."""
    n = int(length * RATE)
    period = int(RATE / freq)
    out = np.zeros(n + period + 1)
    out[: period + 1] = shape(rng.uniform(-1, 1, period + 1), 0, 2000 + brightness * 8000)
    for start in range(period + 1, n + period + 1, period):
        end = min(start + period, n + period + 1)
        out[start:end] = decay * 0.5 * (out[start - period : end - period] + out[start - period - 1 : end - period - 1])
    return fade(out[period + 1 :], 0.002, 0.05)


def save(name, signal, loop=False):
    os.makedirs(OUT, exist_ok=True)
    pcm = (np.clip(signal, -1, 1) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        path = tmp.name
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    target = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", path, "-c:a", "libvorbis", "-q:a", "4", target], check=True)
    os.remove(path)
    print("made", target, "%.1f s" % (len(signal) / RATE), "(loops)" if loop else "")


# --- Hooves -----------------------------------------------------------------------

def hoof(surface, variant):
    pitch = 1 + (variant - 1) * 0.08
    if surface == "grass":
        thud = sweep(110 * pitch, 55 * pitch, 0.12) * envelope(0.12, 0.003, 0.035)
        brush = shape(noise(0.12), 300, 1800) * envelope(0.12, 0.002, 0.03) * 0.25
        return normalise(fade(thud + brush, 0.001, 0.02), 0.8)
    if surface == "dirt":
        # A firmer clop, like a coconut shell, with a little thud under it.
        clop = sweep(700 * pitch, 520 * pitch, 0.09) * envelope(0.09, 0.001, 0.018)
        thud = sweep(120 * pitch, 60 * pitch, 0.09) * envelope(0.09, 0.002, 0.03)
        grit = shape(noise(0.09), 1500, 6000) * envelope(0.09, 0.001, 0.01) * 0.2
        return normalise(fade(clop * 0.6 + thud + grit, 0.0005, 0.02), 0.8)
    if surface == "sand":
        shff = shape(noise(0.18), 400, 3500, -0.5) * envelope(0.18, 0.01, 0.05)
        thud = sweep(90 * pitch, 50 * pitch, 0.18) * envelope(0.18, 0.004, 0.03) * 0.6
        return normalise(fade(shff + thud, 0.002, 0.03), 0.7)
    if surface == "snow":
        # A soft crunch: lots of tiny crackles packed close together.
        length = 0.2
        crackle = np.zeros(len(seconds(length)))
        for k in range(28):
            start = int(rng.uniform(0.0, 0.13) * RATE)
            c = shape(noise(0.012), 1200, 7000) * envelope(0.012, 0.0005, 0.003)
            crackle[start : start + len(c)] += c * rng.uniform(0.3, 1.0)
        crackle *= envelope(length, 0.004, 0.06)
        thud = sweep(95 * pitch, 50 * pitch, length) * envelope(length, 0.004, 0.03) * 0.5
        return normalise(fade(crackle + thud, 0.002, 0.03), 0.65)
    # Water: a splash with a few bubbles.
    splash = shape(noise(0.35), 500, 5000) * envelope(0.35, 0.01, 0.09)
    bubbles = np.zeros_like(splash)
    for k in range(5):
        start = int(rng.uniform(0.02, 0.2) * RATE)
        b = sweep(rng.uniform(500, 900), rng.uniform(1200, 1800), 0.04) * envelope(0.04, 0.002, 0.012)
        bubbles[start : start + len(b)] += b * 0.3
    return normalise(fade(splash + bubbles, 0.002, 0.05), 0.75)


# --- The horse's voice --------------------------------------------------------------

def voice(f, length, formants, breath=0.15, partials=14):
    """A voiced sound following the pitch curve f (Hz per sample), shaped by
    formants [(centre, width, gain)] like a horse's nose and throat."""
    phase = 2 * np.pi * np.cumsum(f) / RATE
    out = np.zeros(len(f))
    for k in range(1, partials + 1):
        fk = f * k
        gain = sum(g * np.exp(-((fk - c) / w) ** 2) for c, w, g in formants) + 0.05 / k
        out += np.sin(k * phase) * gain * (fk < RATE / 2)
    out += shape(noise(length), 800, 5000) * breath
    return out


def whinny(variant):
    length = 1.5 + variant * 0.15
    t = seconds(length)
    # High at first, then falling in quavering steps.
    base = 820 + variant * 40
    f = base * (1 - 0.42 * (t / length) ** 0.8)
    f *= 1 + (0.03 + 0.07 * t / length) * np.sin(2 * np.pi * (11 + variant) * t)
    tremolo = 1 - 0.6 * np.clip(t / length - 0.35, 0, 1) * (0.5 + 0.5 * np.sin(2 * np.pi * 13 * t))
    amp = np.minimum(t / 0.06, 1) * np.exp(-np.maximum(t - length * 0.6, 0) / 0.25) * tremolo
    out = fade(voice(f, length, [(1100, 500, 1.0), (2400, 700, 0.6), (3500, 800, 0.25)], breath=0.08) * amp, 0.01, 0.15)
    # A breathy blow at the end.
    blow = shape(noise(0.35), 200, 1500) * envelope(0.35, 0.03, 0.1) * 0.5
    out = np.concatenate([out, np.zeros(int(0.1 * RATE))])
    out[-len(blow):] += blow
    return normalise(reverb(fade(out, 0.01, 0.1), 0.6, 0.12), 0.85)


def nicker():
    """A soft, low, pulsing "huh-huh-huh": a happy hello."""
    length = 0.8
    t = seconds(length)
    f = 120 * (1 - 0.15 * t / length)
    pulses = np.clip(np.sin(2 * np.pi * 9.5 * t), 0, 1) ** 0.7
    amp = envelope(length, 0.03, 0.4) * (0.35 + 0.65 * pulses)
    out = voice(f, length, [(300, 200, 1.0), (700, 300, 0.4)], breath=0.25, partials=10) * amp
    return normalise(shape(fade(out, 0.01, 0.08), 60, 2500), 0.8)


def snort():
    """A blow through the nose, with the lips fluttering."""
    length = 0.55
    t = seconds(length)
    flutter = 0.55 + 0.45 * np.sin(2 * np.pi * 28 * t)
    out = shape(noise(length), 150, 1800, -0.5) * envelope(length, 0.02, 0.14) * flutter
    return normalise(fade(out, 0.005, 0.05), 0.75)


# --- Outdoors -------------------------------------------------------------------------

def bird(kind):
    parts = []
    if kind == 0:   # A falling whistle, three times
        for k in range(3):
            parts.append(sweep(4200, 2600, 0.12, 0.6) * envelope(0.12, 0.01, 0.05))
            parts.append(np.zeros(int(0.06 * RATE)))
    elif kind == 1:   # A quick trill
        t = seconds(0.6)
        parts.append(np.sin(2 * np.pi * 3600 * t + 3 * np.sin(2 * np.pi * 40 * t)) * (0.5 + 0.5 * np.sin(2 * np.pi * 24 * t)) * envelope(0.6, 0.05, 0.25))
    elif kind == 2:   # "Tweet tweet", rising
        for k in range(2):
            parts.append(sweep(2400, 3900, 0.1, 2.0) * envelope(0.1, 0.01, 0.04))
            parts.append(np.zeros(int(0.09 * RATE)))
    elif kind == 3:   # A cheerful little song
        for f0, f1, d in [(3000, 3400, 0.08), (3400, 2800, 0.08), (3800, 4200, 0.06), (4200, 3000, 0.12), (2600, 3300, 0.1)]:
            parts.append(sweep(f0, f1, d) * envelope(d, 0.008, d * 0.5))
            parts.append(np.zeros(int(0.03 * RATE)))
    else:   # A cuckoo-like two notes, far off
        for f, d in [(780, 0.22), (640, 0.3)]:
            parts.append(np.sin(2 * np.pi * f * seconds(d)) * envelope(d, 0.02, d * 0.4))
            parts.append(np.zeros(int(0.12 * RATE)))
    out = np.concatenate([fade(p, 0.003, 0.02) if p.any() else p for p in parts])
    return normalise(reverb(fade(out, 0.003, 0.03), 0.8, 0.2), 0.6)


def gull(variant):
    """A seagull's "kee-ow", a bit raspy."""
    length = 0.45 + variant * 0.05
    t = seconds(length)
    f = 1700 - 700 * (t / length) ** 1.5 + variant * 80
    f *= 1 + 0.02 * np.sin(2 * np.pi * 60 * t)
    out = voice(f, length, [(2200, 900, 1.0), (3800, 900, 0.4)], breath=0.2, partials=6) * envelope(length, 0.04, 0.18)
    return normalise(reverb(fade(out, 0.005, 0.05), 0.7, 0.2), 0.6)


def rain():
    length = 10.0
    hiss = shape(noise(length), 300, 7000, -0.6) * 0.6
    drops = np.zeros(int(length * RATE))
    for k in range(900):
        start = int(rng.uniform(0, length - 0.05) * RATE)
        d = sweep(rng.uniform(2000, 5000), rng.uniform(1500, 3000), 0.012) * envelope(0.012, 0.0005, 0.003)
        drops[start : start + len(d)] += d * rng.uniform(0.05, 0.3)
    return normalise(loop_seam(hiss + drops), 0.5)


def waves():
    """Waves washing up the beach: a rush as each wave breaks, then a long
    fizzing pull back. One wave every 7 s, like the sea's swell (sea.gdshader)."""
    period = 2 * np.pi / 0.9
    length = period * 2
    t = seconds(length + 1.0)
    phase = (t % period) / period
    rush = np.exp(-((phase - 0.3) / 0.08) ** 2) + 0.35 * np.exp(-((phase - 0.55) / 0.2) ** 2)
    roar = shape(noise(len(t) / RATE), 80, 2500, -0.8) * (0.25 + rush)
    fizz = shape(noise(len(t) / RATE), 2500, 9000) * np.exp(-((phase - 0.6) / 0.22) ** 2) * 0.25
    return normalise(loop_seam(roar + fizz, 1.0), 0.6)


def wind():
    length = 14.0
    t = seconds(length + 1.0)
    swell = 0.6 + 0.4 * np.sin(2 * np.pi * t / (length + 1.0)) * np.sin(2 * np.pi * t * 3 / (length + 1.0))
    out = shape(noise(len(t) / RATE), 60, 900, -1.0) * swell
    return normalise(loop_seam(out, 1.0), 0.4)


def crickets():
    length = 6.0
    out = np.zeros(int(length * RATE))
    for voice_no in range(4):
        f = rng.uniform(4200, 5200)
        start = rng.uniform(0, 0.4)
        while start < length - 0.3:
            chirp = np.sin(2 * np.pi * f * seconds(0.12)) * (0.5 + 0.5 * np.sin(2 * np.pi * 70 * seconds(0.12))) * envelope(0.12, 0.01, 0.05)
            i = int(start * RATE)
            out[i : i + len(chirp)] += chirp * rng.uniform(0.2, 0.5)
            start += rng.uniform(0.5, 0.9)
    return normalise(loop_seam(reverb(out, 0.6, 0.3), 0.3), 0.35)


def whistle():
    """Your whistle calling the horse: a rising note, then a long falling one."""
    t1 = seconds(0.22)
    up = sweep(1400, 2300, 0.22) * envelope(0.22, 0.02, 0.15)
    t2 = seconds(0.5)
    down = sweep(2400, 1600, 0.5, 1.5) * (1 + 0.04 * np.sin(2 * np.pi * 6 * t2)) * envelope(0.5, 0.02, 0.3)
    breath = shape(noise(0.8), 1500, 5000) * 0.05
    out = np.concatenate([fade(up, 0.01, 0.03), np.zeros(int(0.08 * RATE)), fade(down, 0.01, 0.08)])
    out += breath[: len(out)]
    return normalise(reverb(out, 0.9, 0.2), 0.7)


# --- Little tunes ----------------------------------------------------------------------

def note(name):
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semis = names[name[0]] + (1 if "#" in name else 0) + 12 * (int(name[-1]) - 4)
    return 440.0 * 2 ** (semis / 12)


def chime(notes, gap, length=1.2):
    out = np.zeros(int((gap * len(notes) + length) * RATE))
    for k, n in enumerate(notes):
        f = note(n)
        tone = (np.sin(2 * np.pi * f * seconds(length)) + 0.3 * np.sin(2 * np.pi * f * 2 * seconds(length))) * envelope(length, 0.003, 0.25)
        i = int(k * gap * RATE)
        out[i : i + len(tone)] += tone
    return normalise(reverb(fade(out, 0.002, 0.1), 1.0, 0.2), 0.7)


def music():
    """A gentle tune for riding: a harp melody over soft chords, in C major,
    82 beats a minute, 16 bars that loop."""
    beat = 60 / 82
    bars = [
        ("C", [("E5", 1), ("G5", 1), ("C6", 1.5), ("B5", 0.5)]),
        ("Am", [("A5", 2), ("G5", 1), ("E5", 1)]),
        ("F", [("F5", 1), ("A5", 1), ("C6", 1), ("A5", 1)]),
        ("G", [("G5", 3), (None, 1)]),
        ("C", [("E5", 1), ("G5", 1), ("C6", 1), ("D6", 1)]),
        ("Am", [("E6", 2), ("D6", 1), ("C6", 1)]),
        ("F", [("A5", 1), ("C6", 1), ("A5", 1), ("F5", 1)]),
        ("G", [("G5", 4)]),
        ("F", [("A5", 1.5), ("G5", 0.5), ("F5", 1), ("A5", 1)]),
        ("G", [("B5", 1.5), ("A5", 0.5), ("G5", 1), ("B5", 1)]),
        ("Em", [("G5", 1), ("E5", 1), ("G5", 1), ("B5", 1)]),
        ("Am", [("A5", 3), ("C6", 1)]),
        ("F", [("C6", 1), ("A5", 1), ("F5", 1), ("A5", 1)]),
        ("G", [("D6", 1), ("B5", 1), ("G5", 1), ("B5", 1)]),
        ("C", [("C6", 4)]),
        ("C", [("E5", 1), ("D5", 1), ("C5", 2)]),
    ]
    chords = {"C": ["C3", "G3", "C4", "E4"], "Am": ["A2", "E3", "A3", "C4"], "F": ["F2", "C3", "F3", "A3"],
              "G": ["G2", "D3", "G3", "B3"], "Em": ["E2", "B2", "E3", "G3"]}
    total = int(len(bars) * 4 * beat * RATE)
    out = np.zeros(total + RATE * 3)
    for b, (chord, melody) in enumerate(bars):
        start = b * 4 * beat
        # Soft pad: detuned sines swelling in and out over the bar.
        length = 4 * beat + 0.6
        t = seconds(length)
        pad_env = np.minimum(t / 0.6, 1) * np.minimum((length - t) / 0.6, 1)
        for n in chords[chord]:
            f = note(n)
            pad = sum(np.sin(2 * np.pi * f * (1 + d) * t) for d in (-0.003, 0.0, 0.003)) / 3
            i = int(start * RATE)
            out[i : i + len(t)] += pad * pad_env * 0.06
        # Bass on beats 1 and 3, and a gentle arpeggio on the off-beats.
        for k, n in enumerate([chords[chord][0], chords[chord][0]]):
            i = int((start + k * 2 * beat) * RATE)
            p = pluck(note(n), 2 * beat, 0.2, 0.998)
            out[i : i + len(p)] += p * 0.35
        for k in range(4):
            n = chords[chord][1 + k % 3]
            i = int((start + (k + 0.5) * beat) * RATE)
            p = pluck(note(n) * 2, beat * 1.5, 0.3)
            out[i : i + len(p)] += p * 0.12
        # The melody, an octave down for a softer harp.
        at = start
        for n, d in melody:
            if n:
                f = note(n) / 2
                p = pluck(f, d * beat + 1.0, 0.5, 0.997)
                i = int(at * RATE)
                out[i : i + len(p)] += p * 0.4
            at += d * beat
    # Whatever rings past the end wraps round to the start, so it loops.
    tail = out[total:]
    out = out[:total]
    out[: len(tail)] += tail
    return normalise(reverb(out, 2.2, 0.28, loop=True), 0.7)


def main():
    for surface in ["grass", "dirt", "sand", "water"]:
        for v in range(1, 4):
            save("hoof_%s_%d" % (surface, v), hoof(surface, v))
    for v in range(3):
        save("whinny_%d" % (v + 1), whinny(v))
    save("nicker", nicker())
    save("snort", snort())
    for k in range(5):
        save("bird_%d" % (k + 1), bird(k))
    for v in range(2):
        save("gull_%d" % (v + 1), gull(v))
    save("rain", rain(), True)
    save("waves", waves(), True)
    save("wind", wind(), True)
    save("crickets", crickets(), True)
    save("coin", chime(["B5", "E6"], 0.07, 0.8))
    save("discover", chime(["C5", "E5", "G5", "C6", "E6"], 0.11, 1.4))
    save("trophy", chime(["G4", "C5", "E5", "G5", "C6", "E6", "G6"], 0.09, 1.6))
    save("click", normalise(fade(sweep(900, 600, 0.05) * envelope(0.05, 0.001, 0.012), 0.001, 0.01), 0.5))
    save("crunch", normalise(fade(shape(noise(0.4), 800, 6000) * (np.abs(np.sin(2 * np.pi * 7 * seconds(0.4))) ** 3) * envelope(0.4, 0.01, 0.15), 0.002, 0.05), 0.6))
    save("brush", normalise(fade(shape(noise(0.3), 2000, 8000) * envelope(0.3, 0.05, 0.1), 0.01, 0.05), 0.4))
    save("land", normalise(fade(sweep(90, 40, 0.3) * envelope(0.3, 0.003, 0.08) + shape(noise(0.3), 200, 1500) * envelope(0.3, 0.002, 0.04) * 0.4, 0.001, 0.05), 0.9))
    save("whistle", whistle())
    save("music", music(), True)
    for v in range(1, 4):
        save("hoof_snow_%d" % v, hoof("snow", v))


if __name__ == "__main__":
    main()
