extends Node
## Inventar ma'lumotlari (autoload "Inventory").
##
## Hozircha: jon paketlari (health pack). Qurollar Loadout'da, granatalar
## GrenadeThrower'da boshqariladi — inventar UI ularni Events orqali ko'rsatadi.
## Bu yerda — yig'iladigan/ishlatiladigan narsalar (hozircha jon paketi).

signal changed()   ## UI yangilanishi uchun

const MAX_HEALTH_PACKS := 5
const HEAL_AMOUNT := 50.0

var health_packs: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Yangi o'yin (o'lim → qayta boshlash) da inventar tozalansin.
	Events.player_died.connect(reset)


func add_health_pack(n: int = 1) -> void:
	health_packs = clampi(health_packs + n, 0, MAX_HEALTH_PACKS)
	changed.emit()


## Jon paketini ishlatadi — o'yinchini davolaydi. Muvaffaqiyatli bo'lsa true.
## Player'ga TEGMAYDI — uni "player" guruhidan topib, public `health` ni o'zgartiradi.
func use_health_pack() -> bool:
	if health_packs <= 0:
		return false
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return false
	var hp: float = float(p.get("health"))
	var mx: float = float(p.get("max_health"))
	if hp >= mx - 0.01:
		return false   # jon to'la — behuda sarflamaymiz
	health_packs -= 1
	p.set("health", minf(mx, hp + HEAL_AMOUNT))
	Events.player_health_changed.emit(float(p.get("health")), mx)
	changed.emit()
	return true


func reset() -> void:
	health_packs = 0
	changed.emit()
