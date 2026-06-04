extends Node
## O'yinchi jihozi (autoload "Loadout") — qaysi qurollar 1 va 2-slotda.
##
## Avatar/jihoz ekranida tanlanadi; gameplay'da weapon.gd `get_weapons()` orqali o'qiydi.
## `user://loadout.cfg` ga saqlanadi (o'yin yopilib ochilsa tanlov esda qoladi).

const PATH := "user://loadout.cfg"

## Tanlash uchun mavjud barcha qurollar (avatar ekranida shu tartibda ko'rinadi).
const ALL: Array[String] = [
	"res://resources/weapons/topponcha.tres",   # Topponcha (pistol)
	"res://resources/weapons/pistol.tres",      # Avtomat
	"res://resources/weapons/sniper.tres",      # Snayper
]

## Tanlangan 2 slot. Standart: Avtomat (1) + Snayper (2).
var slots: Array[String] = [
	"res://resources/weapons/pistol.tres",
	"res://resources/weapons/sniper.tres",
]


func _ready() -> void:
	load_loadout()


## Slotga qurol qo'yadi (i = 0 yoki 1) va saqlaydi.
func set_slot(i: int, path: String) -> void:
	if i < 0 or i >= slots.size():
		return
	if not ResourceLoader.exists(path):
		return
	slots[i] = path
	save_loadout()


## Tanlangan qurollarni WeaponData resurslari ro'yxati sifatida qaytaradi (weapon.gd uchun).
## Tip Array[Resource] — weapon.gd dagi `weapons` maydoniga to'g'ridan-to'g'ri tushadi.
func get_weapons() -> Array[Resource]:
	var out: Array[Resource] = []
	for p in slots:
		var w: Resource = load(p)
		if w != null:
			out.append(w)
	return out


## Qurol yo'lidan ko'rinadigan nomni qaytaradi (UI uchun).
func weapon_display_name(path: String) -> String:
	var w: Resource = load(path)
	if w != null and "display_name" in w:
		return w.display_name
	return path.get_file().get_basename()


func save_loadout() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("loadout", "slots", slots)
	cfg.save(PATH)


func load_loadout() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	var s: Variant = cfg.get_value("loadout", "slots", slots)
	# Faqat 2 ta haqiqiy (mavjud) yo'l bo'lsa qabul qilamiz (buzuq saqlovga qarshi).
	if s is Array and s.size() == 2 and ResourceLoader.exists(s[0]) and ResourceLoader.exists(s[1]):
		slots = [String(s[0]), String(s[1])]
