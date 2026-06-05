extends Node
## "Olish" (pickup) tizimi (main.tscn dagi tugun). Player'ga TEGMAYDI — uni "player"
## guruhidan topadi, yaqindagi eng yaqin pickup'ni aniqlaydi, ekranda "[F] ... ol"
## ko'rsatadi va "interact" bosilganda oladi. Tugma rebind qilinsa, matn ham yangilanadi.

const RANGE := 2.6
const NAMES := {"health": "jon paketi", "grenade": "granata", "ammo": "o'q-dori"}

var _label: Label
var _current: Node3D = null


func _ready() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 50
	add_child(cl)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(0.96, 0.86, 0.5))
	_label.anchor_left = 0.5; _label.anchor_top = 0.5
	_label.anchor_right = 0.5; _label.anchor_bottom = 0.5
	_label.offset_left = -160.0; _label.offset_top = 44.0
	_label.offset_right = 160.0; _label.offset_bottom = 74.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	cl.add_child(_label)


func _process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		_set_target(null)
		return
	var ppos: Vector3 = (p as Node3D).global_position
	var best: Node3D = null
	var best_d := RANGE
	for n in get_tree().get_nodes_in_group("pickup"):
		var d: float = ppos.distance_to((n as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = n
	_set_target(best)
	if _current != null \
			and Input.is_action_just_pressed("interact") \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var c := _current
		_set_target(null)
		c.collect()


func _set_target(n: Node3D) -> void:
	_current = n
	if n == null or not is_instance_valid(n):
		_label.visible = false
		return
	var key: String = GameSettings.binding_text("interact")
	_label.text = "[%s] %s ol" % [key, NAMES.get(n.get("kind"), "narsa")]
	_label.visible = true
