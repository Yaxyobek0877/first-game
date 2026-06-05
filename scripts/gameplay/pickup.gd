extends Area3D
## Yerdagi olinadigan narsa (pickup). Tur: "ammo" | "health" | "grenade".
## Suzadi (bob) + aylanadi + rang/nur turiga qarab. Interactor uni masofadan topadi
## (collision YO'Q — "pickup" guruhi orqali). `collect()` chaqirilganda effekt beradi.

@export var kind: String = "ammo"

var _t: float = 0.0
var _base_y: float = 0.0
var _collected: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	add_to_group("pickup")
	_base_y = position.y
	_tint()


func _process(delta: float) -> void:
	_t += delta
	rotate_y(delta * 1.6)
	position.y = _base_y + sin(_t * 2.2) * 0.12   # suzish


func _tint() -> void:
	var mesh := get_node_or_null("Mesh") as MeshInstance3D
	if mesh == null:
		return
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission_energy_multiplier = 0.6
	match kind:
		"health":
			mat.albedo_color = Color(0.85, 0.2, 0.2); mat.emission = Color(0.6, 0.1, 0.1)
		"grenade":
			mat.albedo_color = Color(0.3, 0.6, 0.3); mat.emission = Color(0.1, 0.3, 0.1)
		_:
			mat.albedo_color = Color(0.85, 0.7, 0.3); mat.emission = Color(0.5, 0.4, 0.1)
	mesh.material_override = mat


## Interactor "interact" bosilganda chaqiradi: effekt + ovoz + o'chish.
func collect() -> void:
	if _collected:
		return
	_collected = true
	match kind:
		"health":
			Inventory.add_health_pack(1)
		"grenade":
			var types := ["frag", "smoke", "flash"]
			Events.grenade_pickup.emit(types[randi() % types.size()])
		_:
			Events.ammo_pickup.emit(1)
	# olish ovozi (dunyoda — o'zim o'chsam ham eshitilsin)
	if ResourceLoader.exists("res://assets/audio/pickup.wav"):
		var a := AudioStreamPlayer3D.new()
		a.stream = load("res://assets/audio/pickup.wav")
		a.bus = "SFX"; a.max_distance = 30.0
		get_tree().current_scene.add_child(a)
		a.global_position = global_position
		a.play()
		a.finished.connect(a.queue_free)
	queue_free()
