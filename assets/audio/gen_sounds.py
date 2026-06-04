# -*- coding: utf-8 -*-
"""
Protsedural SFX generator — otish va qadam tovushlari (WAV).

Faqat Python standart kutubxonasi (wave, struct, math, random) — bpy KERAK EMAS,
lekin Blender'ning Python'i orqali ishlatsa ham bo'ladi:
  & "<blender>" --background --python assets\\audio\\gen_sounds.py
yoki tizim python'i bo'lsa: python assets\\audio\\gen_sounds.py

Natija: assets/audio/shot.wav, footstep.wav
DIQQAT: bular oddiy protsedural placeholder — keyin yaxshiroq tovush bilan almashtirsa bo'ladi.
"""

import wave
import struct
import math
import random
import os

SR = 22050  # namuna chastotasi


def write_wav(path, samples):
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)  # 16-bit
        w.setframerate(SR)
        frames = bytearray()
        for s in samples:
            v = int(max(-1.0, min(1.0, s)) * 32767)
            frames += struct.pack("<h", v)
        w.writeframes(bytes(frames))
    print("WAV:", os.path.basename(path), len(samples), "namuna")


def gunshot(seed=1):
    random.seed(seed)
    dur = 0.16
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-t * 32.0)               # tez so'nish
        noise = random.uniform(-1.0, 1.0)        # "taraq" — oq shovqin
        body = math.sin(2 * math.pi * 95.0 * t)  # past "dub" tanasi
        crack = math.sin(2 * math.pi * 1800.0 * t) * math.exp(-t * 90.0)  # o'tkir bosh
        s = (noise * 0.7 + body * 0.5 + crack * 0.4) * env
        out.append(s * 0.85)
    return out


def footstep(seed=7):
    random.seed(seed)
    dur = 0.09
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-t * 48.0)
        noise = random.uniform(-1.0, 1.0) * 0.4
        low = math.sin(2 * math.pi * 65.0 * t) * 0.6
        s = (noise + low) * env
        out.append(s * 0.55)
    return out


out_dir = os.path.dirname(os.path.abspath(__file__))
write_wav(os.path.join(out_dir, "shot.wav"), gunshot())
write_wav(os.path.join(out_dir, "footstep.wav"), footstep())
print("DONE")
