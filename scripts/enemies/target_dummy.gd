extends StaticBody3D
## Nishon "qo'g'irchoq" — vaqtinchalik dushman o'rnini bosadi.
## O'q tekkanda zarar oladi, joni tugaganda yo'qoladi va Events.enemy_died yuboradi.
## Keyingi bosqichda haqiqiy, harakatlanadigan AI dushman bilan almashtiramiz.

@export var max_health: float = 100.0
var health: float

@onready var mesh: MeshInstance3D = $MeshInstance3D
var _material: StandardMaterial3D
var _base_color: Color = Color(0.85, 0.2, 0.2)   ## qizil nishon


func _ready() -> void:
	health = max_health
	# Rang "flash" effekti uchun o'zimizning materialni yaratamiz.
	_material = StandardMaterial3D.new()
	_material.albedo_color = _base_color
	mesh.material_override = _material


## weapon.gd shu funksiyani chaqiradi (has_method("take_damage") orqali topadi).
func take_damage(amount: float) -> void:
	health -= amount
	_flash()
	if health <= 0.0:
		_die()


func _flash() -> void:
	# Zarba momentida oq rangga o'tamiz, keyin asl rangga silliq qaytamiz.
	_material.albedo_color = Color.WHITE
	var tween: Tween = create_tween()
	tween.tween_property(_material, "albedo_color", _base_color, 0.15)


func _die() -> void:
	Events.enemy_died.emit(self)
	queue_free()
