"""Synthesizes the Workshop drum and chime samples into assets/audio.

Run: python3 tool/make_workshop_audio.py
Each groove sample is one beat of drums plus a bass note, so the game can
trigger them on its own clock and stay in sync with the arrows.
"""
import math, random, struct, wave, os

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')
random.seed(4)

def save(name, s):
    peak = max(1e-6, max(abs(x) for x in s))
    k = 0.9 / peak if peak > 0.9 else 1
    with wave.open(os.path.join(OUT, name), 'w') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, x * k)) * 32767)) for x in s))

def n(sec): return int(SR * sec)

def kick(L):
    out = [0.0] * L
    ph = 0
    for i in range(min(L, n(0.35))):
        t = i / SR
        f = 45 + 110 * math.exp(-t * 28)
        ph += 2 * math.pi * f / SR
        out[i] = math.sin(ph) * math.exp(-t * 9) * 0.9
    return out

def hat(L, at=0.0, amp=0.18):
    out = [0.0] * L
    s = n(at); prev = 0
    for i in range(n(0.06)):
        if s + i >= L: break
        r = random.uniform(-1, 1); hp = r - prev; prev = r
        out[s + i] = hp * math.exp(-i / SR * 60) * amp
    return out

def clap(L):
    out = [0.0] * L
    for burst in (0, 0.012, 0.024):
        s = n(burst)
        for i in range(n(0.16)):
            if s + i >= L: break
            out[s + i] += random.uniform(-1, 1) * math.exp(-i / SR * (40 if burst < 0.02 else 22)) * 0.35
    return out

def bass(L, f):
    out = [0.0] * L
    for i in range(L):
        t = i / SR
        env = min(1, t * 200) * math.exp(-t * 3.2)
        out[i] = (math.sin(2 * math.pi * f * t) + 0.3 * math.sin(4 * math.pi * f * t)) * env * 0.38
    return out

def mix(*xs): return [sum(v) for v in zip(*xs)]

# Chords Am, F, C, G: bass roots.
ROOTS = [110.0, 87.31, 130.81, 98.0]
L = n(0.62)  # one beat at the slowest tempo
for ci, f in enumerate(ROOTS):
    save(f'ws_on{ci}.wav', mix(kick(L), bass(L, f), hat(L, 0, 0.14), hat(L, 0.29, 0.1)))
    save(f'ws_back{ci}.wav', mix(clap(L), bass(L, f * 1.5), hat(L, 0, 0.14), hat(L, 0.29, 0.1)))

# Hit chimes, one per direction: left, up, down, right (A minor pentatonic).
for di, f in enumerate([880.0, 1046.5, 659.25, 1174.66]):
    L2 = n(0.5)
    s = []
    for i in range(L2):
        t = i / SR
        env = min(1, t * 400) * math.exp(-t * 7)
        s.append((math.sin(2 * math.pi * f * t) + 0.35 * math.sin(2 * math.pi * f * 2.01 * t) + 0.12 * math.sin(2 * math.pi * f * 3 * t)) * env * 0.4)
    save(f'ws_chime{di}.wav', s)

# A soft wrong-step thud.
L3 = n(0.3)
save('ws_oops.wav', [math.sin(2 * math.pi * (180 - 400 * i / SR) * i / SR) * math.exp(-i / SR * 12) * 0.5 + random.uniform(-1, 1) * math.exp(-i / SR * 30) * 0.15 for i in range(L3)])
print('ok')
