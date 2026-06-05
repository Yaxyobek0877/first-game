extends Node
## Granata otish nazorati (main.tscn ga tugun sifatida qo'shiladi).
##
## G — joriy turdagi granatani kamera qaragan tomonga tashlaydi (qaysi qurol bo'lsa ham).
## '4' — granata turini aylantiradi (frag → smoke → flash).
## Har to'lqin (wave) boshida zaxira tiklanadi. HUD `Events.grenade_changed` ni eshitadi.
##
## Player skriptiga TEGMAYDI — kamerani get_viewport().get_camera_3d() orqali topadi.

const GRENADE := preload("res://scenes/fx/grenade.tscn")
const TYPES := ["frag", "smoke", "flash"]
const START_COUNTS := {"frag": 3, "smoke": 2, "flash": 2}
const THROW_FORCE := 16.0
const COOLDOWN := 0.7

var _counts: Dictionary = {}
var _type_idx: int = 0
var _cd: float = 0.0


func _ready() -> void:
	_counts = START_COUNTS.duplicate()
	Events.wave_started.connect(_on_wave)
	Events.grenade_pickup.connect(_on_pickup)
	_announce.call_deferred()   # HUD ulanib ulgurishi uchun


## Yerdan granata olinganda — o'sha turdagi son oshadi (maks 9).
func _on_pickup(grenade_type: String) -> void:
	if _counts.has(grenade_type):
		_counts[grenade_type] = mini(int(_counts[grenade_type]) + 1, 9)
		_announce()


func _on_wave(_wave: int) -> void:
	_counts = START_COUNTS.duplicate()
	_announce()


func _process(delta: float) -> void:
	if _cd > 0.0:
		_cd -= delta
	# Faqat o'yin faol (sichqoncha qamalgan) bo'lganda.
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if Input.is_action_just_pressed("grenade_cycle"):
		_type_idx = (_type_idx + 1) % TYPES.size()
		_announce()
	if Input.is_action_just_pressed("grenade") and _cd <= 0.0:
		_throw()


func _cur() -> String:
	return TYPES[_type_idx]


## Inventar UI uchun — barcha granata turlari sonini qaytaradi.
func get_counts() -> Dictionary:
	return _counts.duplicate()


func _announce() -> void:
	Events.grenade_changed.emit(_cur(), int(_counts.get(_cur(), 0)))


func _throw() -> void:
	var t: String = _cur()
	if int(_counts.get(t, 0)) <= 0:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_counts[t] = int(_counts[t]) - 1
	_cd = COOLDOWN
	var fwd: Vector3 = -cam.global_transform.basis.z
	var origin: Vector3 = cam.global_position + fwd * 0.6 - cam.global_transform.basis.y * 0.1
	var g := GRENADE.instantiate()
	g.grenade_type = t
	g.position = origin            # Main (root) origin'da → local = global
	get_tree().current_scene.add_child(g)
	g.linear_velocity = fwd * THROW_FORCE + Vector3.UP * 2.5
	g.angular_velocity = Vector3(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
	# tashlash "shuv" ovozi
	var p := AudioStreamPlayer3D.new()
	p.stream = load("res://assets/audio/grenade_throw.wav")
	p.bus = "SFX"
	p.max_distance = 30.0
	g.add_child(p)
	p.play()
	_announce()
