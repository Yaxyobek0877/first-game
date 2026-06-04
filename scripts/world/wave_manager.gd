extends Node
## To'lqin (wave) boshqaruvchisi — 3-bosqich.
##
## Vazifasi: dushmanlarni to'lqin-to'lqin spawn qiladi. Har to'lqinda ko'proq
## dushman; har 3-dushman masofadan otadigan (ranged). Tirik dushmanlar tugaganda
## qisqa kutib, keyingi to'lqinni boshlaydi.
##
## Dushmanlar "enemy" guruhida bo'ladi (enemy.gd add_to_group). Nishonlar (dummy)
## bu guruhda EMAS, shuning uchun to'lqin hisobiga ta'sir qilmaydi.

@export var enemy_scene: PackedScene
@export var first_wave_delay: float = 1.5    ## Birinchi to'lqingacha kutish (s)
@export var between_wave_delay: float = 3.0  ## To'lqinlar orasidagi kutish (s)
@export var base_count: int = 2              ## 1-to'lqindagi dushman = base_count + 1

var _wave: int = 0
var _spawning: bool = false   ## To'lqin almashish jarayonida (qayta-trigger bo'lmasin)

## Spawn nuqtalari (Godot koordinatalari, polda). Arena ichi, to'siqlardan chetda,
## o'yinchidan (z=8) uzoqda — shimol va flanglar.
var _spawn_points: Array[Vector3] = [
	Vector3(-12, 0, -16), Vector3(0, 0, -17), Vector3(12, 0, -16),
	Vector3(-16, 0, -8), Vector3(16, 0, -8),
	Vector3(-4, 0, -16), Vector3(4, 0, -16),
]


func _ready() -> void:
	if enemy_scene == null:
		enemy_scene = load("res://scenes/enemies/enemy.tscn")
	# create_timer(..., false): pauzaga bo'ysunadi — game over paytida spawn bo'lmaydi.
	await get_tree().create_timer(first_wave_delay, false).timeout
	_start_wave()


func _process(_delta: float) -> void:
	# To'lqin boshlangan va almashish jarayonida emas bo'lsa — tirik dushman qoldimi?
	if _wave > 0 and not _spawning:
		if get_tree().get_nodes_in_group("enemy").is_empty():
			_spawning = true
			_next_wave_after_delay()


func _next_wave_after_delay() -> void:
	await get_tree().create_timer(between_wave_delay, false).timeout
	_start_wave()


func _start_wave() -> void:
	_wave += 1
	var count: int = base_count + _wave   # to'lqin sayin ko'proq dushman
	for i in count:
		var e: Node3D = enemy_scene.instantiate()
		var sp: Vector3 = _spawn_points[(i * 3 + _wave) % _spawn_points.size()]
		e.position = sp
		# Har 3-dushman masofadan otadigan (ranged) bo'ladi.
		if i % 3 == 2:
			e.is_ranged = true
		get_tree().current_scene.add_child(e)
	_spawning = false
	Events.wave_started.emit(_wave)
	print("To'lqin ", _wave, " boshlandi: ", count, " dushman")
