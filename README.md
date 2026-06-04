# First Game — «QAYTISH» 🎮

Birinchi shaxs (FPS) otishma + sarguzasht o'yini — **Godot 4.6 / GDScript**.
1-jahon urushi uslubidagi arena janglari; **«QAYTISH»** hikoyasi asosida (kelajakdan
o'tmishga qaytgan general taqdirni o'zgartirishga urinadi). Bu — mening birinchi o'yin loyiham.

> 📖 To'liq hikoya: [`docs/SENARIY.md`](docs/SENARIY.md) · 🧭 Loyiha konteksti (dasturchi/AI uchun): [`CLAUDE.md`](CLAUDE.md)

---

## 🎮 Hozir nima ishlaydi

Hozirgi o'yin — **arena "wave shooter"**: Kron askarlari to'lqin-to'lqin hujum qiladi, siz ularni qirib ochko va rekord yig'asiz.

**Jang:**
- Tirik AI dushman — **6 rol** (qo'riqchi, patrul, miltiqchi, snayper, hujumchi, qanotchi); ko'rish konusi + ovozni eshitish + LOS bilan sezadi, navmesh bo'ylab harakatlanadi
- **To'lqin (wave) tizimi** — har to'lqin og'irlashadi; ochko + rekord (saqlanadi)
- **3 qurol:** Topponcha · Avtomat · Snayper (durbin/zoom) — Avatar/Jihoz ekranida 2 slotga tanlanadi
- **Granata:** frag · tutun · flash
- Portlash/effektlar, tracer, muzzle flash, qon, jasadlar, kamera silkinishi
- Jon regeni, zarar chaqnashi, hit-marker, headshot (bosh ×2.5)

**Harakat (player):**
- Yurish/yugurish/sakrash · cho'kkalash · yotish · **sirpanish (slide)** · **egilish (lean)** · minoraga **narvondan chiqish**

**UI / tizim:**
- Bosh menyu · Avatar/Jihoz · Sozlamalar (ovoz/sezgirlik/ekran/FPS) · pauza · "O'yin tugadi"
- Fon musiqasi + jang ovozlari (protsedural)

## 🕹️ Boshqaruv

| Tugma | Vazifa | Tugma | Vazifa |
|-------|--------|-------|--------|
| `W A S D` | Yurish | `Chap tugma` | Otish |
| `Shift` | Yugurish | `O'ng tugma` | Mo'ljal / zoom |
| `Space` | Sakrash | `R` | Qayta o'qlash |
| `Ctrl` | Cho'kkalash | `1` / `2` / g'ildirak | Qurol almashtirish |
| `Ctrl` ×2 | Sirpanish (slide) | `G` | Granata tashlash |
| `Z` | Yotish (toggle) | `4` | Granata turini almashtirish |
| `Q` / `E` | Egilish (chap/o'ng) | `Esc` | Pauza |
| `W` (narvonda) | Chiqish / tushish | `Sichqoncha` | Qarash |

## ▶️ Ishga tushirish

1. Godot 4.6 da `project.godot` ni oching (yoki **Import** qiling).
2. `F5` — o'yin **bosh menyudan** boshlanadi.

Terminaldan: `godot --path .` (bosh menyu) · faqat gameplay: `godot --path . res://scenes/main.tscn`.

## 📁 Tuzilish (qisqa)

```
scenes/   — main · player · world(arena) · enemies · ui(menu/hud/loadout/pause/...) · fx
scripts/  — autoload(events, sfx, music_player, game_settings, loadout, ui_sound)
            player · weapons · enemies · world(arena, wave_manager) · ui · fx · gameplay
resources/weapons/  — WeaponData .tres (topponcha · avtomat · sniper)
assets/   — models(.glb) · textures · audio · ui · art   (Blender / Pillow generatorlar bilan)
docs/SENARIY.md  — o'yin hikoyasi («QAYTISH»)
```

## 🏗️ Arxitektura tamoyillari

- **Signal bus (`Events`)** — sahnalar bir-birini to'g'ridan-to'g'ri bilmaydi, signal orqali gaplashadi (decoupling).
- **Scene-per-concept** + **`@export` tunables** (Inspector'dan sozlanadi).
- **`WeaponData` resurslari** — yangi qurol = yangi `.tres` fayl, kod o'zgarmaydi.
- **6 autoload:** Events, GameSettings, MusicPlayer, Loadout, UiSound, Sfx.

## 🗺️ Yo'l xaritasi

- [x] **0. Asoslar** · [x] **1. Vertical slice** · [x] **2. Jang tizimi**
- [~] **3. Arena janglari** — wave/ochko/rekord ✅; ko'p arena + o'tish ⬜
- [ ] **4. Kampaniya/syujet** — `docs/SENARIY.md` («QAYTISH»), avval PROLOG
- [~] **5. Sayqal** — menyu/SFX/FX ✅; saqlash/optimizatsiya qisman
- [ ] **6. Ko'p o'yinchilik** — 5v5 + xona (uzoq muddatli)

## 🔗 Repozitoriya

GitHub (public): https://github.com/Yaxyobek0877/first-game
