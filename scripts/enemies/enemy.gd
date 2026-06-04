extends CharacterBody3D
## Harakatlanadigan AI dushman.
##
## Vazifasi: o'yinchini "ko'radi", NavigationAgent3D yordamida tomon yo'l topib
## yuradi, yaqinlashganda yaqin masofadan (melee) zarba berib jonini kamaytiradi.
## O'q tekkanda zarar oladi va o'ladi (nishon — target_dummy — naqshi bilan).
##
## Holatlar (FSM = Finite State Machine — chekli holatlar mashinasi):
##   IDLE   — jim turadi, o'yinchini kutadi
##   CHASE  — o'yinchiga tomon yuradi
##   ATTACK — yetib oldi, zarba beradi
##   DEAD   — o'lgan, harakatsiz, tez orada o'chadi
##
## Navigatsiya arena.tscn dagi NavigationRegion3D (bake qilingan navmesh) ga bog'liq.

enum State { IDLE, CHASE, ATTACK, DEAD }

# --- Jon va harakat ---
@export var max_health: float = 60.0
@export var move_speed: float = 3.5
@export var gravity: float = 20.0

# --- Bir-biridan itarilish (separation) — ustma-ust to'planib qolmaslik uchun ---
@export var separation_radius: float = 1.5    ## Shu masofadagi boshqa dushmanlardan itariladi
@export var separation_strength: float = 2.2  ## Itarilish kuchi (move_speed dan kichik)

# --- Ko'rish masofalari (arena shooter — butun maydondan aggro) ---
@export var sight_range: float = 65.0        ## Shu masofadan yaqin bo'lsa o'yinchini "ko'radi"
@export var lose_sight_range: float = 80.0   ## Bundan uzoqlashsa ta'qibni to'xtatadi (gisterezis)
@export var attack_range: float = 2.0        ## Shu masofadan yaqin bo'lsa zarba beradi

# --- Hujum sozlamalari ---
@export var attack_damage: float = 12.0
@export var attack_cooldown: float = 1.2     ## Zarbalar orasidagi vaqt (s)
@export var attack_windup: float = 0.25      ## Zarba "tayyorgarligi" — o'yinchi reaksiya qilsin

# --- Masofadan otish (ranged) — Kron miltiqchi uchun ---
@export var is_ranged: bool = false          ## true = yaqin jang emas, masofadan otadi
@export var ranged_range: float = 16.0       ## Shu masofadan otadi (ko'rinish bo'lsa)
@export var ranged_damage: float = 8.0       ## Har otishdagi zarar (melee'dan kamroq)

# --- O'lim/jasad ---
@export var corpse_lifetime: float = 12.0    ## Jasad yerda qancha turadi (s), so'ng o'chadi
                                              ## (juda ko'p jasad to'planib FPS tushmasligi uchun)

var _state: State = State.IDLE
var _player: Node3D = null
var health: float

@onready var nav: NavigationAgent3D = $NavigationAgent3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var attack_timer: Timer = $AttackTimer
@onready var model: Node3D = $Model
var _anim: AnimationPlayer = null              ## glTF model ichidagi animatsiyalar
var _mesh_inst: MeshInstance3D = null          ## "flash" effekti uchun mesh


func _ready() -> void:
	health = max_health
	# "enemy" guruhi — keyin (3-bosqich) to'lqin tizimida dushmanlarni sanash uchun foydali.
	add_to_group("enemy")
	attack_timer.one_shot = true
	attack_timer.wait_time = attack_cooldown
	# glTF model ichidan AnimationPlayer va mesh'ni topamiz ("as" — xavfsiz cast).
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_mesh_inst = model.find_child("KronSoldierMesh", true, false) as MeshInstance3D
	if _anim != null:
		# idle va run takrorlanadigan (loop) bo'lsin.
		for a in ["idle", "run"]:
			if _anim.has_animation(a):
				_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		_anim.play("idle")
	# MUHIM: NavigationServer3D xaritani keyingi fizika kadrida sinxronlaydi.
	# Shuning uchun bir kadr kutamiz, keyin o'yinchini topamiz.
	await get_tree().physics_frame
	_player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	# Gravitatsiya har doim — dushman yerga "yopishib" tursin (o'lganda ham tushadi).
	if not is_on_floor():
		velocity.y -= gravity * delta

	match _state:
		State.IDLE:
			_do_idle()
		State.CHASE:
			_do_chase()
		State.ATTACK:
			_do_attack()
		State.DEAD:
			velocity.x = 0.0
			velocity.z = 0.0

	# Tirik bo'lsa — yaqin dushmanlardan itariladi (ustma-ust to'planmasin).
	# Ta'qibda ham, hujumda ham, jim turganda ham ishlaydi.
	if _state != State.DEAD:
		var sep: Vector3 = _separation()
		velocity.x += sep.x
		velocity.z += sep.z

	_update_anim()

	# DIQQAT: butun skriptda move_and_slide() FAQAT shu yerda — bir kadrda bir marta.
	move_and_slide()


## Yaqin (tirik) dushmanlardan itarilish vektori — boids "separation".
## Yaqinroq bo'lsa kuchliroq itaradi; natija move_speed'dan oshmaydigan kuchga normallanadi.
func _separation() -> Vector3:
	var push := Vector3.ZERO
	for o in get_tree().get_nodes_in_group("enemy"):
		if o == self or not (o is Node3D):
			continue
		var away: Vector3 = global_position - (o as Node3D).global_position
		away.y = 0.0
		var d: float = away.length()
		if d > 0.001 and d < separation_radius:
			push += away.normalized() * (1.0 - d / separation_radius)
	if push.length() > 0.001:
		push = push.normalized() * separation_strength
	return push


# --- Holat funksiyalari ---

func _do_idle() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if _ensure_player() and _distance_to_player() <= sight_range:
		_state = State.CHASE


func _do_chase() -> void:
	if not _ensure_player():
		_stop_horizontal()
		_state = State.IDLE
		return

	var dist: float = _distance_to_player()
	# Juda uzoqlashdi — ta'qibni to'xtatamiz.
	if dist > lose_sight_range:
		_stop_horizontal()
		_state = State.IDLE
		return
	# Yetib oldik (melee) yoki otish masofasiga kirdik (ranged) — hujumga o'tamiz.
	# Ranged uchun: KO'RINISH (LOS) bo'lsagina ATTACK. Aks holda pana ortida qotib
	# qolmaslik uchun yaqinlashishni (navigatsiyani) davom ettiramiz — yangi joydan
	# otish imkonini topguncha.
	var stop_dist: float = ranged_range if is_ranged else attack_range
	var ready: bool = dist <= stop_dist
	if is_ranged and ready and not _has_line_of_sight():
		ready = false
	if ready:
		_stop_horizontal()
		_state = State.ATTACK
		return

	# Navmesh hali sinxronlanmagan bo'lsa (yoki yo'q bo'lsa) — bu kadr turamiz.
	if NavigationServer3D.map_get_iteration_id(nav.get_navigation_map()) == 0:
		_stop_horizontal()
		return

	nav.target_position = _player.global_position
	if nav.is_navigation_finished():
		_stop_horizontal()
		return

	# Yo'lning keyingi nuqtasiga qarab yuramiz.
	var next_pos: Vector3 = nav.get_next_path_position()
	var dir: Vector3 = global_position.direction_to(next_pos)
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	_face_player()


func _do_attack() -> void:
	_stop_horizontal()
	if not _ensure_player():
		_state = State.IDLE
		return
	_face_player()

	var trigger: float = ranged_range if is_ranged else attack_range
	# O'yinchi uzoqlashdi — yana ta'qibga (biroz "yopishqoqlik" bilan).
	if _distance_to_player() > trigger * 1.3:
		_state = State.CHASE
		return

	# Ranged: o'yinchi ko'rinmasa (pana ortida) — qayta joylashish uchun ta'qibga qaytamiz.
	if is_ranged and not _has_line_of_sight():
		_state = State.CHASE
		return

	# Taymer bo'sh bo'lsa — yangi hujum. Taymer cooldown'ni ushlab turadi.
	if attack_timer.is_stopped():
		attack_timer.start()
		if is_ranged:
			_ranged_strike()
		else:
			_strike()


## Zarba: qisqa tayyorgarlikdan keyin o'yinchiga zarar yetkazadi.
## Alohida funksiya — await _do_attack'ni har kadr to'xtatib qo'ymasligi uchun.
func _strike() -> void:
	# Nayza zarbasi animatsiyasini boshlaymiz (bir martalik).
	if _anim != null:
		_anim.play("attack")
	# create_timer(..., false): pauzaga bo'ysunadi — game over paytida zarba bermaydi.
	await get_tree().create_timer(attack_windup, false).timeout
	# await dan KEYIN holat o'zgargan bo'lishi mumkin (o'ldik / o'yinchi qochdi).
	# Shuning uchun qayta tekshiramiz — aks holda o'lik dushman ham urishi mumkin.
	if _state != State.ATTACK:
		return
	if not is_instance_valid(_player):
		return
	if _distance_to_player() > attack_range * 1.3:
		return
	if _player.has_method("take_damage"):
		_player.take_damage(attack_damage)


## Masofadan otish: tayyorgarlikdan keyin, ko'rinish bo'lsa, hitscan zarar beradi.
## Taymer process_in_physics=true — await fizika kadrida tugaydi (raycast xavfsiz).
func _ranged_strike() -> void:
	if _anim != null:
		_anim.play("attack")   # qisqa otish harakati
	await get_tree().create_timer(attack_windup, false, true).timeout
	if _state != State.ATTACK or not is_instance_valid(_player):
		return
	if not _has_line_of_sight():
		return                 # pana ortida — o'q tegmaydi
	_enemy_muzzle_flash()
	# Ko'rinadigan o'q izi (tracer) quvurdan o'yinchigacha + tekkan joyda uchqun.
	var muzzle_pos: Vector3 = global_position - global_transform.basis.z * 0.7 + Vector3(0, 1.0, 0)
	var hit_pos: Vector3 = _player.global_position + Vector3(0, 1.1, 0)
	_spawn_tracer(muzzle_pos, hit_pos)
	_spawn_impact(hit_pos)
	if _player.has_method("take_damage"):
		_player.take_damage(ranged_damage)


## O'q izi (tracer) — ikki nuqta orasida qisqa yorug' chiziq.
## Yo'g'onroq + biroz uzoqroq turadi (0.09s) — tezkor jangda ko'rinib qolsin.
func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var dist: float = from.distance_to(to)
	if dist < 0.2:
		return
	var t := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.06, 0.06, dist)
	t.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.3)
	t.material_override = mat
	get_tree().current_scene.add_child(t)
	t.global_position = (from + to) * 0.5
	t.look_at(to, Vector3.UP)
	get_tree().create_timer(0.09).timeout.connect(t.queue_free)


## Tekkan joyda kichik uchqun (0.1s).
func _spawn_impact(pos: Vector3) -> void:
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	s.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.5)
	s.material_override = mat
	get_tree().current_scene.add_child(s)
	s.global_position = pos
	get_tree().create_timer(0.1).timeout.connect(s.queue_free)


## Dushman ko'zidan o'yinchiga to'g'ri ko'rinish bormi? (devor/pana to'smaydimi)
func _has_line_of_sight() -> bool:
	if not is_instance_valid(_player):
		return false
	var from: Vector3 = global_position + Vector3(0, 1.4, 0)
	var to: Vector3 = _player.global_position + Vector3(0, 1.2, 0)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1 | 2   # world + player
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	return not hit.is_empty() and hit.collider == _player


## Dushman quroli uchida qisqa alanga (otganda) — dunyoga qo'shamiz, 0.05s.
func _enemy_muzzle_flash() -> void:
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	flash.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.3)
	flash.material_override = mat
	get_tree().current_scene.add_child(flash)
	# Quvur uchi taxminan: oldinga (-Z, o'yinchi tomon) va ko'krak balandligida.
	flash.global_position = global_position - global_transform.basis.z * 0.7 + Vector3(0, 1.0, 0)
	get_tree().create_timer(0.07).timeout.connect(flash.queue_free)


# --- Yordamchi funksiyalar ---

func _stop_horizontal() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


## Holatga qarab animatsiya tanlaydi (idle <-> run). attack/die — bir martalik,
## ular _strike()/_die() ichida qo'yiladi va bu yerda ustidan yozilmaydi.
func _update_anim() -> void:
	if _anim == null:
		return
	if _state == State.DEAD:
		return                                # "die" _die() da qo'yiladi
	if _anim.current_animation == "attack":
		return                                # zarba animatsiyasi tugaguncha kutamiz
	var moving: bool = Vector2(velocity.x, velocity.z).length() > 0.4
	var want: String = "run" if moving else "idle"
	if _anim.current_animation != want:
		_anim.play(want)


## Player havolasini tekshiradi/yangilaydi. Topilsa true qaytaradi.
func _ensure_player() -> bool:
	if is_instance_valid(_player):
		return true
	_player = get_tree().get_first_node_in_group("player")
	return is_instance_valid(_player)


func _distance_to_player() -> float:
	if not is_instance_valid(_player):
		return INF
	return global_position.distance_to(_player.global_position)


func _face_player() -> void:
	if not is_instance_valid(_player):
		return
	var target: Vector3 = _player.global_position
	target.y = global_position.y   # faqat gorizontal aylanish (tepaga qaramasin)
	# Nol-uzunlik (o'yinchi ustimizda) bo'lsa look_at xato beradi — shuning uchun guard.
	if global_position.distance_to(target) > 0.05:
		look_at(target, Vector3.UP)


# --- Zarar olish va o'lim (target_dummy naqshi) ---

func take_damage(amount: float) -> void:
	if _state == State.DEAD:
		return
	health -= amount
	_flash()
	_blood_burst()
	if health <= 0.0:
		_die()


func _flash() -> void:
	# Zarba momentida butun model oq rangga "yonadi", keyin asl ranglar tiklanadi.
	if _mesh_inst == null:
		return
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.emission_enabled = true
	m.emission = Color(1, 1, 1)
	_mesh_inst.material_override = m
	# Qisqa vaqtdan keyin override'ni olib tashlaymiz (asl model ranglari qaytadi).
	get_tree().create_timer(0.12).timeout.connect(_clear_flash)


func _clear_flash() -> void:
	if is_instance_valid(_mesh_inst):
		_mesh_inst.material_override = null


func _die() -> void:
	_state = State.DEAD
	# Jasad joyida qotadi (fizika o'chadi — yerga botmaydi).
	set_physics_process(false)
	# Tirik dushmanlar ro'yxatidan chiqamiz — to'lqin keyingisiga o'tsin (jasad qolsa ham).
	remove_from_group("enemy")
	# Boshqalarga/o'qqa to'siq bo'lmasin: "enemy" qatlamidan chiqamiz va to'qnashuvni o'chiramiz.
	set_collision_layer_value(3, false)
	# set_deferred — fizika qadami ichida to'g'ridan-to'g'ri o'chirsak Godot xato beradi.
	collision_shape.set_deferred("disabled", true)
	Events.enemy_died.emit(self)   # HUD ochkoni +1 qiladi (mavjud signal)
	_blood_pool()
	# Jasad TABIIY yerda yotsin: skeletni neytral qilib, butun modelni gorizontal
	# ag'daramiz (orqaga yiqilib, yuz tepaga) — g'alati ko'tarilgan poza emas.
	if _anim != null:
		_anim.play("idle")
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(model, "rotation_degrees:x", 90.0, 0.4)
	tw.tween_property(model, "position:y", 0.13, 0.4)
	# Jasad yerda qoladi (corpse_lifetime), so'ng o'chadi (cheksiz to'planmasin).
	await get_tree().create_timer(corpse_lifetime, false).timeout
	queue_free()


## Tekkanda qisqa qizil "qon" purkagichi (ko'krak balandligida).
func _blood_burst() -> void:
	var b := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.12
	s.height = 0.24
	b.mesh = s
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.5, 0.0, 0.0, 0.9)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b.material_override = mat
	get_tree().current_scene.add_child(b)
	b.global_position = global_position + Vector3(0, 1.2, 0)
	var tw := get_tree().create_tween()
	tw.set_parallel(true)
	tw.tween_property(b, "scale", Vector3(2.0, 2.0, 2.0), 0.28)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tw.chain().tween_callback(b.queue_free)


## O'lganda yerga qon ko'lmagi (yassi qizil disk) — jasad bilan qoladi.
func _blood_pool() -> void:
	var p := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.7
	c.bottom_radius = 0.7
	c.height = 0.03
	p.mesh = c
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.0, 0.0)
	mat.roughness = 1.0
	p.material_override = mat
	get_tree().current_scene.add_child(p)
	p.global_position = global_position + Vector3(0, 0.02, 0)
	# Jasad bilan birga (corpse_lifetime) o'chadi.
	get_tree().create_timer(corpse_lifetime, false).timeout.connect(p.queue_free)
