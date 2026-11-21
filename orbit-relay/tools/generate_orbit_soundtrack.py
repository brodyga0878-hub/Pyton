#!/usr/bin/env python3
"""Render the original Orbital Relay soundtrack as seamless stereo PCM loops."""

import argparse
import math
import random
import struct
import wave
from pathlib import Path

RATE = 24000
TAU = math.tau
OUTPUT = Path(__file__).resolve().parents[1] / "assets" / "audio"

# Each tuple holds the bass, chord voicing and lead phrase for a four-beat bar.
SCORES = {
    "berth": (82, [
        (43, (55, 59, 62, 69), (74, None, 71, 69)),
        (40, (55, 59, 64, 66), (67, None, 69, None)),
        (36, (55, 59, 62, 64), (71, 74, 76, None)),
        (38, (57, 62, 66, 69), (78, None, 74, 71)),
        (43, (55, 59, 62, 69), (74, None, 79, 78)),
        (40, (55, 59, 64, 66), (76, None, 71, None)),
        (36, (55, 59, 62, 64), (72, 71, 67, 66)),
        (38, (57, 62, 66, 69), (69, None, None, None)),
    ]),
    "flight": (93, [
        (45, (57, 60, 64, 71), (76, None, 72, 71)),
        (41, (57, 60, 65, 67), (69, None, 72, 74)),
        (48, (55, 60, 64, 67), (76, None, 79, 76)),
        (43, (55, 59, 62, 69), (74, 71, None, None)),
        (45, (57, 60, 64, 71), (76, None, 81, 79)),
        (41, (57, 60, 65, 67), (77, None, 76, 72)),
        (48, (55, 60, 64, 67), (74, 76, 79, None)),
        (43, (55, 59, 62, 69), (74, None, 71, None)),
    ]),
    "combat": (136, [
        (38, (50, 53, 57, 64), (65, 57, 62, 58)),
        (38, (50, 55, 58, 62), (65, 62, 67, 63)),
        (34, (50, 53, 58, 67), (62, 65, 70, 67)),
        (37, (49, 55, 58, 64), (64, 61, 67, 65)),
        (38, (50, 53, 57, 64), (69, 65, 62, 65)),
        (38, (50, 55, 58, 62), (67, 62, 65, 70)),
        (34, (50, 53, 58, 67), (65, 70, 74, 72)),
        (37, (49, 55, 58, 64), (73, 67, 64, None)),
    ]),
    "transit": (112, [
        (44, (56, 59, 63, 70), (70, 71, 75, 78)),
        (47, (58, 63, 66, 68), (82, None, 78, 75)),
        (42, (54, 58, 61, 68), (73, 78, 80, None)),
        (46, (58, 61, 65, 68), (77, 80, 82, None)),
        (44, (56, 59, 63, 70), (83, 82, 78, 75)),
        (47, (58, 63, 66, 68), (80, None, 78, 71)),
        (42, (54, 58, 61, 68), (73, 75, 78, 80)),
        (46, (58, 61, 65, 68), (77, 73, 70, None)),
    ]),
}


def oscillate(timbre, phase, seconds):
    if timbre == "pad":
        return 0.70 * math.sin(phase) + 0.21 * math.sin(phase * 1.003) + 0.09 * math.sin(2 * phase)
    if timbre == "pluck":
        return math.sin(phase + 0.8 * math.exp(-4.2 * seconds) * math.sin(2 * phase))
    if timbre == "pulse":
        return 0.74 * math.sin(phase) + 0.18 * math.sin(3 * phase) + 0.08 * math.sin(5 * phase)
    return 0.84 * math.sin(phase + 1.2 * math.sin(TAU * 4.6 * seconds)) + 0.16 * math.sin(phase * 2)


def render(path, context):
    tempo, bars = SCORES[context]
    beat = 60.0 / tempo
    size = round(len(bars) * 4 * beat * RATE)
    left, right = [0.0] * size, [0.0] * size
    noise = random.Random(75923)

    def note(start, midi, length, gain, pan, timbre):
        duration = length * beat
        offset = round(start * beat * RATE)
        attack = 0.22 if timbre == "pad" else 0.022
        release = 0.42 if timbre == "pad" else min(0.20, duration * 0.4)
        omega = TAU * 440 * 2 ** ((midi - 69) / 12)
        stereo_left = math.sqrt(0.5 * (1.0 - pan))
        stereo_right = math.sqrt(0.5 * (1.0 + pan))
        for index in range(round(duration * RATE)):
            seconds = index / RATE
            envelope = max(0.0, min(1.0, seconds / attack, (duration - seconds) / release))
            envelope = envelope * envelope * (3.0 - 2.0 * envelope)
            if timbre == "pluck":
                envelope *= math.exp(-2.8 * seconds)
            sample = gain * envelope * oscillate(timbre, omega * seconds, seconds)
            frame = (offset + index) % size
            left[frame] += sample * stereo_left
            right[frame] += sample * stereo_right

    def drum(start, gain, kick):
        offset = round(start * beat * RATE)
        for index in range(round(0.13 * RATE)):
            seconds = index / RATE
            phase = TAU * (48 * seconds + 1.75 * (1.0 - math.exp(-25 * seconds)))
            wave_sample = math.sin(phase) if kick else noise.uniform(-1.0, 1.0) * 0.55
            sample = gain * wave_sample * min(1.0, seconds * 350.0) * math.exp(-35 * seconds)
            frame = (offset + index) % size
            left[frame] += sample * 0.8
            right[frame] += sample * (0.8 if kick else 0.6)

    for bar_index, (bass, chord, phrase) in enumerate(bars):
        start = bar_index * 4
        brisk = context in ("combat", "transit")
        for index, midi in enumerate(chord):
            note(start - 0.15 + 0.05 * index, midi, 4.45, 0.085, (index - 1.5) * 0.39, "pad")
        if brisk:
            for pulse in (0, 0.75, 1.5, 2, 2.75, 3.5):
                note(start + pulse, bass + (12 if pulse == 3.5 else 0), 0.52, 0.28, -0.02, "pulse")
            for offset in (0, 2):
                drum(start + offset, 0.27 if context == "combat" else 0.13, True)
            for offset in (0.5, 1.5, 2.5, 3.5):
                drum(start + offset, 0.1, False)
        else:
            note(start, bass, 3.9, 0.19, 0.0, "pad")
        for index in range(8):
            if context != "berth" or index % 2 == 1:
                note(start + index * 0.5, chord[(index * 3) % 4] + 12, 0.72, 0.082, (-1) ** index * 0.58, "pluck")
        for index, midi in enumerate(phrase):
            if midi is not None:
                note(start + index, midi, 0.82 if brisk else 1.38, 0.14, 0.20, "pluck" if context == "berth" else "lead")

    delay = round(0.42 * beat * RATE)
    echo_left = [left[i] + 0.15 * right[(i - delay) % size] for i in range(size)]
    echo_right = [right[i] + 0.12 * left[(i - delay * 2) % size] for i in range(size)]
    peak = max(map(abs, echo_left + echo_right))
    scale = 0.70 * 32767.0 / peak
    packed = bytearray(size * 4)
    for index, (a, b) in enumerate(zip(echo_left, echo_right)):
        struct.pack_into("<hh", packed, index * 4, round(a * scale), round(b * scale))
    with wave.open(str(path), "wb") as stream:
        stream.setparams((2, 2, RATE, size, "NONE", "not compressed"))
        stream.writeframes(packed)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    for context in SCORES:
        render(args.output / f"{context}.wav", context)


if __name__ == "__main__":
    main()
