extends Node
## Portlash kamera silkinishi (autoload emas — main.tscn dagi tugun).
## `Events.explosion` ni eshitadi va faol Camera3D ni qisqa silkitadi.
##
## Decoupled: player.gd ga TEGMAYDI. Kamera `h_offset`/`v_offset` (frustum siljishi —
## tananı surmaydi) + `rotation.z` (roll) vaqtincha o'zgartiriladi; player bu uchtasini
## ishlatmaydi (u head.rotation.x va player.rotation.y ni boshqaradi) — konflikt yo'q.

const DECAY := 1.8          ## "trauma" so'nish tezligi (1/s)
const MAX_OFFSET := 0.16    ## eng katta frustum siljishi
const MAX_ROLL := 0.045     ## eng katta roll (rad)

var _trauma: float = 0.0


func _ready() -> void:
	Events.explosion.connect(_on_explosion)


func _on_explosion(center: Vector3, radius: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var d: float = cam.global_position.distance_to(center)
	var f: float = clampf(1.0 - d / (radius * 2.6), 0.0, 1.0)
	if f > 0.0:
		_trauma = minf(1.0, _trauma + f)


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	if _trauma <= 0.0:
		# Silkinish tugadi — qiymatlarni nolga qaytaramiz (bir marta).
		if cam.h_offset != 0.0 or cam.v_offset != 0.0 or cam.rotation.z != 0.0:
			cam.h_offset = 0.0
			cam.v_offset = 0.0
			cam.rotation.z = 0.0
		return
	_trauma = maxf(0.0, _trauma - DECAY * delta)
	var s: float = _trauma * _trauma     # kuchli boshlanib, tez yumshaydi
	cam.h_offset = randf_range(-1.0, 1.0) * MAX_OFFSET * s
	cam.v_offset = randf_range(-1.0, 1.0) * MAX_OFFSET * s
	cam.rotation.z = randf_range(-1.0, 1.0) * MAX_ROLL * s
