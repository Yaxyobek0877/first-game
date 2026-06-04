# First Game — FPS + Adventure 🎮

Birinchi shaxs (FPS) otishma + sarguzasht o'yini. **Godot 4.6 / GDScript** bilan
o'rganish maqsadida qurilmoqda. Bu mening birinchi o'yin loyiham.

---

## 🎯 Hozir nima ishlaydi (1-bosqich: Vertical Slice)

- ✅ FPS yurish (WASD), yugurish (Shift), sakrash (Space)
- ✅ Sichqoncha bilan atrofga qarash
- ✅ Otish (hitscan / lahzali nur) + uchqun effekti
- ✅ Otiladigan nishonlar (zarar olib, yo'qoladi)
- ✅ HUD: o'q-dori, jon, ochko
- ✅ Greybox arena (yer, devorlar, panalar)

## 🕹️ Boshqaruv

| Tugma | Vazifa |
|-------|--------|
| `W A S D` | Yurish |
| `Shift` | Yugurish |
| `Space` | Sakrash |
| `Sichqoncha` | Qarash |
| `Chap tugma` | Otish |
| `R` | Qayta o'qlash |
| `Esc` | Sichqonchani bo'shatish (pauza) |

## ▶️ Qanday ishga tushirish

1. Godot 4.6 ni oching.
2. **Import** tugmasini bosib, shu papkadagi `project.godot` faylini tanlang.
3. `F5` (yoki yuqoridagi ▶️ tugma) bosib o'yinni ishga tushiring.

---

## 📁 Papka tuzilishi

```
first_game/
├── project.godot          # Loyiha sozlamalari + boshqaruv (input) xaritasi
├── icon.svg               # Loyiha ikonkasi
├── scenes/                # Sahnalar (.tscn) — tugunlar daraxti
│   ├── main.tscn          #   Bosh sahna (hammasini birlashtiradi)
│   ├── player/            #   O'yinchi
│   ├── world/             #   Arena / dunyo
│   ├── enemies/           #   Nishon / dushmanlar
│   └── ui/                #   HUD / menyular
├── scripts/               # GDScript kodlar (.gd)
│   ├── autoload/events.gd #   Global signal bus (decoupling)
│   ├── player/            #   player.gd, weapon.gd
│   ├── enemies/           #   target_dummy.gd
│   └── ui/                #   hud.gd
└── assets/                # Modellar, teksturalar, tovushlar (keyin to'ldiriladi)
```

## 🏗️ Arxitektura tamoyillari

- **Signal bus (`Events`)** — sahnalar bir-birini to'g'ridan-to'g'ri bilmaydi.
  Qurol `Events.ammo_changed` yuboradi, HUD esa uni eshitadi. Bu ulanishlarni
  ajratadi va keyinroq kengaytirishni osonlashtiradi.
- **Scene tuzilishi** — har bir mantiqiy bo'lak alohida sahna (player, enemy, hud).
- **`@export` o'zgaruvchilar** — tezlik, zarar, jon kabi sozlamalar Inspector'dan
  o'zgartiriladi (kodga tegmasdan sinab ko'rish uchun).

---

## 🗺️ Yo'l xaritasi

- [x] **0. Asoslar** — loyiha, tuzilish, input
- [x] **1. Vertical Slice** — FPS yadro, otish, nishon, HUD
- [ ] **2. Jang tizimi** — AI dushman, qurol turlari, jon/zarar balansi
- [ ] **3. Arena janglari** — to'lqinli dushmanlar, bir nechta arena, ochko
- [ ] **4. Sarguzasht/syujet** — darajalar, hikoya, NPC, maqsadlar
- [ ] **5. Sayqal** — tovush, effektlar, menyu, saqlash, optimizatsiya
