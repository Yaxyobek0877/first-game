# -*- coding: utf-8 -*-
"""
Protsedural fon musiqasi generatori — menyu va jang treklari (WAV, loop).

Faqat Python standart kutubxonasi (wave, struct, math, random) — bpy KERAK EMAS:
  python assets\\audio\\gen_music.py

Natija:
  assets/audio/menu_music.wav    — sokin, g'amgin pad (1-jahon urushi kayfiyati)
  assets/audio/combat_music.wav  — keskin, ritmli jang treki
  assets/audio/ui_click.wav      — menyu tugmasi bosilganda
  assets/audio/pistol.wav        — topponcha otish tovushi (quruq "qars")

DIQQAT: bular protsedural placeholder — keyin yaxshiroq musiqa bilan almashtirsa bo'ladi.
Seamless loop: oxiri boshiga teng-quvvatli (equal-power) crossfade bilan ulanadi.
"""

import wave
import struct
import math
import random
import os

SR = 22050  # namuna chastotasi (mono, 16-bit)

OUT_DIR = os.path.dirname(os.path.abspath(__file__))


# --- Yordamchilar ---------------------------------------------------------

def midi_to_freq(n):
    """MIDI nota raqamidan chastota (A4=69=440 Hz)."""
    return 440.0 * (2.0 ** ((n - 69) / 12.0))


def write_wav(path, samples):
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for s in samples:
            v = int(max(-1.0, min(1.0, s)) * 32767)
            frames += struct.pack("<h", v)
        w.writeframes(bytes(frames))
    print("WAV:", os.path.basename(path), "%.1fs" % (len(samples) / SR))


def soft_clip(x):
    """Yumshoq cheklov (tanh-simon) — keskin clipping o'rniga."""
    return math.tanh(x * 1.2)


def normalize(buf, peak=0.9):
    m = max((abs(s) for s in buf), default=1.0)
    if m < 1e-6:
        return buf
    g = peak / m
    return [s * g for s in buf]


def loopify(buf, fade_sec=0.18):
    """Oxirini boshiga teng-quvvatli crossfade bilan ulab seamless loop qiladi.

    Dum (fade qismi) boshga aralashtiriladi, so'ng o'sha dum kesib tashlanadi.
    Natija: buf uzunligi fade_sec ga qisqaradi, lekin chetda 'qars' bo'lmaydi.
    """
    f = int(SR * fade_sec)
    if f * 2 >= len(buf):
        return buf
    out = buf[:]
    n = len(out)
    for i in range(f):
        # teng-quvvatli (sin/cos) egri chiziq
        a = math.cos(0.5 * math.pi * (i / f))   # dum uchun (1 -> 0)
        b = math.sin(0.5 * math.pi * (i / f))   # bosh uchun (0 -> 1)
        tail = out[n - f + i]
        head = out[i]
        out[i] = head * b + tail * a
    return out[: n - f]


def adsr(i, n, a, d, s, r):
    """ADSR konvert (namunalarda). a/d/r — soniya ulushi, s — sustain darajasi."""
    at = int(n * a)
    dt = int(n * d)
    rt = int(n * r)
    st = n - at - dt - rt
    if i < at:
        return i / max(1, at)
    if i < at + dt:
        return 1.0 - (1.0 - s) * ((i - at) / max(1, dt))
    if i < at + dt + st:
        return s
    return s * (1.0 - (i - at - dt - st) / max(1, rt))


# --- Tovush sintezi -------------------------------------------------------

def pad_voice(freq, dur, vol=0.2, detune=0.006):
    """Yumshoq, sekin pad ovozi — uchta biroz farqli (detune) arra to'lqin."""
    n = int(SR * dur)
    out = [0.0] * n
    for k, dt in enumerate((-detune, 0.0, detune)):
        f = freq * (1.0 + dt)
        ph = random.uniform(0, math.pi)
        for i in range(n):
            t = i / SR
            # arra (band-cheklanmagan, lekin past chastota uchun yetarli)
            saw = 2.0 * ((f * t + ph / (2 * math.pi)) % 1.0) - 1.0
            env = adsr(i, n, 0.22, 0.12, 0.75, 0.30)
            # past o'tkazgich his uchun — yuqori harmonikani biroz so'ndiramiz
            out[i] += saw * env * vol * 0.33
    return out


def bell(freq, dur, vol=0.22):
    """Sodda 'qo'ng'iroq' — sinus + 2-harmonika, tez so'nuvchi."""
    n = int(SR * dur)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        env = math.exp(-t * 3.2)
        s = math.sin(2 * math.pi * freq * t) * 0.7
        s += math.sin(2 * math.pi * freq * 2.01 * t) * 0.3 * math.exp(-t * 5.0)
        out[i] = s * env * vol
    return out


def bass(freq, dur, vol=0.32):
    """Past bas — sinus + ozgina arra, qisqa attack."""
    n = int(SR * dur)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        env = adsr(i, n, 0.02, 0.10, 0.7, 0.20)
        s = math.sin(2 * math.pi * freq * t)
        saw = 2.0 * ((freq * t) % 1.0) - 1.0
        out[i] = (s * 0.8 + saw * 0.2) * env * vol
    return out


def kick(dur=0.18, vol=0.6):
    """Bochka (kick) — chastotasi tushuvchi sinus."""
    n = int(SR * dur)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        f = 110.0 * math.exp(-t * 24.0) + 45.0
        env = math.exp(-t * 9.0)
        out[i] = math.sin(2 * math.pi * f * t) * env * vol
    return out


def snare(dur=0.12, vol=0.35):
    """Baraban (snare) — shovqin + ozgina ohang."""
    n = int(SR * dur)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        env = math.exp(-t * 26.0)
        noise = random.uniform(-1.0, 1.0)
        tone = math.sin(2 * math.pi * 190.0 * t) * 0.3
        out[i] = (noise * 0.7 + tone) * env * vol
    return out


def mix_into(dst, src, start):
    """src ni dst ichiga start namunadan boshlab qo'shadi (joy yetsa)."""
    for i in range(len(src)):
        j = start + i
        if 0 <= j < len(dst):
            dst[j] += src[i]


# --- Treklar --------------------------------------------------------------

def make_menu():
    """Sokin, g'amgin pad — 8 akkordli ikki bo'limli aylana (har akkord 4s = ~32s loop)."""
    random.seed(11)
    chord_dur = 4.0
    # Ikki bo'lim: A (Am F C G) + B (Am F Dm E) — g'amgin; E dominanta Am ga qaytaradi.
    chords = [
        [45, 57, 60, 64],   # Am
        [41, 53, 57, 60],   # F
        [48, 55, 60, 64],   # C
        [43, 55, 59, 62],   # G
        [45, 57, 60, 64],   # Am
        [41, 53, 57, 60],   # F
        [38, 50, 53, 57],   # Dm
        [40, 52, 56, 59],   # E
    ]
    total = int(SR * chord_dur * len(chords))
    buf = [0.0] * total
    for ci, ch in enumerate(chords):
        start = int(SR * chord_dur * ci)
        for note in ch:
            v = pad_voice(midi_to_freq(note), chord_dur, vol=0.16)
            mix_into(buf, v, start)
    # Yuqorida sokin qo'ng'iroq melodiyasi (A minor pentatonika) — uzunroq, o'zgaruvchan
    mel = [69, 72, 76, 72, 74, 69, 67, 69, 72, 76, 79, 76, 74, 72, 69, 64]
    step = total // len(mel)
    for mi, mnote in enumerate(mel):
        b = bell(midi_to_freq(mnote), 2.2, vol=0.15)
        mix_into(buf, b, mi * step + int(SR * 0.3))
    buf = [soft_clip(s) for s in buf]
    buf = normalize(buf, 0.82)
    return loopify(buf)


def make_combat():
    """Keskin jang treki — ~128 BPM, bas ostinato + kick/snare + arpejio."""
    random.seed(23)
    bpm = 128.0
    beat = 60.0 / bpm
    bars = 4
    total = int(SR * beat * 4 * bars)
    buf = [0.0] * total

    # Bas ostinato (A minor): A A C D har 1/2 beat
    bass_seq = [33, 33, 36, 38]   # A1 A1 C2 D2
    half = beat / 2.0
    steps = int(beat * 4 * bars / half)
    for i in range(steps):
        note = bass_seq[i % len(bass_seq)]
        b = bass(midi_to_freq(note), half * 0.95, vol=0.30)
        mix_into(buf, b, int(SR * half * i))

    # Kick — har beatda; Snare — 2 va 4-beatda
    total_beats = int(beat * 4 * bars / beat)
    for i in range(total_beats):
        mix_into(buf, kick(), int(SR * beat * i))
        if i % 2 == 1:
            mix_into(buf, snare(), int(SR * beat * i))

    # Arpejio (yuqori, keskin) — A minor: A C E A
    arp = [69, 72, 76, 81, 76, 72]
    sixteenth = beat / 4.0
    asteps = int(beat * 4 * bars / sixteenth)
    for i in range(asteps):
        if i % 2 == 0:   # har ikkinchi 1/16 — siyrak, charchatmasin
            note = arp[(i // 2) % len(arp)]
            b = bell(midi_to_freq(note), sixteenth * 2.0, vol=0.10)
            mix_into(buf, b, int(SR * sixteenth * i))

    buf = [soft_clip(s) for s in buf]
    buf = normalize(buf, 0.9)
    return loopify(buf, fade_sec=0.08)


def make_ui_click():
    """Qisqa menyu 'klik' — yuqori sinus, juda tez so'nuvchi."""
    n = int(SR * 0.05)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-t * 90.0)
        s = math.sin(2 * math.pi * 880.0 * t) * 0.5 + math.sin(2 * math.pi * 1320.0 * t) * 0.3
        out.append(s * env * 0.5)
    return out


def make_pistol():
    """Topponcha otish — avtomatga nisbatan quruqroq, pastroq 'qars'."""
    random.seed(5)
    dur = 0.13
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-t * 40.0)
        noise = random.uniform(-1.0, 1.0)
        body = math.sin(2 * math.pi * 130.0 * t)
        crack = math.sin(2 * math.pi * 1500.0 * t) * math.exp(-t * 120.0)
        s = (noise * 0.6 + body * 0.55 + crack * 0.35) * env
        out.append(s * 0.8)
    return out


if __name__ == "__main__":
    write_wav(os.path.join(OUT_DIR, "menu_music.wav"), make_menu())
    write_wav(os.path.join(OUT_DIR, "combat_music.wav"), make_combat())
    write_wav(os.path.join(OUT_DIR, "ui_click.wav"), make_ui_click())
    write_wav(os.path.join(OUT_DIR, "pistol.wav"), make_pistol())
    print("DONE")
