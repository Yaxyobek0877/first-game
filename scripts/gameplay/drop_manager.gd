extends Node
## Pickup'larni paydo qiladi (main.tscn dagi tugun). Player/dushman skriptlariga TEGMAYDI.
##  - Dushman o'lganda (Events.enemy_died) tasodifan narsa tushiradi.
##  - O'yin boshida arenaga bir nechta narsa sochib qo'yadi.

const PICKUP := preload("res://scenes/fx/pickup.tscn")
const DROP_CHANCE := 0.45
const KINDS := ["ammo", "health", "grenade"]


func _ready() -> void:
	Events.enemy_died.connect(_on_enemy_died)
	_spawn_scattered.call_deferred()   # current_scene tayyor bo'lgach


func _on_enemy_died(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if randf() > DROP_CHANCE:
		return
	_spawn(KINDS[randi() % KINDS.size()], (enemy as Node3D).global_position + Vector3(0, 0.4, 0))


## Arenaga oldindan sochilgan narsalar (turli joy).
func _spawn_scattered() -> void:
	var spots := [Vector3(8, 0.5, -8), Vector3(-9, 0.5, -12), Vector3(13, 0.5, 4), Vector3(-14, 0.5, 5)]
	var kinds := ["ammo", "health", "grenade", "ammo"]
	for i in spots.size():
		_spawn(kinds[i], spots[i])


func _spawn(kind: String, pos: Vector3) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var pk := PICKUP.instantiate()
	pk.kind = kind
	pk.position = pos
	scene.add_child(pk)
