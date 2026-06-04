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
var _model_nodes: Dictionary = {}      ## nom (String) -> Node3D (viewmodel)
var _base_pos: Dictionary = {}         ## nom (String) -> Vector3 (model'ning asl joyi)
var _recoil: Vector3 = Vector3.ZERO    ## Otishda tepish (decay bilan nolga qaytadi)
var _equip_t: float = 0.0              ## Qurol olish (pastdan ko'tarilish): 0 -> 1
var _time: float = 0.0                 ## Yengil tebranish (bob) uchun
var _shot_player: AudioStreamPlayer    ## Otish tovushi

@onready var ray: RayCast3D = $RayCast3D     ## Nishonni aniqlaydigan nur
@onready var muzzle: Marker3D = $Muzzle      ## Quvur uchi (effekt chiqadigan nuqta)
@onready var _flash: MeshInstance3D = $Muzzle/MuzzleFlash  ## Otish alangasi (toggle)
## Qurol 3D modellari (viewmodel) Weapon ostidagi "...Model" bolalardan _ready'da yig'iladi.
## Faol qurol model_node'iga mos modelgina ko'rinadi (qolgani yashiriladi).
## Kamera (Weapon tuguni Camera3D ostida) — aim/zoom uchun.
@onready var _camera: Camera3D = get_parent() as Camera3D
var _default_fov: float = 75.0
var _aim_t: float = 0.0     ## Aim (ADS) o'tishi: 0 = beldan, 1 = markazga olingan
var _scoped: bool = false   ## Snayper durbin (scope) overlay faolmi
var _reloading: bool = false  ## Qayta o'qlash jarayonidami (otib bo'lmaydi)
var _reload_t: float = 0.0    ## Reload animatsiyasi progressi 0->1 (qurol pasayadi)
var _reload_gen: int = 0      ## Reload "avlodi" — eskirgan coroutine'larni bekor qiladi (race oldini olish)
var _recoil_pitch: float = 0.0  ## Otish "tepishi" burilishi (daraja — quvur tepaga; nolga so'nadi)
var _bolt_t: float = 0.0        ## Snayper zatvor harakati progressi (0 = jim, >0 = ishlayapti)
const BOLT_DUR := 0.55          ## Zatvor (bolt-action) harakati davomiyligi (s)


func _ready() -> void:
	# Zoom uchun kameraning asl FOV'ini saqlaymiz.
	if _camera != null:
		_default_fov = _camera.fov

	# Viewmodel'larni nom bo'yicha yig'amiz ("...Model" bilan tugaydiganlar) va yashiramiz.
	for child in get_children():
		if child is Node3D and child.name.ends_with("Model"):
			_model_nodes[child.name] = child
			_base_pos[child.name] = child.position
			child.visible = false

	# Qurollar: Inspector'da berilmagan bo'lsa — tanlangan jihozdan (Loadout) olamiz.
	if weapons.is_empty():
		weapons = Loadout.get_weapons()
	if weapons.is_empty():   # zaxira (Loadout bo'sh bo'lib qolsa)
		weapons = [
			load("res://resources/weapons/pistol.tres"),   # Avtomat (tez/zaif)
			load("res://resources/weapons/sniper.tres"),    # Snayper (sekin/kuchli, durbin)
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

	# O'q nuri dushman HITBOX'larini (bosh/tana/oyoq — 5-qatlam "hitbox"=16) uradi,
	# kapsulani (enemy=4) emas — shu sabab tana qismini aniqlab, headshot beramiz.
	ray.collide_with_areas = true
	ray.collision_mask = 1 | (1 << 4)   # world(1) + hitbox(16) = 17

	# Otish tovushi pleyeri (WAV — protsedural SFX). "SFX" shinasiga ulanadi.
	# Stream faol qurolga qarab _apply_active_weapon'da o'rnatiladi.
	_shot_player = AudioStreamPlayer.new()
	_shot_player.bus = "SFX"
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
	_recoil_pitch = lerpf(_recoil_pitch, 0.0, clampf(delta * 12.0, 0.0, 1.0))
	# Zatvor (bolt-action) harakati: boshlangan bo'lsa progressni surib, tugaganda nolga.
	if _bolt_t > 0.0:
		_bolt_t += delta / BOLT_DUR
		if _bolt_t >= 1.0:
			_bolt_t = 0.0
	_equip_t = move_toward(_equip_t, 1.0, delta * 4.5)
	if _reloading and not weapons.is_empty():
		_reload_t = minf(_reload_t + delta / maxf(0.1, _active().reload_time), 1.0)
	_update_viewmodel()
	_update_zoom(delta)

	# Qurol almashtirish — sichqoncha qamalmagan bo'lsa ham ishlasin (mouse guard'dan oldin).
	if Input.is_action_just_pressed("weapon_1"):
		_switch_to(0)
	elif Input.is_action_just_pressed("weapon_2"):
		_switch_to(1)
	# Sichqoncha g'ildiragi (scroll) bilan keyingi/oldingi qurolga aylanma o'tish.
	elif Input.is_action_just_pressed("weapon_next"):
		_cycle(1)
	elif Input.is_action_just_pressed("weapon_prev"):
		_cycle(-1)

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

	if wants_to_fire and _cooldown <= 0.0 and _ammo_counts[_current_index] > 0 and not _reloading:
		_shoot()

	if Input.is_action_just_pressed("reload"):
		_start_reload()


## Joriy (faol) qurol ma'lumotini qaytaradi.
func _active() -> Resource:
	return weapons[_current_index]


## Faol qurolga mos viewmodel tugunini qaytaradi (model_node bo'yicha). Yo'q bo'lsa null.
func _active_model() -> Node3D:
	return _model_nodes.get(_active().model_node, null)


## Scroll bilan keyingi (+1) yoki oldingi (-1) qurolga aylanma o'tadi.
func _cycle(dir: int) -> void:
	if weapons.size() <= 1:
		return
	_switch_to((_current_index + dir + weapons.size()) % weapons.size())


## Berilgan slotga o'tadi (agar mavjud va boshqa bo'lsa).
func _switch_to(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
	if index == _current_index:
		return
	_current_index = index
	_equip_t = 0.0   # yangi qurol pastdan "olinadi" (equip animatsiyasi)
	_reloading = false   # qurol almashsa reload bekor bo'ladi
	_reload_t = 0.0
	_reload_gen += 1     # eskirgan reload coroutine'ini bekor qilamiz
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
	# Faol qurolning otish tovushini o'rnatamiz (topponcha/avtomat farqli).
	if _shot_player != null and w.sfx_path != "":
		_shot_player.stream = load(w.sfx_path)
	_show_active_model()


## O'ng tugma (aim) bosilganda faol qurolning zoom_fov'iga silliq o'tadi.
func _update_zoom(delta: float) -> void:
	if _camera == null or weapons.is_empty():
		return
	var w: Resource = _active()
	var aiming: bool = Input.is_action_pressed("aim") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and w.zoom_fov > 0.0
	var target_fov: float = w.zoom_fov if aiming else _default_fov
	_camera.fov = lerpf(_camera.fov, target_fov, clampf(delta * 14.0, 0.0, 1.0))
	# ADS o'tishi (qurol markazga olinadi) — _update_viewmodel ishlatadi.
	_aim_t = move_toward(_aim_t, 1.0 if aiming else 0.0, delta * 8.0)
	# Durbin (scope) overlay — faqat durbinli qurolni aim qilganda.
	var want_scope: bool = aiming and w.is_scope
	if want_scope != _scoped:
		_scoped = want_scope
		Events.scoped.emit(_scoped)


## Faqat faol qurol modelini ko'rsatadi (qolganini yashiradi).
func _show_active_model() -> void:
	var key: String = _active().model_node
	for name in _model_nodes:
		_model_nodes[name].visible = (name == key)


## Faol qurolni recoil + equip + bob offsetlari bilan asl joyiga nisbatan suradi.
func _update_viewmodel() -> void:
	if weapons.is_empty():
		return
	var m: Node3D = _active_model()
	if m == null:
		return
	var w: Resource = _active()
	var base: Vector3 = _base_pos.get(w.model_node, Vector3.ZERO)
	# Aim qilganda bob kamayadi (tinch nishon).
	var bob := Vector3(sin(_time * 1.8) * 0.003, sin(_time * 3.6) * 0.003, 0.0) * (1.0 - _aim_t)
	# equip: 0 da pastroq/orqaroq, 1 da asl joyda
	var equip := (1.0 - _equip_t) * Vector3(0.05, -0.14, 0.05)
	# ADS: aim qilganda qurol markazga (x->0) va biroz oldinga/tepaga olinadi.
	var bx: float = base.x
	var aim := _aim_t * Vector3(-bx * 0.92, 0.03, 0.05)
	# Reload: qurol pasayadi (o'rtada eng past); bolt-action bo'lsa gardishni ham ag'daradi.
	var reload_dip := Vector3.ZERO
	var reload_roll := 0.0
	if _reloading:
		var d: float = sin(_reload_t * PI)
		reload_dip = Vector3(0.04, -0.20 * d, 0.0)
		if w.bolt_action:
			reload_roll = 20.0 * d   # snayper: o'q joylash hissi (qo'l gardishni ishlatadi)
	# Bolt-action zatvor harakati (snayper) — har otishdan keyin orqaga tortib qaytariladi.
	var bolt_off := Vector3.ZERO
	var bolt_roll := 0.0
	var bolt_pitch := 0.0
	if _bolt_t > 0.0:
		var bp: float = sin(clampf(_bolt_t, 0.0, 1.0) * PI)   # 0 -> 1 -> 0
		bolt_off = Vector3(0.025, -0.03, 0.05) * bp           # orqaga+pastga+o'ngga
		bolt_roll = 16.0 * bp                                  # gardishni ag'darish
		bolt_pitch = 4.0 * bp
	# Durbin orqali qaraganda qurol modeli yashiriladi.
	m.visible = not _scoped
	m.position = base + _recoil + bob + equip + aim + reload_dip + bolt_off
	# Burilish: recoil quvurni tepaga (pitch+), bolt/reload gardishni ag'daradi (roll).
	m.rotation_degrees = Vector3(_recoil_pitch + bolt_pitch, 0.0, bolt_roll + reload_roll)


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

	# Otish "tepishi" (recoil) — har qurolga moslangan (topponcha/avtomat/snayper farqli).
	# Siljish (orqaga+tepaga) + quvurni tepaga ko'taradigan burilish (pitch).
	_recoil += Vector3(0.0, w.recoil_up, w.recoil_back)
	_recoil.z = minf(_recoil.z, w.recoil_back * 1.8)
	_recoil.y = minf(_recoil.y, w.recoil_up * 1.8)
	_recoil_pitch = minf(_recoil_pitch + w.recoil_pitch, w.recoil_pitch * 1.6)
	# Snayper (bolt-action): har otishdan keyin zatvor harakatini boshlaymiz ("puza").
	if w.bolt_action:
		_bolt_t = 0.0001
	_muzzle_flash()
	if _shot_player != null and _shot_player.stream != null:
		_shot_player.pitch_scale = randf_range(0.92, 1.08)   # ozgina o'zgarish — bir xil bo'lmasin
		_shot_player.play()
	# Otish ovozi — yaqindagi dushmanlar "eshitadi" va tovush kelgan joyni tekshiradi.
	Events.player_fired.emit(muzzle.global_position)

	# Nurning uzunligini qurol masofasiga moslaymiz va shu kadrda yangilaymiz.
	ray.target_position = Vector3(0.0, 0.0, -w.max_range)
	ray.force_raycast_update()
	var tracer_end: Vector3
	if ray.is_colliding():
		var target: Object = ray.get_collider()
		var point: Vector3 = ray.get_collision_point()
		tracer_end = point
		# O'q kuchi: har qurol zarari × tasodifiy ±15% (o'qlar bir xil emas).
		var dmg: float = w.damage * randf_range(0.85, 1.15)
		var victim: Object = target
		# Hitbox'ga tegsa — tana joyiga qarab ko'paytma (bosh ×2.5 / tana ×1 / oyoq ×0.7).
		if target != null and target.is_in_group("hitbox"):
			dmg *= float(target.get_meta("mult", 1.0))
			victim = target.get_parent()
		if victim != null and victim.has_method("take_damage"):
			victim.take_damage(dmg)
			Events.target_hit.emit()   # HUD hit-marker ko'rsatadi
		_spawn_impact(point)
	else:
		tracer_end = ray.to_global(ray.target_position)
	_spawn_tracer(muzzle.global_position, tracer_end)


## Qayta o'qlashni boshlaydi (animatsiya bilan). Jarayonda otib bo'lmaydi.
func _start_reload() -> void:
	if _reloading or weapons.is_empty():
		return
	var w: Resource = _active()
	if _ammo_counts[_current_index] >= w.max_ammo:
		return   # magazin to'la — kerak emas
	_reloading = true
	_reload_t = 0.0
	_reload_gen += 1
	_reload(w, _current_index, _reload_gen)


## Reload jarayoni: o'rtada (qurol eng pastda) magazin almashadi.
## slot/gen — boshlanish paytidagi qurol va "avlod"; almashsa/yangi reload bo'lsa bekor.
func _reload(w: Resource, slot: int, gen: int) -> void:
	var half: float = w.reload_time * 0.5
	await get_tree().create_timer(half, false).timeout
	if gen != _reload_gen:       # eskirgan (almashtirildi/yangi reload) — hech narsa qilmaymiz
		return
	_ammo_counts[slot] = w.max_ammo
	if slot == _current_index:
		Events.ammo_changed.emit(_ammo_counts[slot], w.max_ammo)
	await get_tree().create_timer(half, false).timeout
	if gen != _reload_gen:
		return
	_reloading = false


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
