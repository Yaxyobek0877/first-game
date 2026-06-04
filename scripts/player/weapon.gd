extends Node3D
## Oddiy "hitscan" (lahzali nur) qurol.
## Hitscan = o'q uchib bormaydi, balki tepkanda darhol nur tashlanadi va
## birinchi tekkan narsa nishonga olinadi. FPS o'yinlarda keng tarqalgan usul
## (masalan, pistolet, avtomat). Snayper, raketa kabilarda boshqacha bo'ladi.
##
## Bu skript Camera3D ostidagi "Weapon" tuguniga ulanadi, shunda nur har doim
## kamera qaragan tomonga ketadi.

@export var damage: float = 25.0       ## Har otishda yetkaziladigan zarar
@export var fire_rate: float = 0.15    ## Ketma-ket otishlar orasidagi minimal vaqt (s)
@export var max_ammo: int = 12         ## Magazindagi maksimal o'q soni
@export var auto_fire: bool = true     ## true = tugmani bosib tursa otaveradi (avtomat)

var current_ammo: int
var _cooldown: float = 0.0             ## Keyingi otishgacha qolgan vaqt

@onready var ray: RayCast3D = $RayCast3D     ## Nishonni aniqlaydigan nur
@onready var muzzle: Marker3D = $Muzzle      ## Quvur uchi (effekt chiqadigan nuqta)


func _ready() -> void:
	current_ammo = max_ammo
	Events.ammo_changed.emit(current_ammo, max_ammo)

	# Nur o'yinchining o'z tanasiga tegib qolmasligi uchun uni istisno qilamiz.
	var body: Node = get_parent()
	while body != null and not (body is CharacterBody3D):
		body = body.get_parent()
	if body != null:
		ray.add_exception(body)


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

	# Sichqoncha qamalmagan bo'lsa (pauza/menyu) — otmaymiz.
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	# Avtomat rejimda — bosib tursa otadi; aks holda — har bosishda bitta.
	var wants_to_fire: bool = (
		Input.is_action_pressed("shoot") if auto_fire
		else Input.is_action_just_pressed("shoot")
	)

	if wants_to_fire and _cooldown <= 0.0 and current_ammo > 0:
		_shoot()

	if Input.is_action_just_pressed("reload"):
		reload()


func _shoot() -> void:
	_cooldown = fire_rate
	current_ammo -= 1
	Events.ammo_changed.emit(current_ammo, max_ammo)

	# Nurni shu kadrda yangilaymiz (kutmasdan darhol natija).
	ray.force_raycast_update()
	if ray.is_colliding():
		var target: Object = ray.get_collider()
		var point: Vector3 = ray.get_collision_point()
		# Agar tekkan narsa "take_damage" funksiyasiga ega bo'lsa — zarar beramiz.
		if target != null and target.has_method("take_damage"):
			target.take_damage(damage)
		_spawn_impact(point)


func reload() -> void:
	current_ammo = max_ammo
	Events.ammo_changed.emit(current_ammo, max_ammo)


## Nur tekkan joyda kichik "uchqun" (sharcha) hosil qilamiz va tezda o'chiramiz.
## Hozircha sodda — keyinchalik zarrachalar (particles) bilan almashtiramiz.
func _spawn_impact(pos: Vector3) -> void:
	var spark := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	spark.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2)        # sarg'ish uchqun
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.1)
	spark.material_override = mat

	# Effektni dunyo (root) ichiga qo'shamiz, qurolga emas — joyida qotib qolsin.
	get_tree().current_scene.add_child(spark)
	spark.global_position = pos

	# 0.15 soniyada o'zini o'chiradigan taymer.
	var timer := get_tree().create_timer(0.15)
	timer.timeout.connect(spark.queue_free)
