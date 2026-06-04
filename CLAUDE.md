# CLAUDE.md — First Game (FPS + Adventure)

> **Yangi sessiyada avval shu faylni o'qing.** Bu loyiha konteksti — Claude Code uni avtomatik yuklaydi.
> Foydalanuvchi **o'zbek tilida (lotin yozuvi)** muloqot qiladi → javoblar va kod izohlari ham o'zbekcha.
> Rol taqsimoti: **foydalanuvchi yo'naltiradi, Claude quradi va tushuntiradi.**

---

## 🎯 Loyiha maqsadi (vision)

Bu — foydalanuvchining **birinchi o'yini**. Maqsad: AI yordamida o'yin yaratishni o'rganish.

- **Janr:** birinchi shaxs (FPS) **otishma + sarguzasht/syujet**.
- **Asosiy mexanika:** alohida **arenalarda** janglar, hikoya/scenariy bilan bog'langan.
- **Dvijok:** **Godot 4.6**, **GDScript** (Mono/C# emas).
- **Tamoyil:** professional, bosqichma-bosqich ("vertical slice" → kengaytirish). Sifat va o'rganish birinchi o'rinda.

---

## 📊 Hozirgi holat

| Bosqich | Tavsif | Holat |
|---------|--------|-------|
| **0. Asoslar** | Loyiha, papka tuzilishi, input xaritasi, `Events` autoload | ✅ Tugadi |
| **1. Vertical Slice** | FPS yurish/qarash/sakrash, hitscan otish, nishonlar, HUD | ✅ Tugadi va tekshirildi |
| **2. Jang tizimi** | AI dushman, qurol turlari, jon/zarar balansi | ⏭️ Keyingi |
| 3. Arena janglari | To'lqinli dushmanlar, bir nechta arena, ochko | ⬜ |
| 4. Sarguzasht/syujet | Darajalar, hikoya, NPC, maqsadlar, o'tish | ⬜ |
| 5. Sayqal | Tovush, effektlar, menyu, saqlash, optimizatsiya | ⬜ |

**1-bosqich `--headless` rejimida 120 kadr toza ishladi** (script/sahna xatosi yo'q).

---

## 🗺️ Aniq maqsadlar (bosqichlarning konkret natijalari)

**2-bosqich — Jang tizimi (keyingi):**
- [ ] Harakatlanadigan AI dushman: `CharacterBody3D` + `NavigationAgent3D`, o'yinchini ko'rib, tomon yuradi.
- [ ] Dushman hujum qiladi (otish yoki yaqin masofa) → o'yinchi jon yo'qotadi.
- [ ] O'yinchi o'lganda: "O'yin tugadi" ekrani + qayta boshlash.
- [ ] `target_dummy` ni real dushman bilan almashtirish (lekin nishon ham qoladi — mashq uchun).
- [ ] Kamida 2 qurol turi (masalan: tez/zaif vs sekin/kuchli), `1`/`2` bilan almashtirish.

**3-bosqich — Arena janglari:** to'lqin (wave) tizimi, dushman spawn nuqtalari, ochko/rekord, 2-3 arena sahnasi, arenadan arenaga o'tish.

**4-bosqich — Sarguzasht/syujet:** darajalar ketma-ketligi, oddiy hikoya/dialog, NPC, maqsadlar (objective), daraja o'tish eshigi/portali.

**5-bosqich — Sayqal:** otish/qadam tovushlari, muzzle flash va tracer, asosiy menyu + pauza menyusi, saqlash/yuklash, optimizatsiya.

---

## 🏗️ Arxitektura

- **Signal bus (`Events` autoload)** — `scripts/autoload/events.gd`. Sahnalar bir-birini bilmaydi; signal orqali "gaplashadi" (decoupling). Signallar: `ammo_changed`, `player_health_changed`, `enemy_died`. Yangi global hodisalarni shu yerga qo'shing.
- **Scene-per-concept** — har bir mantiqiy bo'lak alohida `.tscn` (player, world, enemy, ui).
- **`@export` tunables** — tezlik, zarar, jon kabi qiymatlar Inspector orqali sozlanadi (kodga tegmasdan).
- **Player** — `CharacterBody3D`; harakat `_physics_process` ichida, qarash `_unhandled_input` ichida.
- **Weapon** — Camera3D ostida; **hitscan** (`RayCast3D.force_raycast_update()`). Agar nishonda `take_damage(amount)` bo'lsa zarar beradi (duck typing: `has_method`).

---

## 📁 Tuzilish

```
first_game/
├── project.godot          # Sozlamalar + input xaritasi + Events autoload
├── CLAUDE.md              # (shu fayl) loyiha konteksti
├── README.md              # Inson uchun hujjat + boshqaruv
├── icon.svg
├── scenes/
│   ├── main.tscn          # Bosh sahna: arena + player + 3 nishon + HUD
│   ├── player/player.tscn # CharacterBody3D > Head > Camera3D > Weapon(RayCast3D, GunMesh, Muzzle)
│   ├── world/arena.tscn   # WorldEnvironment + Sun + CSGBox3D yer/devor/panalar
│   ├── enemies/target_dummy.tscn
│   └── ui/hud.tscn        # Crosshair, Ammo, Health, Score
└── scripts/
    ├── autoload/events.gd
    ├── player/{player.gd, weapon.gd}
    ├── enemies/target_dummy.gd
    └── ui/hud.gd
```

## 🎮 Boshqaruv

`WASD` yurish · sichqoncha qarash · chap tugma otish · `Shift` yugurish · `Space` sakrash · `R` qayta o'qlash · `Esc` sichqonchani bo'shatish.

---

## ▶️ Ishga tushirish va tekshirish

Godot 4.6 winget orqali o'rnatilgan. To'liq yo'l:
```
C:\Users\hcsah\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64.exe
```
(PATH ichida `godot` aliasi ham bor — terminal qayta ochilganida ishlaydi.)

- **Muharrirni ochish:** `godot --path D:\first_game --editor`
- **O'yinni ishga tushirish:** muharrir ichida `F5`, yoki `godot --path D:\first_game`
- **Headless tekshiruv (xato bormi?):** `godot --headless --path D:\first_game --quit-after 120`
  → toza bo'lsa faqat engine bannerini chiqaradi, `ERROR:` / `SCRIPT ERROR:` qatorlar bo'lmaydi.

---

## 🔗 Repozitoriya

- GitHub (public): https://github.com/Yaxyobek0877/first-game
- Har bosqich yoki muhim o'zgartirishdan keyin commit qiling va `git push` qiling.

---

## 🧭 Yangi sessiyada qanday davom ettirish

1. Shu `CLAUDE.md` va xotira indeksini o'qing.
2. Headless tekshiruvni ishlatib, asos hali ham toza ekanini tasdiqlang.
3. "Hozirgi holat" jadvalidan qayerda turganini ko'ring.
4. Foydalanuvchidan qaysi bosqich/yo'nalishdan davom etishni so'rang (o'zbekcha).

## ✍️ Konventsiyalar

- GDScript; satr boshi **tab** bilan (bo'shliq/space emas — Godot standarti).
- Izohlar **o'zbekcha (lotin yozuvi)** — Kirill harflari aralashib ketmasligiga e'tibor bering.
- Yangi sahna/skript qo'shganda shu papka tuzilishiga amal qiling.
- O'zgartirishdan keyin **headless tekshiruvni** ishlatib, hech narsa buzilmaganini tasdiqlang.
