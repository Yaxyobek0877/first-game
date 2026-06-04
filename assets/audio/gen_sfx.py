# -*- coding: utf-8 -*-
"""
Jang/holat SFX generatori (protsedural, faqat Python standart kutubxonasi).
gen_music.py dan ALOHIDA — chunki u boshqa terminalda tahrirlanishi mumkin.

  python assets/audio/gen_sfx.py

Natija (16-bit mono WAV, SFX shinasi uchun):
  enemy_death.wav   — dushman o'lganda (pasayuvchi nola + gup)
  player_hurt.wav   — o'yinchi zarar olganda (qisqa "uf")
  hitmarker.wav     — o'q nishonga tekkanda ("tink" — qoniqarli feedback)
  weapon_switch.wav — qurol almashtirilganda (mexanik "klak-klak")
  player_death.wav  — o'yinchi halok bo'lganda (g'amgin sting)
  wave_start.wav    — yangi to'lqin boshlanganda (jang shoxi/signal)

Hammasi `scripts/autoload/sfx.gd` orqali Events signallariga ulanadi.
"""
import wave, struct, math, random, os

SR = 22050
OUT = os.path.dirname(os.path.abspath(__file__))


def write_wav(path, samples):
	with wave.open(path, "w") as w:
		w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
		fr = bytearray()
		for s in samples:
			v = int(max(-1.0, min(1.0, s)) * 32767)
			fr += struct.pack("<h", v)
		w.writeframes(bytes(fr))
	print("SFX:", os.path.basename(path), "%.2fs" % (len(samples) / SR))


def noise():
	return random.uniform(-1.0, 1.0)


def soft_clip(x):
	return math.tanh(x * 1.1)


def normalize(buf, peak=0.92):
	m = max((abs(s) for s in buf), default=1.0)
	return buf if m < 1e-6 else [s * (peak / m) for s in buf]


def make_explosion():
	"""Granata portlashi — boshda 'qars' (yuqori shovqin), past 'bo'm', uzun 'gumburlash' dumi."""
	random.seed(201)
	dur = 1.15; n = int(SR * dur); out = [0.0] * n
	for i in range(n):
		t = i / SR
		crack = noise() * math.exp(-t * 38.0) * 0.85                     # boshlang'ich yorilish
		f = 95.0 - 60.0 * min(1.0, t / 0.5)                             # tushuvchi 'bo'm'
		boom = math.sin(2 * math.pi * f * t) * math.exp(-t * 3.0) * 0.7
		rumble = noise() * math.exp(-t * 2.1) * 0.45                     # past gumburlash dumi
		out[i] = soft_clip(crack + boom + rumble)
	return normalize(out, 0.97)


def make_grenade_throw():
	"""Tashlash 'shuv' (whoosh) — qisqa filtrlangan shovqin to'lqini."""
	random.seed(202)
	dur = 0.28; n = int(SR * dur); out = [0.0] * n
	prev = 0.0
	for i in range(n):
		t = i / SR
		env = math.sin(math.pi * min(1.0, t / dur))      # ko'tarilib-tushadigan
		lp = prev * 0.85 + noise() * 0.15                # past-o'tkazgich (yumshoq shuv)
		prev = lp
		out[i] = lp * env * 0.6
	return normalize(out, 0.7)


def make_grenade_bounce():
	"""Granata yerga tegib 'tink' — qisqa metall ohang."""
	dur = 0.09; n = int(SR * dur); out = [0.0] * n
	for i in range(n):
		t = i / SR
		env = math.exp(-t * 55.0)
		s = math.sin(2 * math.pi * 540.0 * t) * 0.5 + math.sin(2 * math.pi * 870.0 * t) * 0.3
		out[i] = (s + noise() * 0.2) * env * 0.6
	return out


def make_flashbang():
	"""Flashbang — keskin 'qars' (pop) + jiringlovchi yuqori dum (quloqqa 'ring')."""
	random.seed(203)
	dur = 0.6; n = int(SR * dur); out = [0.0] * n
	for i in range(n):
		t = i / SR
		pop = noise() * math.exp(-t * 50.0) * 0.9                       # keskin yorilish
		ring = math.sin(2 * math.pi * 4200.0 * t) * math.exp(-t * 4.0) * 0.35  # yuqori jiringlash
		out[i] = soft_clip(pop + ring)
	return normalize(out, 0.95)


def make_enemy_death():
	"""Pasayuvchi nola (180->90 Hz) + oxirida yumshoq 'gup' (jasad yiqilishi)."""
	random.seed(101)
	dur = 0.55; n = int(SR * dur); out = [0.0] * n
	for i in range(n):
		t = i / SR
		f = 180.0 - 95.0 * (t / dur)                  # tushuvchi ohang
		vib = 1.0 + 0.025 * math.sin(2 * math.pi * 6.0 * t)
		env = math.exp(-t * 3.2)
		groan = math.sin(2 * math.pi * f * vib * t) * 0.55 + math.sin(2 * math.pi * f * 2.0 * t) * 0.12
		out[i] = groan * env
	# gup (kick-simon) ~0.30s da
	k0 = int(SR * 0.30)
	for i in range(int(SR * 0.18)):
		t = i / SR
		f = 90.0 * math.exp(-t * 22.0) + 40.0
		if k0 + i < n:
			out[k0 + i] += math.sin(2 * math.pi * f * t) * math.exp(-t * 11.0) * 0.5
	return out


def make_player_hurt():
	"""Qisqa past 'uf' — shovqin + past ohang, tez so'nadi."""
	random.seed(102)
	dur = 0.20; n = int(SR * dur); out = [0.0] * n
	for i in range(n):
		t = i / SR
		env = math.exp(-t * 14.0)
		tone = math.sin(2 * math.pi * 160.0 * (1.0 - 0.4 * t / dur) * t) * 0.5
		out[i] = (tone + noise() * 0.35) * env
	return out


def make_hitmarker():
	"""Qisqa yorqin 'tink' — ikki baland sinus, juda tez so'nadi (hit feedback)."""
	dur = 0.07; n = int(SR * dur); out = [0.0] * n
	for i in range(n):
		t = i / SR
		env = math.exp(-t * 70.0)
		s = math.sin(2 * math.pi * 1650.0 * t) * 0.5 + math.sin(2 * math.pi * 2400.0 * t) * 0.3
		out[i] = s * env * 0.7
	return out


def make_weapon_switch():
	"""Mexanik 'klak-klak' — ikki qisqa shovqin-klik (qurol almashtirish)."""
	random.seed(103)
	dur = 0.15; n = int(SR * dur); out = [0.0] * n
	for click_t in (0.0, 0.075):
		c0 = int(SR * click_t)
		for i in range(int(SR * 0.04)):
			t = i / SR
			env = math.exp(-t * 90.0)
			s = noise() * 0.6 + math.sin(2 * math.pi * 320.0 * t) * 0.4
			if c0 + i < n:
				out[c0 + i] += s * env * 0.6
	return out


def make_player_death():
	"""G'amgin sting — past ohang (110->65) + sekin shovqin to'lqini, uzun dum."""
	random.seed(104)
	dur = 0.95; n = int(SR * dur); out = [0.0] * n
	for i in range(n):
		t = i / SR
		f = 110.0 - 45.0 * (t / dur)
		env = math.exp(-t * 2.0)
		swell = math.sin(math.pi * min(1.0, t / 0.4)) * 0.3      # shovqin to'lqini
		tone = math.sin(2 * math.pi * f * t) * 0.5 + math.sin(2 * math.pi * f * 1.5 * t) * 0.2
		out[i] = (tone * env + noise() * swell * math.exp(-t * 3.0) * 0.4)
	return out


def make_wave_start():
	"""Jang shoxi (signal) — past 'brass' (saw+sinus), kvinta bilan, vibrato."""
	random.seed(105)
	dur = 0.75; n = int(SR * dur); out = [0.0] * n
	for f0 in (147.0, 220.0):   # D3 + A3 (kvinta) — shox chaqirig'i
		for i in range(n):
			t = i / SR
			vib = 1.0 + 0.01 * math.sin(2 * math.pi * 5.0 * t)
			ang = f0 * vib * t
			saw = 2.0 * (ang % 1.0) - 1.0
			sine = math.sin(2 * math.pi * ang)
			# attack 0.05, sustain, release oxirida
			env = min(1.0, t / 0.05) * math.exp(-t * 1.4)
			out[i] += (saw * 0.4 + sine * 0.6) * env * 0.22
	return out


if __name__ == "__main__":
	write_wav(os.path.join(OUT, "enemy_death.wav"), make_enemy_death())
	write_wav(os.path.join(OUT, "player_hurt.wav"), make_player_hurt())
	write_wav(os.path.join(OUT, "hitmarker.wav"), make_hitmarker())
	write_wav(os.path.join(OUT, "weapon_switch.wav"), make_weapon_switch())
	write_wav(os.path.join(OUT, "player_death.wav"), make_player_death())
	write_wav(os.path.join(OUT, "wave_start.wav"), make_wave_start())
	write_wav(os.path.join(OUT, "explosion.wav"), make_explosion())
	write_wav(os.path.join(OUT, "grenade_throw.wav"), make_grenade_throw())
	write_wav(os.path.join(OUT, "grenade_bounce.wav"), make_grenade_bounce())
	write_wav(os.path.join(OUT, "flashbang.wav"), make_flashbang())
	print("DONE")
