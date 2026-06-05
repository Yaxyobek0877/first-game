extends Resource
class_name WeaponData
## Bitta qurol turining sozlamalari — faqat MA'LUMOT (tugun emas, mantiq yo'q).
##
## Bu "custom Resource": qiymatlarni .tres fayl sifatida saqlaymiz va Inspector
## orqali tahrirlaymiz. Yangi qurol qo'shish = yangi .tres fayl, kod o'zgarmaydi.
##
## DIQQAT: o'q-dori (ammo) HOLATI bu yerda saqlanMAYDI — .tres umumiy/ulashilgan
## bo'lgani uchun. Joriy magazin soni weapon.gd ichida (har qurolga alohida) turadi.

@export var display_name: String = "Qurol"   ## HUD'da ko'rinadigan nom
@export var damage: float = 25.0              ## Har otishdagi zarar
@export var fire_rate: float = 0.15           ## Otishlar orasidagi minimal vaqt (s)
@export var max_ammo: int = 12                ## Magazin sig'imi (bitta magazindagi o'q)
@export var magazines: int = 3                ## Zaxira magazinlar soni — har reload bittasini kamaytiradi
@export var auto_fire: bool = true            ## true = tugmani bosib tursa otaveradi
@export var spread: float = 0.0               ## Tarqalish (radian) — kelajak uchun, hozir 0
@export var max_range: float = 1000.0         ## Nur uzunligi (m). Nomi "range" emas —
                                              ## chunki range() GDScript'ning band funksiyasi.
@export var zoom_fov: float = 0.0             ## O'ng tugma (aim) bosilganda kamera FOV (0 = zoom yo'q).
                                              ## Snayper uchun kichik (kuchli zoom), avtomat uchun o'rta.
@export var reload_time: float = 1.4          ## Qayta o'qlash davomiyligi (s) — animatsiya bilan.
@export var is_scope: bool = false            ## true = aim qilganda durbin (scope) overlay ko'rsatiladi (snayper).

# --- Modellar va tovush (loadout/avatar tizimi uchun) ---
@export var model_node: String = "AvtomatModel"  ## player.tscn ichidagi FP viewmodel tugun nomi
@export var view_model: String = ""              ## avatar/loadout ekrani 3D preview uchun .glb yo'li
@export var sfx_path: String = "res://assets/audio/shot.wav"  ## otish tovushi (WAV)
@export var avatar_display_size: float = 0.85    ## avatar ekranida qurolning eng uzun o'lchami (m) —
                                                  ## loadout.gd AABB'ni shunga moslab masshtablaydi (proporsional)

# --- Otish "tepishi" (recoil) — viewmodel animatsiyasi (weapon.gd ishlatadi) ---
@export var recoil_back: float = 0.05    ## Orqaga (kameraga) siljish (m)
@export var recoil_up: float = 0.015     ## Tepaga siljish (m)
@export var recoil_pitch: float = 5.0    ## Quvurni tepaga ko'taradigan burilish (daraja)
@export var bolt_action: bool = false    ## true = snayper: har otishdan keyin zatvor harakati
