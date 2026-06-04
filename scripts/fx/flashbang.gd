extends Node3D
## Flashbang (ko'r qiluvchi granata).
##
## - Yorqin oq yorug'lik chaqnashi (OmniLight, tez so'nadi).
## - Flashbang ovozi (keskin "qars" + jiringlash).
## - Agar o'yinchi yaqin VA portlashga qarab turgan bo'lsa (va orada devor yo'q) —
##   ekran oqarib ketadi va sekin tiniqlashadi (ko'rlik effekti).
## Zarar bermaydi.

const SFX := "res://assets/audio/flashbang.wav"
const BLIND_RANGE := 18.0
const LIFETIME := 2.6


func _ready() -> void:
	# Yorug'lik chaqnashi
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 1.0, 0.98)
	light.light_energy = 12.0
	light.omni_range = 14.0
	add_child(light)
	create_tween().tween_property(light, "light_energy", 0.0, 0.4) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# Ovoz
	if ResourceLoader.exists(SFX):
		var p := AudioStreamPlayer3D.new()
		p.stream = load(SFX)
		p.bus = "SFX"
		p.max_distance = 70.0
		add_child(p)
		p.play()

	_try_blind()
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)


## O'yinchi kamerasini topib, ko'rlik kerakmi-yo'qligini hisoblaydi.
func _try_blind() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var to_flash: Vector3 = global_position - cam.global_position
	var dist: float = to_flash.length()
	if dist > BLIND_RANGE or dist < 0.01:
		return
	# Kamera portlashga qarab turibdimi? (oldinga = -Z; portlash yo'nalishi bilan dot)
	var facing: float = (-cam.global_transform.basis.z).dot(to_flash.normalized())
	if facing <= 0.05:
		return   # boshqa tomonga qarab turibdi — ko'r bo'lmaydi
	# Orada devor (world=1) bo'lsa — ko'rlik yo'q.
	var space := get_world_3d().direct_space_state
	var rq := PhysicsRayQueryParameters3D.create(
		cam.global_position, global_position + Vector3(0, 0.3, 0), 1)
	rq.collide_with_areas = false
	if not space.intersect_ray(rq).is_empty():
		return
	var intensity: float = clampf(1.0 - dist / BLIND_RANGE, 0.15, 1.0) * clampf(facing, 0.0, 1.0)
	if intensity < 0.06:
		return
	_blind(intensity)


func _blind(intensity: float) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 100        # hamma narsa ustida
	add_child(cl)
	var rect := ColorRect.new()
	rect.color = Color(1, 1, 1, clampf(intensity, 0.0, 1.0))
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(rect)
	# Sekin tiniqlashadi (ko'rlik o'tadi). Davomiyligi intensivlikka bog'liq.
	var dur: float = 1.4 + intensity * 0.9
	create_tween().tween_property(rect, "color:a", 0.0, dur).set_ease(Tween.EASE_IN)
