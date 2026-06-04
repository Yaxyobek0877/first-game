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

# --- Viewmodel animatsiyasi (recoil / equip / bob) ---
var _base_pos: Array[Vector3] = []     ## Har model'ning asl (base) joyi
var _recoil: Vector3 = Vector3.ZERO    ## Otishda tepish (decay bilan nolga qaytadi)
var _equip_t: float = 0.0              ## Qurol olish (pastdan ko'tarilish): 0 -> 1
var _time: float = 0.0                 ## Yengil tebranish (bob) uchun
var _shot_player: AudioStreamPlayer    ## Otish tovushi

@onready var ray: RayCast3D = $RayCast3D     ## Nishonni aniqlaydigan nur
@onready var muzzle: Marker3D = $Muzzle      ## Quvur uchi (effekt chiqadigan nuqta)
@onready var _flash: MeshInstance3D = $Muzzle/MuzzleFlash  ## Otish alangasi (toggle)
## Qurol 3D modellari — tartibi `weapons` bilan bir xil (0=Avtomat, 1=Miltiq).
## Faol qurolniki ko'rinadi, qolgani yashiriladi.
@onready var _models: Array[Node3D] = [$AvtomatModel, $MiltiqModel]


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

	# Viewmodel animatsiyasi uchun har model'ning asl joyini saqlaymiz.
	_base_pos.resize(_models.size())
	for i in _models.size():
		if _models[i] != null:
			_base_pos[i] = _models[i].position

	# Otish tovushi pleyeri (WAV — protsedural SFX).
	_shot_player = AudioStreamPlayer.new()
	_shot_player.stream = load("res://assets/audio/shot.wav")
	add_child(_shot_player)

	# Boshlang'ich o'q-dori va qurol nomini HUD'ga yuboramiz.
	# DIQQAT: call_deferred — HUD hali signalga ulanib ulgurishi uchun (kadr oxirida).
	_apply_active_weapon.call_deferred()


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

	# Viewmodel animatsiyasi: recoil so'nadi, equip ko'tariladi, yengil bob qo'shiladi.
	_time += delta
	_recoil = _recoil.lerp(Vector3.ZERO, clampf(delta * 14.0, 0.0, 1.0))
	_equip_t = move_toward(_equip_t, 1.0, delta * 4.5)
	_update_viewmodel()

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
	_equip_t = 0.0   # yangi qurol pastdan "olinadi" (equip animatsiyasi)
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
	_show_active_model()


## Faqat faol qurol modelini ko'rsatadi (qolganini yashiradi).
func _show_active_model() -> void:
	for i in _models.size():
		if _models[i] != null:
			_models[i].visible = (i == _current_index)


## Faol qurolni recoil + equip + bob offsetlari bilan asl joyiga nisbatan suradi.
func _update_viewmodel() -> void:
	if _current_index >= _models.size() or _models[_current_index] == null:
		return
	if _current_index >= _base_pos.size():
		return
	var m: Node3D = _models[_current_index]
	var bob := Vector3(sin(_time * 1.8) * 0.003, sin(_time * 3.6) * 0.003, 0.0)
	# equip: 0 da pastroq/orqaroq, 1 da asl joyda
	var equip := (1.0 - _equip_t) * Vector3(0.05, -0.14, 0.05)
	m.position = _base_pos[_current_index] + _recoil + bob + equip


## Quvur uchidagi doimiy alanga tugunini qisqa vaqt ko'rsatadi (otish his uchun).
func _muzzle_flash() -> void:
	if _flash == null:
		return
	_flash.visible = true
	get_tree().create_timer(0.05).timeout.connect(_hide_flash)


func _hide_flash() -> void:
	if is_instance_valid(_flash):
		_flash.visible = false


## Otishda quvurdan tekkan nuqtagacha qisqa yorug' "iz" (tracer) chizadi (0.04s).
func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var dist: float = from.distance_to(to)
	if dist < 0.1:
		return
	var tracer := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.02, 0.02, dist)
	tracer.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.4)
	tracer.material_override = mat
	get_tree().current_scene.add_child(tracer)
	tracer.global_position = (from + to) * 0.5
	tracer.look_at(to, Vector3.UP)   # -Z 'to' tomon; box uzunligi Z bo'ylab
	get_tree().create_timer(0.04).timeout.connect(tracer.queue_free)


func _shoot() -> void:
	var w: Resource = _active()
	_cooldown = w.fire_rate
	_ammo_counts[_current_index] -= 1
	Events.ammo_changed.emit(_ammo_counts[_current_index], w.max_ammo)

	# Otish "tepishi" (recoil — orqaga/tepaga) + quvur uchidagi alanga.
	_recoil += Vector3(0.0, 0.012, 0.045)
	_recoil.z = minf(_recoil.z, 0.08)
	_recoil.y = minf(_recoil.y, 0.03)
	_muzzle_flash()
	if _shot_player != null and _shot_player.stream != null:
		_shot_player.pitch_scale = randf_range(0.92, 1.08)   # ozgina o'zgarish — bir xil bo'lmasin
		_shot_player.play()

	# Nurning uzunligini qurol masofasiga moslaymiz va shu kadrda yangilaymiz.
	ray.target_position = Vector3(0.0, 0.0, -w.max_range)
	ray.force_raycast_update()
	var tracer_end: Vector3
	if ray.is_colliding():
		var target: Object = ray.get_collider()
		var point: Vector3 = ray.get_collision_point()
		tracer_end = point
		# Agar tekkan narsa "take_damage" funksiyasiga ega bo'lsa — zarar beramiz.
		if target != null and target.has_method("take_damage"):
			target.take_damage(w.damage)
			Events.target_hit.emit()   # HUD hit-marker ko'rsatadi
		_spawn_impact(point)
	else:
		tracer_end = ray.to_global(ray.target_position)
	_spawn_tracer(muzzle.global_position, tracer_end)


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
