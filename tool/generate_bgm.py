"""Render Runtime Loop, an original 16-bar chiptune. Python stdlib only."""
from array import array
import math
from pathlib import Path
import random
import wave

RATE = 22050
BPM = 112
BEAT = 60 / BPM
STEP = BEAT / 2
BARS = 16
samples = array('d', [0.0]) * round(BARS * 4 * BEAT * RATE)
noise = random.Random(281)


def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def tone(start, duration, midi, gain, voice='lead'):
    frequency = hz(midi)
    offset = round(start * RATE)
    length = round(duration * RATE)
    for i in range(min(length, len(samples) - offset)):
        t = i / RATE
        phase = 2 * math.pi * frequency * t
        attack = min(1, t / 0.008)
        release = min(1, (duration - t) / 0.035)
        if voice == 'bass':
            value = math.sin(phase) + 0.18 * math.sin(phase * 2)
            envelope = math.exp(-t * 4)
        elif voice == 'arp':
            value = math.sin(phase) + 0.12 * math.sin(phase * 3)
            envelope = math.exp(-t * 14)
        else:
            # Soft, band-limited odd harmonics give a little console character.
            value = math.sin(phase) + 0.2 * math.sin(phase * 3) + 0.08 * math.sin(phase * 5)
            envelope = math.exp(-t * 3.5)
        samples[offset + i] += value * gain * attack * release * envelope


def drum(start, voice):
    duration = {'kick': 0.19, 'snare': 0.13, 'hat': 0.045}[voice]
    offset = round(start * RATE)
    previous = 0
    for i in range(min(round(duration * RATE), len(samples) - offset)):
        t = i / RATE
        n = noise.uniform(-1, 1)
        if voice == 'kick':
            phase = 2 * math.pi * (48 * t + 55 * (1 - math.exp(-t * 35)) / 35)
            value = math.sin(phase) * math.exp(-t * 24) * 0.24
        elif voice == 'snare':
            value = (n * 0.7 + math.sin(2 * math.pi * 180 * t) * 0.3) * math.exp(-t * 34) * 0.12
        else:
            value = (n - previous) * math.exp(-t * 90) * 0.035
        previous = n
        edge = min(1, t / 0.002) * min(1, (duration - t) / 0.006)
        samples[offset + i] += value * edge


# Two eight-bar phrases over Am / F / C / G. No borrowed melodies or samples.
chords = [(45, [69, 72, 76]), (41, [69, 72, 77]), (48, [67, 72, 76]), (43, [67, 71, 74])]
melodies = [
    [76, None, 79, 81, 79, 76, 72, None],
    [72, 76, None, 77, 76, None, 72, 69],
    [76, None, 79, 84, 83, 79, 76, None],
    [74, 71, 74, None, 79, 76, 74, None],
    [81, 79, 76, None, 72, 76, 79, None],
    [77, None, 76, 72, 69, None, 72, 76],
    [79, 76, 72, None, 76, 79, 84, None],
    [83, 79, 74, None, 71, 74, 76, None],
]
for bar in range(BARS):
    root, chord = chords[bar % 4]
    for step in range(8):
        start = (bar * 8 + step) * STEP
        bass = root + (12 if step in (3, 7) else 7 if step == 5 else 0)
        if step in (0, 2, 3, 4, 6, 7):
            tone(start, STEP * 0.78, bass, 0.17, 'bass')
        tone(start, STEP * 0.65, chord[(step + bar) % 3], 0.045, 'arp')
        note = melodies[(bar + (2 if bar >= 8 else 0)) % 8][step]
        if note is not None:
            tone(start + 0.006, STEP * 0.84, note, 0.09 if bar < 8 else 0.11)
        drum(start, 'hat')
        if step % 2 == 0:
            drum(start, 'kick' if step in (0, 4) else 'snare')

peak = max(abs(value) for value in samples)
pcm = array('h', (round(value / peak * 0.65 * 32767) for value in samples))
# WAV is little endian even when regenerated on a big-endian host.
import sys
if sys.byteorder != 'little':
    pcm.byteswap()
destination = Path(__file__).resolve().parents[1] / 'assets/audio/runtime_loop.wav'
with wave.open(str(destination), 'wb') as output:
    output.setnchannels(1)
    output.setsampwidth(2)
    output.setframerate(RATE)
    output.writeframes(pcm.tobytes())
print(f'{destination.name}: {len(samples) / RATE:.2f}s, 16 bars, {BPM} BPM, {destination.stat().st_size} bytes')
