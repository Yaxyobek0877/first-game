# -*- coding: utf-8 -*-
# Qo'shimcha ikonkalar (gen_art.py dan ALOHIDA — u boshqa terminalda tahrirlanmoqda):
#   res://icon.png                      — o'yin/ilova ikonkasi (dubulg'a emblemi, amber nur)
#   assets/ui/hud/icon_topponcha.png    — pistol (topponcha) HUD ikonkasi
#   python assets/art/gen_icons_extra.py
import os, math
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # first_game/
HUD = os.path.join(ROOT, "assets", "ui", "hud")
os.makedirs(HUD, exist_ok=True)

STEEL = (74, 78, 74, 255); STEEL_HI = (122, 128, 120, 255)
DARK = (20, 21, 18, 255); AMBER = (232, 156, 70)
S = 4   # supersampling


def _save(img, size, path):
	img.resize((size, size), Image.LANCZOS).save(path)


def make_app_icon(size=256):
	W = size * S
	img = Image.new("RGBA", (W, W), (0, 0, 0, 0)); d = ImageDraw.Draw(img)
	# fon — yumaloq to'rtburchak (to'q)
	d.rounded_rectangle((0, 0, W, W), int(W * 0.18), fill=(34, 30, 26, 255))
	# amber radial nur (markazda)
	glow = Image.new("RGBA", (W, W), (0, 0, 0, 0)); gd = ImageDraw.Draw(glow)
	gd.ellipse((int(W * 0.18), int(W * 0.22), int(W * 0.82), int(W * 0.86)),
			   fill=(AMBER[0], AMBER[1], AMBER[2], 150))
	glow = glow.filter(ImageFilter.GaussianBlur(int(W * 0.07)))
	img = Image.alpha_composite(img, glow); d = ImageDraw.Draw(img)
	# dubulg'a (Brodie — keng tepalik + sayoz gumbaz) silueti
	cx = W // 2; cy = int(W * 0.52)
	# soya
	d.ellipse((cx - int(W * 0.40), cy - int(W * 0.02), cx + int(W * 0.40), cy + int(W * 0.16)), fill=DARK)
	# keng tepalik (brim)
	d.ellipse((cx - int(W * 0.38), cy - int(W * 0.01), cx + int(W * 0.38), cy + int(W * 0.13)), fill=STEEL)
	# gumbaz
	d.ellipse((cx - int(W * 0.25), cy - int(W * 0.22), cx + int(W * 0.25), cy + int(W * 0.06)), fill=STEEL)
	# gumbaz yorug' qirrasi
	d.arc((cx - int(W * 0.24), cy - int(W * 0.21), cx + int(W * 0.24), cy + int(W * 0.05)),
		  200, 340, fill=STEEL_HI, width=int(W * 0.018))
	# brim ostidagi qorong'i chiziq (hajm)
	d.ellipse((cx - int(W * 0.30), cy + int(W * 0.03), cx + int(W * 0.30), cy + int(W * 0.12)),
			  outline=(30, 30, 27, 255), width=int(W * 0.012))
	_save(img, size, os.path.join(ROOT, "icon.png"))
	print("icon.png", size)


def make_pistol_icon(size=128):
	W = size * S
	img = Image.new("RGBA", (W, W), (0, 0, 0, 0)); d = ImageDraw.Draw(img)
	def R(x): return int(W * x)
	cy = R(0.42)
	OL = 8
	# kontur (qora)
	d.rounded_rectangle((R(0.30) - OL, cy - R(0.08) - OL, R(0.66) + OL, cy + R(0.06) + OL), R(0.02), fill=DARK)  # zatvor/ramka
	d.rounded_rectangle((R(0.62) - OL, cy - R(0.05) - OL, R(0.90) + OL, cy + R(0.03) + OL), R(0.012), fill=DARK)  # stvol
	d.polygon([(R(0.34), cy + R(0.05)), (R(0.50), cy + R(0.05)),
			   (R(0.44), cy + R(0.40) + OL), (R(0.30), cy + R(0.40) + OL)], fill=DARK)  # grip
	# metall
	d.rounded_rectangle((R(0.30), cy - R(0.08), R(0.66), cy + R(0.06)), R(0.02), fill=STEEL)
	d.rounded_rectangle((R(0.62), cy - R(0.05), R(0.90), cy + R(0.03)), R(0.012), fill=STEEL)
	d.polygon([(R(0.345), cy + R(0.05)), (R(0.495), cy + R(0.05)),
			   (R(0.435), cy + R(0.38)), (R(0.305), cy + R(0.38))], fill=STEEL)  # grip
	# trigger guard (yoy)
	d.arc((R(0.40), cy + R(0.02), R(0.56), cy + R(0.20)), 0, 180, fill=STEEL, width=R(0.02))
	# zatvor tepa yorug' qirra
	d.rectangle((R(0.30), cy - R(0.08), R(0.66), cy - R(0.05)), fill=STEEL_HI)
	d.rectangle((R(0.62), cy - R(0.05), R(0.90), cy - R(0.035)), fill=STEEL_HI)
	_save(img, size, os.path.join(HUD, "icon_topponcha.png"))
	print("icon_topponcha.png", size)


def make_smoke_puff(size=128):
	# Yumshoq dumaloq "puff" (markaz oq -> chetlar shaffof) — tutun zarrachalari uchun.
	img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
	px = img.load()
	c = size / 2.0
	for y in range(size):
		for x in range(size):
			d = math.hypot(x - c, y - c) / c
			a = max(0.0, 1.0 - d)
			a = a * a                       # yumshoqroq qirralar
			px[x, y] = (255, 255, 255, int(a * 255))
	img = img.filter(ImageFilter.GaussianBlur(4))
	out = os.path.join(ROOT, "assets", "textures", "smoke_puff.png")
	img.save(out)
	print("smoke_puff.png", size)


if __name__ == "__main__":
	make_app_icon()
	make_pistol_icon()
	make_smoke_puff()
	print("DONE")
