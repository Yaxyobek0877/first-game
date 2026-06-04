extends CanvasLayer
## Snayper durbin (scope) overlay — aim qilganda (Events.scoped) ko'rinadi.
## layer=0: HUD (layer 1) ostida — HUD yorliqlari ustida ko'rinib turadi.

@onready var rect: ColorRect = $ScopeRect


func _ready() -> void:
	visible = false
	Events.scoped.connect(_on_scoped)
	_update_aspect()


func _on_scoped(active: bool) -> void:
	visible = active
	if active:
		_update_aspect()


func _update_aspect() -> void:
	var mat := rect.material as ShaderMaterial
	if mat != null:
		var sz := get_viewport().get_visible_rect().size
		mat.set_shader_parameter("aspect", sz.x / maxf(1.0, sz.y))
