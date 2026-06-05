# -*- coding: utf-8 -*-
"""
Qo'shimcha HUD ikonkasi (protsedural, Pillow): zaxira magazin ikoni.
gen_art.py'dan ALOHIDA (boshqa terminalda tahrirlanishi mumkin).

  python assets/art/gen_hud_icons.py
Natija: assets/ui/hud/icon_mag.png  (64x64, shaffof — magazin silueti)
"""
import os
from PIL import Image, ImageDraw

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                    "..", "ui", "hud", "icon_mag.png"))

S = 64
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

BODY = (62, 64, 72, 255)       # magazin tanasi (gunmetal)
EDGE = (22, 23, 27, 255)       # qora kontur
HILITE = (110, 114, 124, 255)  # yorug' qirra
BRASS = (206, 164, 64, 255)    # patron (guruch)
BASE = (34, 35, 40, 255)       # tagliklik

# Magazin tanasi — yengil qiya (taper) to'rtburchak
body = [(22, 14), (42, 14), (45, 50), (19, 50)]
d.polygon(body, fill=BODY, outline=EDGE)
d.line([(24, 16), (24, 48)], fill=HILITE, width=2)         # chap yorug' qirra
# Yuqori "lab" (feed lips) + ko'rinib turgan patron
d.rectangle([21, 11, 43, 16], fill=HILITE, outline=EDGE)
d.ellipse([26, 5, 38, 16], fill=BRASS, outline=EDGE)        # tepada patron uchi
# Tagliklik (baseplate)
d.rectangle([16, 49, 48, 57], fill=BASE, outline=EDGE)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
img.save(OUT)
print("SAVED:", OUT)
