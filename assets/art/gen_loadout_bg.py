# -*- coding: utf-8 -*-
"""
Avatar / Jihoz ekrani uchun MAXSUS fon (protsedural, Pillow).

Qorong'i, atmosferali 1-jahon urushi shomi (dusk) manzarasi — markaz-chap qism
qoramtir va sokin (3D avatar shu yerda turadi, ajralib ko'rinsin), o'ngda iliq dusk
nuri. Buzilgan daraxt/minora siluetlari, tuman, vignetka, yengil grain.

Canva kvotasi tugagani uchun protsedural yo'l ishlatiladi (shaffoflik shart emas).
Ishga tushirish:  python assets/art/gen_loadout_bg.py
Natija:  assets/ui/menu/loadout_background.png  (1600x900, 16:9)
"""

import os
import math
import random

from PIL import Image, ImageDraw, ImageFilter, ImageChops

W, H = 1600, 900
random.seed(7)

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "ui", "menu", "loadout_background.png"))


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def build():
    horizon = int(H * 0.56)
    sky_top = (16, 18, 28)        # qorong'i slate-ko'k
    sky_horizon = (96, 66, 46)    # iliq dusk jigarrang-amber
    ground_far = (32, 27, 26)     # ufqdagi yer
    ground_near = (9, 8, 10)      # deyarli qora (oldingi plan)

    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    # 1) Vertikal gradient (har qator bir rang — tez).
    for y in range(H):
        if y < horizon:
            t = y / horizon
            c = lerp(sky_top, sky_horizon, t ** 1.7)
        else:
            t = (y - horizon) / (H - horizon)
            c = lerp(ground_far, ground_near, t ** 0.7)
        d.line([(0, y), (W, y)], fill=c)

    # 2) Iliq dusk nuri (o'ngda, ufq atrofida) — screen blend.
    glow = Image.new("RGB", (W, H), (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gx, gy = int(W * 0.66), horizon - 10
    gr = int(W * 0.34)
    gd.ellipse([gx - gr, gy - int(gr * 0.55), gx + gr, gy + int(gr * 0.55)], fill=(150, 95, 50))
    glow = glow.filter(ImageFilter.GaussianBlur(130))
    img = ImageChops.screen(img, glow)

    # 3) Ufq tumani — yupqa iliq gorizontal tasma (chuqurlik hissi).
    fog = Image.new("RGB", (W, H), (0, 0, 0))
    fd = ImageDraw.Draw(fog)
    fd.rectangle([0, horizon - 18, W, horizon + 26], fill=(70, 60, 56))
    fog = fog.filter(ImageFilter.GaussianBlur(22))
    img = ImageChops.screen(img, fog)

    # 4) Siluetlar (buzilgan daraxt / minora / xandaq qoldiqlari) — ufq bo'ylab.
    sil = ImageDraw.Draw(img)

    def silhouette_color(depth):
        # uzoq (depth->1) => haze sababli ufq rangiga yaqin; yaqin => deyarli qora
        base = (10, 9, 11)
        return lerp(base, sky_horizon, 0.28 * depth)

    # Minoralar/binolar (o'ngroqda, nur fonida ajralsin)
    for (bx, bw, bh, depth) in [(int(W * 0.55), 60, 150, 0.6), (int(W * 0.74), 80, 200, 0.45),
                                 (int(W * 0.86), 50, 120, 0.7)]:
        top = horizon - bh
        sil.rectangle([bx, top, bx + bw, horizon], fill=silhouette_color(depth))
        # tom (uchburchak)
        sil.polygon([(bx - 8, top), (bx + bw + 8, top), (bx + bw // 2, top - 28)],
                    fill=silhouette_color(depth))

    # Buzilgan daraxtlar (siyrak, asosan markaz-o'ngda; chap toza qolsin)
    def broken_tree(x, h, depth):
        col = silhouette_color(depth)
        sil.line([(x, horizon), (x, horizon - h)], fill=col, width=max(2, int(6 * (1 - depth))))
        # sinib qolgan shoxlar
        for _ in range(random.randint(1, 3)):
            yy = horizon - random.randint(int(h * 0.4), h)
            dx = random.randint(-26, 26)
            sil.line([(x, yy), (x + dx, yy - random.randint(8, 26))], fill=col,
                     width=max(1, int(3 * (1 - depth))))

    for _ in range(7):
        x = random.randint(int(W * 0.42), int(W * 0.98))
        broken_tree(x, random.randint(60, 150), random.uniform(0.3, 0.8))
    # chap chetda bittagina uzoq, xira daraxt (kompozitsiya)
    broken_tree(int(W * 0.08), 90, 0.85)

    # Oldingi plan yer to'lqini (pastki qorong'i tepalik) — avatar "yerda" tursin.
    fg = silhouette_color(0.0)
    pts = [(0, H)]
    yb = int(H * 0.86)
    for x in range(0, W + 1, 80):
        pts.append((x, yb + int(18 * math.sin(x * 0.011) - random.randint(0, 14))))
    pts.append((W, H))
    sil.polygon(pts, fill=fg)

    # 5) Vignetka — chetlarni qoraytirish (markaz yorug'roq).
    vig = Image.new("L", (W, H), 0)
    vd = ImageDraw.Draw(vig)
    vd.ellipse([int(-W * 0.18), int(-H * 0.22), int(W * 1.18), int(H * 1.25)], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(200))
    black = Image.new("RGB", (W, H), (0, 0, 0))
    img = Image.composite(img, black, vig)

    # 6) Yengil grain (film donador) — juda past kuch.
    noise = Image.effect_noise((W, H), 16).convert("RGB")
    img = ImageChops.add(img, ImageChops.multiply(noise, Image.new("RGB", (W, H), (28, 28, 28))))

    return img


if __name__ == "__main__":
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    build().save(OUT)
    print("SAVED:", OUT)
