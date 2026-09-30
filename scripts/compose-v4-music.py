"""Compose original public-domain-by-author game cues and encode small Ogg assets.

This project owns the notes and synthesis; there are no sampled recordings.
"""
import math
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

RATE = 22050
BEAT = 60 / 96
ROOT = Path(__file__).resolve().parents[1] / 'public' / 'assets' / 'music'
ROOT.mkdir(parents=True, exist_ok=True)

# Named harmonic/melodic motifs per location. Values are MIDI notes and original phrases.
TRACKS = {
    'idle': (76, 0.30, [(50, 57, 62), (48, 55, 60), (46, 53, 58), (48, 55, 62)], [74, 72, 69, 67, 69, 72, 74, 76]),
    'tavern': (104, 0.44, [(53, 57, 60), (55, 59, 62), (50, 53, 57), (53, 57, 60)], [69, 72, 74, 72, 69, 67, 65, 69]),
    'hall_of_wonders': (92, 0.34, [(49, 56, 61), (51, 56, 63), (54, 58, 63), (49, 56, 61)], [73, 75, 80, 78, 75, 73, 68, 70]),
    'high_hall': (82, 0.41, [(45, 52, 57), (48, 52, 60), (50, 57, 62), (45, 52, 57)], [69, 72, 76, 74, 72, 69, 67, 64]),
    'upper_city_walls': (90, 0.43, [(43, 50, 55), (46, 53, 58), (48, 55, 60), (43, 50, 55)], [67, 70, 74, 72, 70, 67, 65, 62]),
    'battle_01': (132, 0.58, [(45, 52, 57), (43, 50, 55), (41, 48, 53), (43, 50, 55)], [69, 69, 72, 69, 76, 74, 72, 67]),
    'battle_02': (142, 0.58, [(50, 57, 62), (48, 55, 60), (46, 53, 58), (48, 55, 60)], [74, 72, 77, 74, 72, 69, 67, 69]),
    'final_battle': (126, 0.64, [(38, 45, 50), (41, 48, 53), (43, 50, 55), (38, 45, 50)], [62, 65, 69, 74, 72, 69, 65, 62]),
    'victory': (78, 0.42, [(48, 55, 60), (50, 57, 62), (53, 60, 65), (48, 55, 60)], [72, 76, 79, 81, 79, 76, 74, 72]),
}

def tone(note, duration, shape='string'):
    n = int(duration * RATE)
    t = np.arange(n) / RATE
    hz = 440 * 2 ** ((note - 69) / 12)
    phase = 2 * np.pi * hz * t
    attack = np.minimum(1, t / (0.07 if shape == 'string' else 0.012))
    release = np.minimum(1, (duration - t) / (0.22 if shape == 'string' else 0.08))
    envelope = np.maximum(0, attack * release)
    if shape == 'string':
        sound = np.sin(phase) * .64 + np.sin(phase * 2.001) * .24 + np.sin(phase * 3.004) * .08
    else:
        sound = np.sin(phase) * .72 + np.sin(phase * 2) * .17 + np.sin(phase * 4) * .08
    return (sound * envelope).astype(np.float32)

def make(name, bpm, intensity, chords, melody):
    step = 60 / bpm
    length = int(32 * step * RATE)
    audio = np.zeros(length + RATE, dtype=np.float32)
    def place(note, start, beats, amp, shape='string'):
        beginning = int(start * step * RATE)
        sound = tone(note, beats * step, shape)
        audio[beginning:beginning + len(sound)] += sound * amp
    for bar in range(8):
        chord = chords[bar % 4]
        start = bar * 4
        for n in chord:
            place(n, start, 3.9, intensity * .19)
        place(chord[0]-12, start, 2, intensity * .23)
        place(chord[0]-12, start+2, 1.8, intensity * .14)
        for beat in range(4):
            note = melody[(bar * 4 + beat) % len(melody)] + (0 if bar < 4 else 12 if name == 'victory' else 0)
            place(note, start+beat, .83, intensity * (.21 if beat % 2 else .28), 'bell')
        if name.startswith('battle') or name == 'final_battle':
            for beat in range(4):
                place(chord[0]-24, start+beat, .22, intensity * .33, 'bell')
    # A short echo gives the homemade instruments depth without samples.
    delay = int(.29 * RATE)
    audio[delay:] += audio[:-delay] * .12
    audio = np.tanh(audio[:length] * 1.25)
    fade = int(.5 * RATE)
    audio[:fade] *= np.linspace(0, 1, fade)
    audio[-fade:] *= np.linspace(1, 0, fade)
    with tempfile.NamedTemporaryFile(suffix='.wav') as tmp:
        with wave.open(tmp.name, 'wb') as wav:
            wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(RATE)
            wav.writeframes((audio * 32767).astype('<i2').tobytes())
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', tmp.name, '-c:a', 'libopus', '-b:a', '48k', str(ROOT / f'{name}.ogg')], check=True)

for track, values in TRACKS.items():
    make(track, *values)
    print(track)
