# -*- coding: utf-8 -*-
# QAYTISH — UI grafika generatori (protsedural, qayta yaratiladigan).
#
# Nima uchun: Canva (Free plan) shaffof PNG eksport qila olmaydi va AI-generatsiya
# kvotasi cheklangan. HUD ikonkalari, crosshair, hitmarker SHAFFOF bo'lishi shart,
# shuning uchun ularni shu yerda Pillow bilan chizamiz. Bonus: «QAYTISH» logotipining
# qora fonini shaffofga aylantiramiz va 2 ta yetishmayotgan teksturani (qum qopi,
# zanglagan metall) protsedural — tileable qilib chizamiz.
#
# Ishga tushirish:  python assets/art/gen_art.py
# Uslub: stilize, harbiy, 1-jahon urushi; ranglar — gunmetal, po'lat, amber, zang.

import os, math, random
from PIL import Image, ImageDraw, ImageFilter, ImageChops

random.seed(7)  # determenistik natija (qayta ishga tushganda bir xil chiqadi)

ART = os.path.dirname(os.path.abspath(__file__))   # .../assets/art
ASSETS = os.path.dirname(ART)                      # .../assets
HUD = os.path.join(ASSETS, "ui", "hud")
MENU = os.path.join(ASSETS, "ui", "menu")
TEX = os.path.join(ASSETS, "textures")
for d in (HUD, MENU, TEX):
	os.makedirs(d, exist_ok=True)

# --- Rang palitrasi (RGBA) ---
WHITE   = (232, 235, 226, 255)   # och, ozgina iliq oq
STEEL   = (70, 74, 70, 255)      # po'lat (qurol tanasi)
STEEL_HI= (120, 126, 118, 255)   # po'lat — yorug' qirra
DARK    = (20, 21, 18, 255)      # qoramtir kontur
AMBER   = (230, 170, 60, 255)    # amber aksent (logo/effekt bilan uyg'un)
BRASS   = (188, 146, 64, 255)    # patron gilzasi (latun)
COPPER  = (196, 118, 66, 255)    # o'q uchi (mis)
RED     = (196, 58, 48, 255)     # jon (sanitar xoch)
RED_HI  = (224, 96, 84, 255)

S = 4  # supersampling — yiriкroq chizib, keyin kichraytiramiz (silliq qirralar uchun)


def new(size):
	"""Shaffof RGBA tuval (supersample o'lchamida)."""
	return Image.new("RGBA", (size * S, size * S), (0, 0, 0, 0))


def save(img, size, path):
	out = img.resize((size, size), Image.LANCZOS)
	out.save(path)
	return out


def outlined_round_rect(d, box, radius, fill, outline=DARK, ow=6):
	"""Konturli yumaloq to'rtburchak (ow — kontur qalinligi, supersample bo'yicha)."""
	x0, y0, x1, y1 = box
	if outline:
		d.rounded_rectangle((x0 - ow, y0 - ow, x1 + ow, y1 + ow), radius + ow, fill=outline)
	d.rounded_rectangle(box, radius, fill=fill)


# =====================================================================
#  1) Crosshair (nishon belgisi) — 4 ta chiziq + markaz nuqta, o'rtada bo'shliq
# =====================================================================
def make_crosshair(size=128):
	img = new(size); d = ImageDraw.Draw(img)
	c = size * S // 2
	gap = int(size * S * 0.12)      # markazdagi bo'shliq
	length = int(size * S * 0.20)   # har bir chiziq uzunligi
	th = int(size * S * 0.028)      # qalinlik
	def tick(x0, y0, x1, y1):
		# avval qoramtir kontur, keyin oq — har sharoitda ko'rinishi uchun
		d.rounded_rectangle((x0 - 5, y0 - 5, x1 + 5, y1 + 5), 8, fill=(0, 0, 0, 170))
		d.rounded_rectangle((x0, y0, x1, y1), 6, fill=WHITE)
	tick(c - th, c - gap - length, c + th, c - gap)   # tepa
	tick(c - th, c + gap, c + th, c + gap + length)    # past
	tick(c - gap - length, c - th, c - gap, c + th)    # chap
	tick(c + gap, c - th, c + gap + length, c + th)    # o'ng
	d.ellipse((c - 6, c - 6, c + 6, c + 6), fill=(0, 0, 0, 170))
	d.ellipse((c - 3, c - 3, c + 3, c + 3), fill=WHITE)
	return save(img, size, os.path.join(HUD, "crosshair.png"))


# =====================================================================
#  2) Hitmarker (zarba belgisi) — klassik 4 burchak X, markazda bo'shliq
# =====================================================================
def make_hitmarker(size=128):
	img = new(size); d = ImageDraw.Draw(img)
	c = size * S // 2
	gap = int(size * S * 0.10)
	length = int(size * S * 0.18)
	th = int(size * S * 0.030)
	import math as _m
	for ang in (45, 135, 225, 315):
		a = _m.radians(ang)
		dx, dy = _m.cos(a), _m.sin(a)
		x0, y0 = c + dx * gap, c + dy * gap
		x1, y1 = c + dx * (gap + length), c + dy * (gap + length)
		d.line((x0, y0, x1, y1), fill=(0, 0, 0, 170), width=th + 8)
		d.line((x0, y0, x1, y1), fill=WHITE, width=th)
	return save(img, size, os.path.join(HUD, "hitmarker.png"))


# =====================================================================
#  3) Jon (health) ikonkasi — sanitar xochi (qizil + och qirra)
# =====================================================================
def make_health(size=128):
	img = new(size); d = ImageDraw.Draw(img)
	W = size * S; c = W // 2
	arm = int(W * 0.16)   # xoch yelkasi yarim-eni
	rad = int(W * 0.30)   # xoch uzunligi (markazdan)
	r = int(W * 0.05)
	# vertikal va gorizontal brus (konturli)
	outlined_round_rect(d, (c - arm, c - rad, c + arm, c + rad), r, RED, ow=10)
	outlined_round_rect(d, (c - rad, c - arm, c + rad, c + arm), r, RED, ow=10)
	# ichki yorug' xoch (hajm hissi)
	a2 = int(arm * 0.5)
	d.rounded_rectangle((c - a2, c - rad + arm // 2, c + a2, c + rad - arm // 2), r, fill=RED_HI)
	d.rounded_rectangle((c - rad + arm // 2, c - a2, c + rad - arm // 2, c + a2), r, fill=RED_HI)
	return save(img, size, os.path.join(HUD, "icon_health.png"))


# =====================================================================
#  4) O'q-dori (ammo) ikonkasi — bitta patron (latun gilza + mis o'q)
# =====================================================================
def make_ammo(size=128):
	img = new(size); d = ImageDraw.Draw(img)
	W = size * S; c = W // 2
	w = int(W * 0.20)          # patron eni
	top = int(W * 0.16); bot = int(W * 0.86)
	tip = int(W * 0.40)        # o'q uchi tugaydigan joy
	x0, x1 = c - w, c + w
	# gilza (latun)
	outlined_round_rect(d, (x0, tip, x1, bot), int(W * 0.03), BRASS, ow=8)
	# gilza tagidagi rant
	d.rounded_rectangle((x0 - int(W * 0.03), bot - int(W * 0.06), x1 + int(W * 0.03), bot), int(W * 0.02), fill=(150, 116, 50, 255))
	# o'q uchi (ogival — mis), kontur bilan
	d.polygon([(x0 - 8, tip + 6), (x1 + 8, tip + 6), (x1 + 8, top + int(W * 0.10)),
			   (c, top - 8), (x0 - 8, top + int(W * 0.10))], fill=DARK)
	d.polygon([(x0, tip), (x1, tip), (x1, top + int(W * 0.10)),
			   (c, top), (x0, top + int(W * 0.10))], fill=COPPER)
	# yorug' chiziq (metall yarqirashi)
	d.line((c - w // 3, tip + 10, c - w // 3, bot - 10), fill=(232, 198, 120, 255), width=int(W * 0.02))
	return save(img, size, os.path.join(HUD, "icon_ammo.png"))


def _gun_base(img):
	"""Qurol siluetiga umumiy yorug'lik qirrasini qo'shish uchun yordamchi (hozir oddiy)."""
	return img


# =====================================================================
#  5) Avtomat ikonkasi — ixcham avtomatik qurol silueti (o'ngga qaragan)
# =====================================================================
def make_avtomat(size=128):
	img = new(size); d = ImageDraw.Draw(img)
	W = size * S
	def R(x): return int(W * x)
	cy = R(0.50)
	# qoramtir kontur (hamma qismlarni biroz kattaroq qora bilan chizamiz)
	def part(poly_or_box, fill, kind="poly"):
		if kind == "poly":
			d.polygon(poly_or_box, fill=fill)
		else:
			d.rounded_rectangle(poly_or_box, R(0.015), fill=fill)
	# --- kontur qatlam (qora) ---
	OL = 10
	# tana (receiver)
	d.rounded_rectangle((R(0.30) - OL, cy - R(0.085) - OL, R(0.66) + OL, cy + R(0.085) + OL), R(0.02), fill=DARK)
	# stvol
	d.rounded_rectangle((R(0.66) - OL, cy - R(0.035) - OL, R(0.90) + OL, cy + R(0.035) + OL), R(0.015), fill=DARK)
	# kundak (stock)
	d.polygon([(R(0.10) - OL, cy - R(0.06)), (R(0.30), cy - R(0.07) - OL),
			   (R(0.30), cy + R(0.07) + OL), (R(0.13) - OL, cy + R(0.10) + OL)], fill=DARK)
	# magazin (egri)
	d.polygon([(R(0.40) - OL, cy + R(0.07)), (R(0.52) + OL, cy + R(0.07)),
			   (R(0.58) + OL, cy + R(0.30) + OL), (R(0.44) - OL, cy + R(0.30) + OL)], fill=DARK)
	# dasta (grip)
	d.polygon([(R(0.55), cy + R(0.07)), (R(0.66), cy + R(0.07)),
			   (R(0.64), cy + R(0.26) + OL), (R(0.56), cy + R(0.26) + OL)], fill=DARK)
	# --- metall qatlam ---
	d.rounded_rectangle((R(0.30), cy - R(0.085), R(0.66), cy + R(0.085)), R(0.02), fill=STEEL)
	d.rounded_rectangle((R(0.66), cy - R(0.035), R(0.90), cy + R(0.035)), R(0.015), fill=STEEL)
	d.polygon([(R(0.10), cy - R(0.05)), (R(0.30), cy - R(0.06)),
			   (R(0.30), cy + R(0.06)), (R(0.13), cy + R(0.09))], fill=STEEL)
	d.polygon([(R(0.40), cy + R(0.075)), (R(0.52), cy + R(0.075)),
			   (R(0.575), cy + R(0.29)), (R(0.45), cy + R(0.29))], fill=STEEL)
	d.polygon([(R(0.555), cy + R(0.075)), (R(0.655), cy + R(0.075)),
			   (R(0.635), cy + R(0.25)), (R(0.565), cy + R(0.25))], fill=STEEL)
	# yorug' qirra (tepa)
	d.rectangle((R(0.30), cy - R(0.085), R(0.66), cy - R(0.055)), fill=STEEL_HI)
	d.rectangle((R(0.66), cy - R(0.035), R(0.90), cy - R(0.018)), fill=STEEL_HI)
	# old nishon (front sight)
	d.rectangle((R(0.80), cy - R(0.11), R(0.83), cy - R(0.085)), fill=STEEL)
	return save(img, size, os.path.join(HUD, "icon_avtomat.png"))


# =====================================================================
#  6) Snayper ikonkasi — uzun stvolli, durbinli (scope) miltiq silueti
# =====================================================================
def make_sniper(size=128):
	img = new(size); d = ImageDraw.Draw(img)
	W = size * S
	def R(x): return int(W * x)
	cy = R(0.52)
	OL = 10
	# --- kontur qatlam (qora) ---
	d.rounded_rectangle((R(0.26) - OL, cy - R(0.07) - OL, R(0.58) + OL, cy + R(0.07) + OL), R(0.02), fill=DARK)
	d.rounded_rectangle((R(0.58) - OL, cy - R(0.028) - OL, R(0.94) + OL, cy + R(0.028) + OL), R(0.012), fill=DARK)
	# durbin (scope)
	d.rounded_rectangle((R(0.30) - OL, cy - R(0.20) - OL, R(0.56) + OL, cy - R(0.13) + OL), R(0.02), fill=DARK)
	# kundak (cheek rest bilan)
	d.polygon([(R(0.06) - OL, cy - R(0.03)), (R(0.26), cy - R(0.075) - OL),
			   (R(0.26), cy + R(0.085) + OL), (R(0.16), cy + R(0.13) + OL), (R(0.08) - OL, cy + R(0.10))], fill=DARK)
	# dasta
	d.polygon([(R(0.48), cy + R(0.06)), (R(0.57), cy + R(0.06)),
			   (R(0.55), cy + R(0.24) + OL), (R(0.47), cy + R(0.24) + OL)], fill=DARK)
	# --- metall qatlam ---
	d.rounded_rectangle((R(0.26), cy - R(0.07), R(0.58), cy + R(0.07)), R(0.02), fill=STEEL)
	d.rounded_rectangle((R(0.58), cy - R(0.028), R(0.94), cy + R(0.028)), R(0.012), fill=STEEL)
	# durbin korpusi + krepyojlar
	d.rectangle((R(0.36), cy - R(0.13), R(0.40), cy - R(0.07)), fill=STEEL)
	d.rectangle((R(0.46), cy - R(0.13), R(0.50), cy - R(0.07)), fill=STEEL)
	d.rounded_rectangle((R(0.30), cy - R(0.20), R(0.56), cy - R(0.13)), R(0.02), fill=STEEL)
	d.ellipse((R(0.535), cy - R(0.195), R(0.575), cy - R(0.135)), fill=(30, 32, 28, 255))  # ko'z linzasi
	# kundak metall
	d.polygon([(R(0.06), cy - R(0.02)), (R(0.26), cy - R(0.065)),
			   (R(0.26), cy + R(0.075)), (R(0.16), cy + R(0.12)), (R(0.08), cy + R(0.09))], fill=STEEL)
	# dasta metall
	d.polygon([(R(0.485), cy + R(0.065)), (R(0.565), cy + R(0.065)),
			   (R(0.545), cy + R(0.23)), (R(0.475), cy + R(0.23))], fill=STEEL)
	# yorug' qirralar
	d.rectangle((R(0.30), cy - R(0.20), R(0.56), cy - R(0.175)), fill=STEEL_HI)  # scope tepasi
	d.rectangle((R(0.58), cy - R(0.028), R(0.94), cy - R(0.014)), fill=STEEL_HI) # stvol tepasi
	# bipod (old tayanch — 2 oyoq)
	d.line((R(0.86), cy + R(0.02), R(0.80), cy + R(0.20)), fill=STEEL, width=R(0.018))
	d.line((R(0.86), cy + R(0.02), R(0.92), cy + R(0.20)), fill=STEEL, width=R(0.018))
	return save(img, size, os.path.join(HUD, "icon_sniper.png"))


# =====================================================================
#  7) Logotip — «QAYTISH» qora fonini shaffofga aylantirish
# =====================================================================
def make_logo_transparent():
	src = os.path.join(MENU, "logo_qaytish_raw.png")
	if not os.path.exists(src):
		print("  [o'tkazib yuborildi] logo_qaytish_raw.png topilmadi")
		return None
	img = Image.open(src).convert("RGB")
	lum = img.convert("L")
	# qora (lum<=18) → to'liq shaffof; o'rtada yumshoq o'tish; matn/gerb → to'liq ko'rinadi
	alpha = lum.point(lambda v: 0 if v <= 18 else min(255, int((v - 18) * 6)))
	logo = img.convert("RGBA"); logo.putalpha(alpha)
	bbox = logo.getbbox()            # shaffof chetlarni qirqib tashlash
	if bbox:
		logo = logo.crop(bbox)
	# Yorqin fon (masalan menyu osmoni) ustida ham o'qilishi uchun orqasiga
	# yumshoq qoramtir "halo" (soya) qo'shamiz — logo layout'ini o'zgartirmaydi.
	pad = 64
	W, H = logo.width + pad * 2, logo.height + pad * 2
	out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	shadow_a = logo.split()[3].point(lambda a: int(a * 0.95))
	shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	shadow.paste((0, 0, 0, 255), (pad, pad), shadow_a)
	shadow = shadow.filter(ImageFilter.GaussianBlur(20))
	for _ in range(3):               # bir necha qatlam — quyuqroq, aniqroq halo
		out = Image.alpha_composite(out, shadow)
	out.alpha_composite(logo, (pad, pad))
	dst = os.path.join(MENU, "logo_qaytish.png")
	out.save(dst)
	return out


# =====================================================================
#  8) Tekstura: qum qoplari devori (tileable 512x512)
# =====================================================================
def make_sandbags(size=512):
	img = Image.new("RGB", (size, size), (46, 42, 36)); d = ImageDraw.Draw(img)
	rows = 8; rh = size // rows           # qator balandligi (512/8=64 → vertikal tileable)
	bw = 150; bh = 78                      # qop o'lchami
	tan = (150, 130, 96)
	for ri in range(rows + 1):
		y = ri * rh
		offset = (bw // 2) if (ri % 2) else 0   # g'isht naqshi
		x = -bw + offset
		while x < size + bw:
			# har qopni biroz tasodifiy rang bilan
			jit = random.randint(-16, 16)
			col = (max(0, tan[0] + jit), max(0, tan[1] + jit), max(0, tan[2] + jit))
			# qop ("yostiq") — yumaloq to'rtburchak; chetlardan oshsa, tileable bo'lishi uchun
			# qo'shimcha nusxa chap/o'ng tomonga ham chiziladi (while sikli buni qamrab oladi)
			d.rounded_rectangle((x + 4, y + 4, x + bw - 4, y + bh - 4), 26, fill=col,
								outline=(34, 30, 26), width=4)
			# tikuv chizig'i (o'rtada)
			d.line((x + 16, y + bh // 2, x + bw - 16, y + bh // 2), fill=(110, 94, 68), width=3)
			# soya (pastki yarmi quyuqroq)
			d.rounded_rectangle((x + 4, y + bh // 2, x + bw - 4, y + bh - 4), 20,
								fill=None, outline=(90, 78, 58), width=2)
			x += bw
	# umumiy don (noise) — kanvas to'qimasi
	noise = Image.effect_noise((size, size), 26).convert("RGB")
	img = Image.blend(img, noise, 0.10)
	# yumshoq qorong'i vinetka emas — tekstura tekis qolsin
	img.save(os.path.join(TEX, "sandbags.png"))
	return img


# =====================================================================
#  9) Tekstura: zanglagan gofrirovka (corrugated) metall (tileable 512x512)
# =====================================================================
def make_rusted_metal(size=512):
	base = Image.new("RGB", (size, size), (120, 72, 46)); px = base.load()
	period = 64.0   # 512/64=8 ridge → gorizontal tileable
	for x in range(size):
		# gofr (sinus) yorug'lik
		s = 0.62 + 0.38 * (0.5 + 0.5 * math.sin(2 * math.pi * x / period))
		r = int(118 * s + 20); g = int(72 * s + 12); b = int(46 * s + 8)
		for y in range(size):
			px[x, y] = (min(255, r), min(255, g), min(255, b))
	d = ImageDraw.Draw(base, "RGBA")
	# zang dog'lari (turli ton, yarim-shaffof, keyin blur)
	blot = Image.new("RGBA", (size, size), (0, 0, 0, 0)); bd = ImageDraw.Draw(blot)
	tones = [(168, 96, 44, 90), (74, 46, 30, 110), (150, 120, 86, 70), (96, 54, 34, 100)]
	for _ in range(160):
		cx, cy = random.randint(0, size), random.randint(0, size)
		rr = random.randint(8, 40)
		col = random.choice(tones)
		bd.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=col)
		# tileable bo'lishi uchun chetdan oshganini qarama-qarshi tomonga ham
		for ox in (-size, size):
			bd.ellipse((cx + ox - rr, cy - rr, cx + ox + rr, cy + rr), fill=col)
		for oy in (-size, size):
			bd.ellipse((cx - rr, cy + oy - rr, cx + rr, cy + oy + rr), fill=col)
	blot = blot.filter(ImageFilter.GaussianBlur(6))
	base = Image.alpha_composite(base.convert("RGBA"), blot).convert("RGB")
	d = ImageDraw.Draw(base)
	# bolt teshiklari (qator bo'ylab, tileable joylar)
	for bx in range(32, size, 128):
		for by in range(40, size, 160):
			d.ellipse((bx - 7, by - 7, bx + 7, by + 7), fill=(40, 26, 18), outline=(150, 120, 86), width=2)
	# don
	noise = Image.effect_noise((size, size), 22).convert("RGB")
	base = Image.blend(base, noise, 0.10)
	base.save(os.path.join(TEX, "rusted_metal.png"))
	return base


# =====================================================================
# 10) Backdrop: keng, gorizontal-seamless jang maydoni ufqi (arena devorlari uchun)
#     Tepada g'amgin osmon (amber gradient), ufqda tutun + vayrona siluetlari, pastda tuproq.
# =====================================================================
def make_backdrop(W=2048, H=512):
	random.seed(31)
	img = Image.new("RGB", (W, H), (0, 0, 0)); px = img.load()
	horizon = int(H * 0.62)
	top = (40, 46, 58); hor = (158, 100, 56)       # osmon: tepa -> ufq
	g_top = (60, 48, 36); g_bot = (24, 19, 14)     # tuproq: ufq -> past
	for y in range(H):
		if y < horizon:
			t = y / max(1, horizon)
			c = (int(top[0] + (hor[0] - top[0]) * t),
				 int(top[1] + (hor[1] - top[1]) * t),
				 int(top[2] + (hor[2] - top[2]) * t))
		else:
			t = (y - horizon) / max(1, H - horizon)
			c = (int(g_top[0] + (g_bot[0] - g_top[0]) * t),
				 int(g_top[1] + (g_bot[1] - g_top[1]) * t),
				 int(g_top[2] + (g_bot[2] - g_top[2]) * t))
		for x in range(W):
			px[x, y] = c
	# quyosh yorug'i ufqda
	glow = Image.new("RGBA", (W, H), (0, 0, 0, 0)); gd = ImageDraw.Draw(glow)
	gx = W // 2
	gd.ellipse((gx - 280, horizon - 130, gx + 280, horizon + 130), fill=(235, 155, 75, 130))
	glow = glow.filter(ImageFilter.GaussianBlur(70))
	img = Image.alpha_composite(img.convert("RGBA"), glow).convert("RGB")
	# tutun ustunlari (seamless: x, x-W, x+W)
	smoke = Image.new("RGBA", (W, H), (0, 0, 0, 0)); sd = ImageDraw.Draw(smoke)
	for _ in range(7):
		sx = random.randint(0, W); ty = random.randint(int(H * 0.12), int(H * 0.40))
		wd = random.randint(34, 76)
		for ox in (0, -W, W):
			sd.polygon([(sx + ox - wd, horizon), (sx + ox + wd, horizon),
						(sx + ox + wd // 2, ty), (sx + ox - wd // 2, ty)], fill=(44, 40, 42, 95))
	smoke = smoke.filter(ImageFilter.GaussianBlur(30))
	img = Image.alpha_composite(img.convert("RGBA"), smoke).convert("RGB")
	# ufq siluetlari: vayrona devor / singan daraxt / qoldiq (seamless)
	d = ImageDraw.Draw(img)
	sil = (20, 18, 20)
	x = 0
	while x < W:
		kind = random.random()
		bw = random.randint(24, 96)
		bh = random.randint(int(H * 0.05), int(H * 0.17))
		ty = horizon - bh
		for ox in (0, -W, W):
			xx = x + ox
			if kind < 0.42:        # vayrona devor bo'lagi (notekis tepa)
				d.rectangle((xx, ty, xx + bw, horizon), fill=sil)
				d.polygon([(xx, ty), (xx + bw // 3, ty - bh // 3),
						   (xx + 2 * bw // 3, ty + bh // 6), (xx + bw, ty)], fill=sil)
			elif kind < 0.72:      # singan daraxt / ustun
				tw = max(3, bw // 8); cx = xx + bw // 2
				d.rectangle((cx - tw, horizon - int(bh * 1.7), cx + tw, horizon), fill=sil)
			else:                  # past qoldiq tepalik
				d.ellipse((xx, horizon - bh // 2, xx + bw, horizon + bh // 3), fill=sil)
		x += random.randint(46, 140)
	# ufq dud-haze (yumshoq band)
	haze = Image.new("RGBA", (W, H), (0, 0, 0, 0)); hd = ImageDraw.Draw(haze)
	hd.rectangle((0, horizon - 34, W, horizon + 30), fill=(160, 126, 102, 70))
	haze = haze.filter(ImageFilter.GaussianBlur(22))
	img = Image.alpha_composite(img.convert("RGBA"), haze).convert("RGB")
	# umumiy don
	noise = Image.effect_noise((W, H), 16).convert("RGB")
	img = Image.blend(img, noise, 0.05)
	img.save(os.path.join(TEX, "battle_backdrop.png"))
	print("  backdrop: battle_backdrop.png %dx%d" % (W, H))
	return img


# =====================================================================
# 11) Panorama osmon (2:1 equirektangular) — arena atrofidagi 360° jang ufqi.
#     PanoramaSkyMaterial uchun: cheksizlikda render bo'ladi -> qiya burchakda
#     streaking BO'LMAYDI (tekis devorga rasm qo'yishdagi muammoning yechimi).
#     Horizon v=0.5 da; u bo'ylab 360° seamless.
# =====================================================================
def make_sky_panorama(W=2048, H=1024):
	random.seed(41)
	img = Image.new("RGB", (W, H), (0, 0, 0)); px = img.load()
	horizon = H // 2
	zenith = (26, 32, 46); skyhor = (158, 98, 54)     # osmon: zenit -> ufq (amber)
	grnd_hor = (66, 50, 36); nadir = (12, 10, 8)       # ufqdan past: tuproq -> qorong'i
	for y in range(H):
		if y <= horizon:
			t = (y / max(1, horizon)) ** 1.8           # amber ufqqa yaqin to'planadi
			c = (int(zenith[0] + (skyhor[0] - zenith[0]) * t),
				 int(zenith[1] + (skyhor[1] - zenith[1]) * t),
				 int(zenith[2] + (skyhor[2] - zenith[2]) * t))
		else:
			t = ((y - horizon) / max(1, H - horizon)) ** 0.8
			c = (int(grnd_hor[0] + (nadir[0] - grnd_hor[0]) * t),
				 int(grnd_hor[1] + (nadir[1] - grnd_hor[1]) * t),
				 int(grnd_hor[2] + (nadir[2] - grnd_hor[2]) * t))
		for x in range(W):
			px[x, y] = c
	# quyosh yorug'i (bitta azimutda, ufq yaqinida)
	glow = Image.new("RGBA", (W, H), (0, 0, 0, 0)); gd = ImageDraw.Draw(glow)
	gx = int(W * 0.5)
	gd.ellipse((gx - 240, horizon - 150, gx + 240, horizon + 150), fill=(240, 160, 80, 150))
	glow = glow.filter(ImageFilter.GaussianBlur(80))
	img = Image.alpha_composite(img.convert("RGBA"), glow).convert("RGB")
	# tutun ustunlari (ufqdan tepaga), 360° seamless
	smoke = Image.new("RGBA", (W, H), (0, 0, 0, 0)); sd = ImageDraw.Draw(smoke)
	for _ in range(10):
		sx = random.randint(0, W); ty = random.randint(int(H * 0.10), int(H * 0.40)); wd = random.randint(30, 70)
		for ox in (0, -W, W):
			sd.polygon([(sx + ox - wd, horizon), (sx + ox + wd, horizon),
						(sx + ox + wd // 2, ty), (sx + ox - wd // 2, ty)], fill=(40, 36, 40, 80))
	smoke = smoke.filter(ImageFilter.GaussianBlur(34))
	img = Image.alpha_composite(img.convert("RGBA"), smoke).convert("RGB")
	# ufq siluetlari (vayrona / daraxt / qoldiq), 360° seamless
	d = ImageDraw.Draw(img); sil = (18, 16, 18)
	x = 0
	while x < W:
		kind = random.random(); bw = random.randint(18, 80)
		bh = random.randint(int(H * 0.02), int(H * 0.085)); ty = horizon - bh
		for ox in (0, -W, W):
			xx = x + ox
			if kind < 0.4:
				d.rectangle((xx, ty, xx + bw, horizon + 4), fill=sil)
				d.polygon([(xx, ty), (xx + bw // 3, ty - bh // 3),
						   (xx + 2 * bw // 3, ty + bh // 6), (xx + bw, ty)], fill=sil)
			elif kind < 0.7:
				tw = max(2, bw // 9); cx = xx + bw // 2
				d.rectangle((cx - tw, horizon - int(bh * 1.8), cx + tw, horizon + 4), fill=sil)
			else:
				d.ellipse((xx, horizon - bh // 2, xx + bw, horizon + bh // 2), fill=sil)
		x += random.randint(30, 90)
	# ufq haze (yumshoq band)
	haze = Image.new("RGBA", (W, H), (0, 0, 0, 0)); hd = ImageDraw.Draw(haze)
	hd.rectangle((0, horizon - 20, W, horizon + 24), fill=(170, 130, 100, 70))
	haze = haze.filter(ImageFilter.GaussianBlur(26))
	img = Image.alpha_composite(img.convert("RGBA"), haze).convert("RGB")
	noise = Image.effect_noise((W, H), 12).convert("RGB")
	img = Image.blend(img, noise, 0.04)
	img.save(os.path.join(TEX, "sky_panorama.png"))
	print("  sky panorama: sky_panorama.png %dx%d" % (W, H))
	return img


# =====================================================================
#  Kontakt-varaq (preview) — barcha UI elementlarni bitta rasmda ko'rish uchun
# =====================================================================
def make_contact(icons, logo):
	cols = 3
	cell = 150
	rows = (len(icons) + cols - 1) // cols + 2  # ikonkalar + logo bloki
	W = cols * cell
	H = rows * cell
	sheet = Image.new("RGBA", (W, H), (90, 92, 88, 255))   # o'rta kulrang fon (shaffoflik ko'rinsin)
	d = ImageDraw.Draw(sheet)
	for i, (name, im) in enumerate(icons):
		cx = (i % cols) * cell; cy = (i // cols) * cell
		thumb = im.copy(); thumb.thumbnail((cell - 30, cell - 40))
		sheet.alpha_composite(thumb, (cx + (cell - thumb.width) // 2, cy + 8))
		d.text((cx + 8, cy + cell - 18), name, fill=(255, 255, 255, 255))
	# logo (pastki ikki qator)
	if logo is not None:
		ly = ((len(icons) + cols - 1) // cols) * cell
		lg = logo.copy(); lg.thumbnail((W - 40, 2 * cell - 30))
		sheet.alpha_composite(lg, ((W - lg.width) // 2, ly + (2 * cell - lg.height) // 2))
	sheet.convert("RGB").save(os.path.join(ART, "_preview_ui.png"))


if __name__ == "__main__":
	print("HUD / UI grafika generatsiya qilinmoqda...")
	ch = make_crosshair()
	hm = make_hitmarker()
	hp = make_health()
	am = make_ammo()
	av = make_avtomat()
	sn = make_sniper()
	print("  ikonkalar tayyor: crosshair, hitmarker, health, ammo, avtomat, sniper")
	logo = make_logo_transparent()
	print("  logo shaffof:", "ok" if logo else "yo'q")
	make_sandbags()
	make_rusted_metal()
	make_backdrop()
	make_sky_panorama()
	print("  teksturalar: sandbags, rusted_metal (tileable), battle_backdrop, sky_panorama")
	make_contact([("crosshair", ch), ("hitmarker", hm), ("health", hp),
				  ("ammo", am), ("avtomat", av), ("sniper", sn)], logo)
	print("  preview: assets/art/_preview_ui.png")
	print("Tayyor.")
