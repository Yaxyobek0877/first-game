# CLAUDE.md — First Game (FPS + Adventure)

> **Yangi sessiyada avval shu faylni o'qing.** Bu loyiha konteksti — Claude Code uni avtomatik yuklaydi.
> Foydalanuvchi **o'zbek tilida (lotin yozuvi)** muloqot qiladi → javoblar va kod izohlari ham o'zbekcha.
> Rol taqsimoti: **foydalanuvchi yo'naltiradi, Claude quradi va tushuntiradi.**

---

## 🎯 Loyiha maqsadi (vision)

Bu — foydalanuvchining **birinchi o'yini**. Maqsad: AI yordamida o'yin yaratishni o'rganish.

- **Janr:** birinchi shaxs (FPS) **otishma + sarguzasht/syujet**.
- **Asosiy mexanika:** alohida **arenalarda** janglar, hikoya/scenariy bilan bog'langan.
- **Hikoya:** to'liq senariy → `docs/SENARIY.md` («QAYTISH» — muqobil tarix, 1-jahon urushi uslubi; kelajakdan o'tmishga qaytgan general taqdirni o'zgartirishga urinadi).
- **Dvijok:** **Godot 4.6**, **GDScript** (Mono/C# emas).
- **Tamoyil:** professional, bosqichma-bosqich ("vertical slice" → kengaytirish). Sifat va o'rganish birinchi o'rinda.

---

## 📊 Hozirgi holat

| Bosqich | Tavsif | Holat |
|---------|--------|-------|
| **0. Asoslar** | Loyiha, papka tuzilishi, input xaritasi, `Events` autoload | ✅ Tugadi |
| **1. Vertical Slice** | FPS yurish/qarash/sakrash, hitscan otish, nishonlar, HUD | ✅ Tugadi va tekshirildi |
| **2. Jang tizimi** | AI dushman, qurol turlari, jon/zarar balansi | ✅ Tugadi va tekshirildi |
| 3. Arena janglari | To'lqinli dushmanlar, bir nechta arena, ochko | ⏭️ Keyingi |
| 4. Kampaniya/syujet | `docs/SENARIY.md` ni amalga oshirish — avval PROLOG | ⬜ |
| 5. Sayqal | Tovush, effektlar, menyu, saqlash, optimizatsiya | ⬜ |
| 6. Ko'p o'yinchilik | 5v5 janglar + xona (room) ochish — ilg'or/uzoq muddatli | ⬜ |

**1- va 2-bosqich `--headless` rejimida toza ishladi** (xato/ogohlantirish yo'q). 2-bosqich
`--fixed-fps 60 --quit-after 1200` (20 s determenistik simulyatsiya) bilan **uchidan-uchiga** ham
tekshirildi: navmesh bake bo'ladi (59 ko'pburchak), dushman o'yinchini topib ta'qib qiladi, hujum
qiladi va o'ldiradi → "O'yin tugadi" pauzasi ishlaydi.

---

## 🗺️ Aniq maqsadlar (bosqichlarning konkret natijalari)

**2-bosqich — Jang tizimi (✅ TUGADI):**
- [x] Harakatlanadigan AI dushman: `CharacterBody3D` + `NavigationAgent3D`, o'yinchini ko'rib, tomon yuradi (FSM: IDLE/CHASE/ATTACK/DEAD).
- [x] Dushman hujum qiladi (yaqin masofa / melee — nayza uslubi) → o'yinchi jon yo'qotadi.
- [x] O'yinchi o'lganda: "O'yin tugadi" ekrani + qayta boshlash (pauza-bilan ishlovchi UI).
- [x] `target_dummy` saqlandi (mashq nishoni) + yonida tirik dushman qo'shildi.
- [x] 2 qurol turi: **Avtomat** (tez/zaif, auto) va **Miltiq** (sekin/kuchli, bitta-bitta), `1`/`2` bilan almashtirish, har biriga alohida o'q-dori.

> Eslatma: navmesh CSG'dan emas, ko'rinmas yordamchi collision shape'lardan (`nav_source` guruhi,
> 8-qatlam) `arena.gd` ichida runtime'da bake qilinadi. Senariyga mos: melee dushman ≈ nayzali
> Kron askari; o'lim→qayta-boshlash «Qaytish» mexanikasiga singadi.

**3-bosqich — Arena janglari:** to'lqin (wave) tizimi, dushman spawn nuqtalari, ochko/rekord, 2-3 arena sahnasi, arenadan arenaga o'tish.

**4-bosqich — Sarguzasht/syujet:** darajalar ketma-ketligi, oddiy hikoya/dialog, NPC, maqsadlar (objective), daraja o'tish eshigi/portali.

**5-bosqich — Sayqal:** otish/qadam tovushlari, muzzle flash va tracer, asosiy menyu + pauza menyusi, saqlash/yuklash, optimizatsiya.

---

## 🏗️ Arxitektura

- **Signal bus (`Events` autoload)** — `scripts/autoload/events.gd`. Sahnalar bir-birini bilmaydi; signal orqali "gaplashadi" (decoupling). Signallar: `ammo_changed`, `player_health_changed`, `enemy_died`, `player_died`, `weapon_changed`. Yangi global hodisalarni shu yerga qo'shing.
- **Scene-per-concept** — har bir mantiqiy bo'lak alohida `.tscn` (player, world, enemy, ui).
- **`@export` tunables** — tezlik, zarar, jon kabi qiymatlar Inspector orqali sozlanadi (kodga tegmasdan).
- **Player** — `CharacterBody3D`; harakat `_physics_process` ichida, qarash `_unhandled_input` ichida. `"player"` guruhida (dushman uni topadi).
- **Weapon** — Camera3D ostida; **hitscan** (`RayCast3D.force_raycast_update()`). Qurollar `WeaponData` resurslari (`resources/weapons/*.tres`), `Array[Resource]` sifatida saqlanadi; har biriga alohida o'q-dori. Nishonda `take_damage(amount: float)` bo'lsa zarar beradi (duck typing: `has_method`).
- **Enemy** — `CharacterBody3D` + `NavigationAgent3D`, `enemy.gd` FSM. Player'ni `get_first_node_in_group("player")` orqali topadi. `take_damage`/`_die` → `Events.enemy_died`.
- **Collision qatlamlari:** world=1, player=2, enemy=3 (value 4), nav-source=4 (value 8). Player layer=2/mask=5; Enemy layer=4/mask=3; qurol nuri mask=5 (world+enemy); dummy'lar 1-qatlamda.
- **Pauza/o'lim:** `Events.player_died` → `game_over.tscn` (`PROCESS_MODE_ALWAYS`) `get_tree().paused=true` qiladi; restart `paused=false` (avval) → `reload_current_scene()`.

---

## 📁 Tuzilish

```
first_game/
├── project.godot          # Sozlamalar + input xaritasi (+weapon_1/2) + Events autoload
├── CLAUDE.md              # (shu fayl) loyiha konteksti
├── README.md              # Inson uchun hujjat + boshqaruv
├── docs/SENARIY.md        # O'yin hikoyasi (story bible) — «QAYTISH»
├── icon.svg
├── assets/
│   ├── blender/{soldier,props,weapons}.py  # Blender generatorlar (→ .glb)
│   └── models/*.glb       # kron_soldier · trench_dressing · avtomat · miltiq
├── resources/
│   └── weapons/{avtomat=pistol.tres, rifle.tres}  # WeaponData sozlamalari
├── scenes/
│   ├── main.tscn          # Bosh sahna: arena + player + 3 nishon + Enemy + HUD + GameOver
│   ├── player/player.tscn # CharacterBody3D > Head > Camera3D > Weapon(RayCast3D, GunMesh, Muzzle)
│   ├── world/arena.tscn   # WorldEnvironment + Sun + CSGBox + NavigationRegion3D(nav_source)
│   ├── enemies/{target_dummy.tscn, enemy.tscn}
│   └── ui/{hud.tscn, game_over.tscn}
└── scripts/
    ├── autoload/events.gd
    ├── player/{player.gd, weapon.gd}
    ├── weapons/weapon_data.gd      # class_name WeaponData (custom Resource)
    ├── world/arena.gd              # runtime navmesh bake
    ├── enemies/{target_dummy.gd, enemy.gd}
    └── ui/{hud.gd, game_over.gd}
```

## 🎮 Boshqaruv

`WASD` yurish · sichqoncha qarash · chap tugma otish · `Shift` yugurish · `Space` sakrash · `R` qayta o'qlash · `1`/`2` qurol almashtirish · `Esc` sichqonchani bo'shatish.

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

## 🎨 Assetlar (3D modellar — Blender pipeline)

Modellar **Blender 5.1** da Python skript bilan headless yasaladi va **glTF (.glb)** ga
eksport qilinadi (Godot avtomatik import qiladi). Generator skriptlar `assets/blender/` da —
qayta yaratiladigan (reproducible), izohlar o'zbekcha. **Uslub:** stilize low-poly, 1-jahon urushi davri.

- **Blender:** `C:\Users\hcsah\...` → `C:\Program Files\Blender Foundation\Blender 5.1\blender.exe`
- **Model yasash/yangilash:** `& "<blender>" --background --python assets\blender\soldier.py`
  → `assets/models/kron_soldier.glb` (animatsiyalar bilan) + `_preview_*.png` render'lar (gitignore'da).
- **Tekshirish:** "ko'rmasdan yasamaslik" uchun Blender render'i (`_preview_*.png`) Read bilan ko'riladi.
- **Animatsiya:** rigid skinning (har qism 1 suyak); har Blender action = alohida glTF animatsiya
  (`idle`/`run`/`attack`/`die`). Har animatsiya self-contained (barcha suyaklarni belgilaydi).
- **Integratsiya:** `enemy.tscn` modelni instance qiladi; `enemy.gd` AnimationPlayer'ni FSM bilan
  boshqaradi (`find_child` orqali topadi). Collision kapsula alohida qoladi (fizika).
- **Generatorlar:** `soldier.py` (Kron askari, animatsiyali; dubulg'a bosh ustida) · `props.py`
  (xandaq bezagi — `trench_dressing.glb`, arenaga bir marta instance) · `weapons.py` (Avtomat/Miltiq
  viewmodel + qo'l/yeng; `player.tscn` Weapon ostida; `weapon.gd` faol qurol modelini ko'rsatadi).
- **Viewmodel animatsiyasi (`weapon.gd`):** otishda recoil (tepish) + muzzle flash (Muzzle ostidagi
  doimiy emissive tugun, 0.05s toggle), qurol almashganda equip (pastdan ko'tarilish), yengil bob.
  Hammasi `_update_viewmodel` da har model'ning asl (base) joyiga offset qo'shib hisoblanadi.
- **In-game tekshiruv:** kerak bo'lsa vaqtinchalik scene bilan Godot'ni oynali (`--headless`siz)
  ishga tushirib, `get_viewport().get_texture().get_image().save_png(...)` orqali kadr olib,
  Read bilan ko'rish mumkin (modellar joylashuvini tasdiqlash uchun).

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
