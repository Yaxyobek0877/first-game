extends Node3D
## Bir nechta qurol turini boshqaradigan "hitscan" (lahzali nur) tizimi.
##
## Hitscan = o'q uchib bormaydi, tepkanda darhol nur tashlanadi va birinchi tekkan
## narsa nishonga olinadi. FPS o'yinlarda keng tarqalgan (pistolet, avtomat).
##
## Endi bir nechta qurol bor (WeaponData resurslari). `1` va `2` tugmalari bilan
## almashtiriladi. Har qurolning O'Z magazini bor — almashganda o'q-dori yo'qolmaydi.
##
## Bu skript Camera3D ostidagi "Weapon" tuguniga ulanadi, shunda nur har doim
## kamera qaragan tomonga ketadi.

## Qurollar ro'yxati (slot 1, slot 2, ...). Bo'sh bo'lsa, _ready ichida standart
## ikkita qurol (pistolet, miltiq) avtomatik yuklanadi. Inspector orqali ham
## o'zgartirsa bo'ladi (Resource — WeaponData turidagi .tres fayllar).
@export var weapons: Array[Resource] = []

var _current_index: int = 0
## Har qurolning O'Z magazini. Indeks `weapons` bilan bir xil tartibda.
var _ammo_counts: Array[int] = []
var _cooldown: float = 0.0             ## Keyingi otishgacha qolgan vaqt

@onready var ray: RayCast3D = $RayCast3D     ## Nishonni aniqlaydigan nur
@onready var muzzle: Marker3D = $Muzzle      ## Quvur uchi (effekt chiqadigan nuqta)


func _ready() -> void:
	# Agar Inspector'da qurollar berilmagan bo'lsa — standart ikkitasini yuklaymiz.
	if weapons.is_empty():
		weapons = [
			load("res://resources/weapons/pistol.tres"),
			load("res://resources/weapons/rifle.tres"),
		]

	# Har bir qurol uchun magazinni to'la qilib boshlaymiz.
	_ammo_counts.resize(weapons.size())
	for i in weapons.size():
		_ammo_counts[i] = weapons[i].max_ammo

	# Nur o'yinchining o'z tanasiga tegib qolmasligi uchun uni istisno qilamiz.
	var body: Node = get_parent()
	while body != null and not (body is CharacterBody3D):
		body = body.get_parent()
	if body != null:
		ray.add_exception(body)

	# Boshlang'ich o'q-dori va qurol nomini HUD'ga yuboramiz.
	# DIQQAT: call_deferred — HUD hali signalga ulanib ulgurishi uchun (kadr oxirida).
	_apply_active_weapon.call_deferred()


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

	# Qurol almashtirish — sichqoncha qamalmagan bo'lsa ham ishlasin (mouse guard'dan oldin).
	if Input.is_action_just_pressed("weapon_1"):
		_switch_to(0)
	elif Input.is_action_just_pressed("weapon_2"):
		_switch_to(1)

	# Sichqoncha qamalmagan bo'lsa (pauza/menyu) — otmaymiz.
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if weapons.is_empty():
		return

	var w: Resource = _active()
	# Avtomat rejimda — bosib tursa otadi; aks holda — har bosishda bitta.
	var wants_to_fire: bool = (
		Input.is_action_pressed("shoot") if w.auto_fire
		else Input.is_action_just_pressed("shoot")
	)

	if wants_to_fire and _cooldown <= 0.0 and _ammo_counts[_current_index] > 0:
		_shoot()

	if Input.is_action_just_pressed("reload"):
		reload()


## Joriy (faol) qurol ma'lumotini qaytaradi.
func _active() -> Resource:
	return weapons[_current_index]


## Berilgan slotga o'tadi (agar mavjud va boshqa bo'lsa).
func _switch_to(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
	if index == _current_index:
		return
	_current_index = index
	# Cooldown'ni SAQLAB qolamiz (nolga tushirmaymiz) — aks holda `1`/`2` ni tez-tez
	# bosib fire_rate cheklovini chetlab o'tib, juda tez otish mumkin bo'lardi (exploit).
	_apply_active_weapon()


## Faol qurolning o'q-dori va nomini HUD'ga yuboradi (signal orqali).
func _apply_active_weapon() -> void:
	if weapons.is_empty():
		return
	var w: Resource = _active()
	Events.ammo_changed.emit(_ammo_counts[_current_index], w.max_ammo)
	Events.weapon_changed.emit(w.display_name)


func _shoot() -> void:
	var w: Resource = _active()
	_cooldown = w.fire_rate
	_ammo_counts[_current_index] -= 1
	Events.ammo_changed.emit(_ammo_counts[_current_index], w.max_ammo)

	# Nurning uzunligini qurol masofasiga moslaymiz va shu kadrda yangilaymiz.
	ray.target_position = Vector3(0.0, 0.0, -w.max_range)
	ray.force_raycast_update()
	if ray.is_colliding():
		var target: Object = ray.get_collider()
		var point: Vector3 = ray.get_collision_point()
		# Agar tekkan narsa "take_damage" funksiyasiga ega bo'lsa — zarar beramiz.
		if target != null and target.has_method("take_damage"):
			target.take_damage(w.damage)
		_spawn_impact(point)


func reload() -> void:
	var w: Resource = _active()
	_ammo_counts[_current_index] = w.max_ammo
	Events.ammo_changed.emit(_ammo_counts[_current_index], w.max_ammo)


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
