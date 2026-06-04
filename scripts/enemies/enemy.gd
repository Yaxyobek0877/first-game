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

# --- Ko'rish masofalari ---
@export var sight_range: float = 20.0        ## Shu masofadan yaqin bo'lsa o'yinchini "ko'radi"
@export var lose_sight_range: float = 28.0   ## Bundan uzoqlashsa ta'qibni to'xtatadi (gisterezis)
@export var attack_range: float = 2.0        ## Shu masofadan yaqin bo'lsa zarba beradi

# --- Hujum sozlamalari ---
@export var attack_damage: float = 12.0
@export var attack_cooldown: float = 1.2     ## Zarbalar orasidagi vaqt (s)
@export var attack_windup: float = 0.25      ## Zarba "tayyorgarligi" — o'yinchi reaksiya qilsin

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

	_update_anim()

	# DIQQAT: butun skriptda move_and_slide() FAQAT shu yerda — bir kadrda bir marta.
	move_and_slide()


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
	# Yetib oldik — hujumga o'tamiz.
	if dist <= attack_range:
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

	# O'yinchi qochib qolsa — yana ta'qibga (biroz "yopishqoqlik" bilan).
	if _distance_to_player() > attack_range * 1.3:
		_state = State.CHASE
		return

	# Taymer bo'sh bo'lsa — yangi zarba boshlaymiz. Taymer cooldown'ni ushlab turadi.
	if attack_timer.is_stopped():
		attack_timer.start()
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
	if _anim != null:
		_anim.play("die")          # orqaga yiqilish animatsiyasi
	# Boshqalarga/o'qqa to'siq bo'lmasin: "enemy" qatlamidan chiqamiz va to'qnashuvni o'chiramiz.
	set_collision_layer_value(3, false)
	# set_deferred — fizika qadami ichida to'g'ridan-to'g'ri o'chirsak Godot xato beradi.
	collision_shape.set_deferred("disabled", true)
	Events.enemy_died.emit(self)   # HUD ochkoni +1 qiladi (mavjud signal)
	# Yiqilish animatsiyasi tugashi uchun biroz kutamiz, so'ng o'chadi.
	await get_tree().create_timer(1.2, false).timeout
	queue_free()
