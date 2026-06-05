extends CharacterBody3D
## Intizomli AI Kron askari — rolga ega, tabiiy harakatlanadi (zombi emas).
##
## Eski "to'g'ridan-to'g'ri quvish" o'rniga: har askarning ROLI bor (post qo'riqlash,
## patrul, miltiqchi, snayper, hujumchi, qanotdan aylanish). Harakat SILLIQ (tezlanish/
## sekinlash, burilish tezligi cheklangan), o'yinchini KO'RISH konusi + ovozni eshitish
## orqali sezadi (sehrli kuzatish yo'q — oxirgi ko'rilgan joyni tekshiradi), va o'z
## postidan uzoqlashsa qaytadi (leash). Miltiqchilar masofa saqlab strafe qiladi.
##
## Holatlar (FSM):
##   GUARD       — postni ushlaydi, atrofga qaraydi
##   PATROL      — nuqtalar bo'ylab yuradi
##   INVESTIGATE — ovoz/oxirgi ko'rilgan joyni tekshiradi
##   ENGAGE      — jangda (melee yaqinlashadi, ranged strafe + otadi)
##   ADVANCE     — postga / o'yinchiga / qanotga siljiydi
##   RETURN      — postiga qaytadi
##   ATTACK      — melee zarba (yaqin masofa)
##   DEAD        — o'lgan
##
## Navigatsiya arena.tscn dagi NavigationRegion3D (bake qilingan navmesh) ga bog'liq.

enum Role { SENTRY, PATROL, RIFLEMAN, MARKSMAN, ASSAULT, FLANKER }
enum State { GUARD, PATROL, INVESTIGATE, ENGAGE, ADVANCE, RETURN, ATTACK, DEAD }

# --- Jon va harakat ---
@export var max_health: float = 60.0
@export var move_speed: float = 3.5
@export var gravity: float = 20.0
@export var accel: float = 14.0          ## Tezlanish chegarasi (m/s^2) — silliq tezlashish
@export var decel: float = 18.0          ## Sekinlash chegarasi (m/s^2)
@export var turn_rate_deg: float = 320.0 ## Burilish tezligi (daraja/s) — keskin "snap" emas

# --- Bir-biridan itarilish (separation) — ustma-ust to'planmaslik ---
@export var separation_radius: float = 1.5
@export var separation_strength: float = 2.2

# --- Rol / post ---
@export var role: Role = Role.ASSAULT
@export var guard_position: Vector3 = Vector3.INF  ## INF => spawn joyini post qiladi
@export var guard_radius: float = 3.0              ## Post atrofidagi "egalik" radiusi
@export var leash_range: float = 14.0              ## Postdan bundan uzoqlashsa qaytadi
@export var patrol_points: Array[Vector3] = []     ## PATROL nuqtalari (dunyo koordinatasi)
@export var engage_range: float = 26.0             ## Post yaqinida o'yinchi shu masofada bo'lsa jang
@export var face_dir_deg: float = 0.0              ## Postda turganda qarash yo'nalishi (0 = janub, o'yinchi tomon)
@export var flank_side: int = 0                    ## FLANKER: -1/+1 (qaysi qanotdan)

# --- Idrok (perception) ---
@export var vision_range: float = 32.0       ## Ko'rish masofasi
@export var vision_fov_deg: float = 110.0    ## Ko'rish konusi (to'liq burchak, ±55°)
@export var hearing_range: float = 16.0      ## Otish ovozini eshitish masofasi
@export var lose_interest_time: float = 4.0  ## Ko'rmay turib shuncha o'tsa — qiziqishni yo'qotadi

# --- Hujum (melee) ---
@export var attack_range: float = 2.0
@export var attack_damage: float = 12.0
@export var attack_cooldown: float = 1.2
@export var attack_windup: float = 0.25

# --- Masofadan otish (ranged) ---
@export var is_ranged: bool = false
@export var ranged_range: float = 16.0       ## Shu masofadan otadi (LOS bo'lsa)
@export var ranged_damage: float = 8.0
@export var ideal_range: float = 12.0        ## Saqlamoqchi bo'lgan ideal masofa
@export var min_standoff: float = 7.0        ## Bundan yaqin bo'lsa orqaga chekinadi

# --- Navigatsiya throttle ---
@export var repath_interval: float = 0.35    ## Yo'lni shu intervalda qayta hisoblaydi (har kadr emas)

# --- Minora snayperi / granata ---
@export var tower_sniper: bool = false   ## Minora tepasida turadi — joyidan jilmaydi (faqat aylanadi/otadi)
@export var grenades: int = 0            ## Granata zaxirasi (assault/flanker'da oz miqdorda)

# --- O'lim/jasad ---
@export var corpse_lifetime: float = 12.0

const PERCEPT_INTERVAL := 0.2                ## Idrok yangilanishi (5 Hz) — har kadr emas (tejamkor)

var _state: State = State.ADVANCE
var _player: Node3D = null
var health: float

# Harakat ichki holati
var _desired_vel: Vector3 = Vector3.ZERO     ## Holat funksiyasi shuni belgilaydi (silliqlashdan oldin)
var _face_yaw: float = 0.0                   ## Maqsad burilish (radian) — _apply_rotation unga buradi
var _goal: Vector3 = Vector3.INF             ## Joriy nav maqsadi (repath throttle uchun)
var _repath_accum: float = 0.0
# Idrok holati
var _percept_accum: float = 0.0
var _can_see_player: bool = false
var _los_cached: bool = false                ## Oxirgi ko'rish tekshiruvidagi LOS (jangda qayta ray otmaslik)
var _last_known_pos: Vector3 = Vector3.INF   ## O'yinchining oxirgi ko'rilgan/eshitilgan joyi
var _time_since_seen: float = 999.0
# Holat taymerlari
var _patrol_idx: int = 0
var _dwell_t: float = 0.0
var _look_t: float = 0.0
var _investigate_t: float = 0.0
# Strafe (ranged)
var _strafe_sign: float = 1.0
var _strafe_flip_t: float = 0.0
var _strafe_collide_cd: float = 0.0   ## To'qnashuvda strafe almashishi orasidagi sovish (jitter oldini oladi)
var _aggressive: bool = false         ## Wave failsafe: leash bekor, o'yinchiga to'g'ridan-to'g'ri "bosqin"
var _grenade_cd: float = 0.0          ## Granata tashlash orasidagi sovish (s)

@onready var nav: NavigationAgent3D = $NavigationAgent3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var attack_timer: Timer = $AttackTimer
@onready var model: Node3D = $Model
var _anim: AnimationPlayer = null
var _mesh_inst: MeshInstance3D = null


func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	attack_timer.one_shot = true
	# Eski chaqiruvchi faqat is_ranged bersa (rol bermasa) — RIFLEMAN deb qabul qilamiz.
	if is_ranged and role == Role.ASSAULT:
		role = Role.RIFLEMAN
	# is_ranged ni roldan qayta hisoblaymiz — yangi kod asosiy manba.
	is_ranged = (role == Role.RIFLEMAN or role == Role.MARKSMAN)
	_apply_role_tunables()
	# Postni hal qilamiz — MUHIM: await'dan OLDIN (itarib yuborilsa ham postini bilsin).
	if guard_position == Vector3.INF:
		guard_position = global_position
	# Har askarga ozgina o'zgaruvchanlik (bir xil robot bo'lmasin).
	move_speed *= randf_range(0.9, 1.1)
	turn_rate_deg *= randf_range(0.9, 1.1)
	attack_cooldown *= randf_range(0.9, 1.15)
	repath_interval *= randf_range(0.85, 1.15)
	_repath_accum = randf() * repath_interval
	_percept_accum = randf() * PERCEPT_INTERVAL
	_strafe_sign = 1.0 if randf() < 0.5 else -1.0
	if role == Role.FLANKER and flank_side == 0:
		flank_side = 1 if randf() < 0.5 else -1
	# Granata faqat bir qism askarda qolsin (kam bo'lsin) + qisqa boshlang'ich sovish
	# (yetib kelmasdan, masofadan uloqtirsin).
	if grenades > 0 and randf() > 0.5:
		grenades = 0
	_grenade_cd = randf_range(0.5, 2.0)
	attack_timer.wait_time = attack_cooldown
	# Model animatsiyalari ("walk"/"aim"/"alert" bo'lmasa — fallback bilan ishlaydi).
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_mesh_inst = model.find_child("KronSoldierMesh", true, false) as MeshInstance3D
	if _anim != null:
		for a in ["idle", "run", "walk", "aim"]:
			if _anim.has_animation(a):
				_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		_anim.play("idle")
	# Eshitish (o'yinchi o'q uzganda).
	Events.player_fired.connect(_on_player_fired)
	# Boshlang'ich holat va qarash.
	_state = _initial_state()
	_face_yaw = _hold_yaw()
	rotation.y = _face_yaw
	# Navmesh keyingi fizika kadrida sinxronlanadi — bir kadr kutamiz.
	await get_tree().physics_frame
	_player = get_tree().get_first_node_in_group("player")


## Rolga xos sozlamalar (bir joyda — balansni o'zgartirish oson).
func _apply_role_tunables() -> void:
	match role:
		Role.SENTRY:
			leash_range = 13.0
			engage_range = 24.0
		Role.PATROL:
			leash_range = 18.0
			engage_range = 26.0
		Role.RIFLEMAN:
			ranged_range = 18.0
			ideal_range = 12.0
			min_standoff = 7.0
			leash_range = 16.0
			engage_range = 30.0
		Role.MARKSMAN:
			ranged_range = 40.0
			ideal_range = 24.0
			min_standoff = 16.0
			leash_range = 10.0
			engage_range = 44.0
			vision_range = 46.0     # snayper uzoqni ko'radi (minoradan)
			move_speed *= 0.85
			if tower_sniper:
				vision_fov_deg = 230.0   # minoradan keng kuzatadi (atrofni qamrab oladi)
		Role.ASSAULT:
			leash_range = 99999.0   # butun arena — postga bog'lanmagan
			grenades = 1            # bitta granata (oz)
		Role.FLANKER:
			leash_range = 99999.0
			grenades = 1


func _initial_state() -> State:
	match role:
		Role.SENTRY:
			return State.GUARD
		Role.PATROL:
			return State.PATROL
		_:
			return State.ADVANCE   # ranged: postga; assault/flanker: o'yinchiga


func _physics_process(delta: float) -> void:
	# Gravitatsiya har doim.
	if not is_on_floor():
		velocity.y -= gravity * delta

	if _state == State.DEAD:
		move_and_slide()
		return

	_update_perception(delta)
	_think(delta)

	# Harakatda bo'lsa — yaqin dushmanlardan itariladi (ustma-ust to'planmasin).
	if _desired_vel.length() > 0.05:
		var sep: Vector3 = _separation()
		_desired_vel.x += sep.x
		_desired_vel.z += sep.z

	_apply_movement(_desired_vel, delta)   # tezlanish/sekinlash chegarasi (silliq)
	_apply_rotation(delta)                 # burilish tezligi chegarasi (silliq)
	_update_anim()

	# DIQQAT: butun skriptda move_and_slide() FAQAT shu yerda — bir kadrda bir marta.
	move_and_slide()


# --- Fikrlash (holat dispetcheri) ---

func _think(delta: float) -> void:
	if not _ensure_player():
		_desired_vel = Vector3.ZERO
		return
	match _state:
		State.GUARD:
			_do_guard(delta)
		State.PATROL:
			_do_patrol(delta)
		State.INVESTIGATE:
			_do_investigate(delta)
		State.ENGAGE:
			_do_engage(delta)
		State.ADVANCE:
			_do_advance(delta)
		State.RETURN:
			_do_return(delta)
		State.ATTACK:
			_do_attack(delta)


## Postni ushlaydi, atrofga qaraydi; o'yinchi yaqin kelsa jangga.
func _do_guard(delta: float) -> void:
	_desired_vel = Vector3.ZERO
	# Postdan itarib yuborilgan bo'lsa — qaytadi.
	if _dist_to(guard_position) > guard_radius + 1.0:
		_enter_state(State.RETURN)
		return
	# Davriy atrofga qarash (tirik tuyulsin).
	_look_t -= delta
	if _look_t <= 0.0:
		_look_t = randf_range(3.0, 5.0)
		_face_yaw = _hold_yaw() + deg_to_rad(randf_range(-35.0, 35.0))
	# O'yinchini KO'RSA — jangga (post yaqinligidan qat'i nazar; leash chiqishni cheklaydi,
	# lekin qo'riqchi tirik tuyuladi: ko'rgan zahoti o'q uzadi/yaqinlashadi).
	if _can_see_player:
		_enter_state(State.ENGAGE)


## Nuqtalar bo'ylab xotirjam yuradi.
func _do_patrol(delta: float) -> void:
	if _can_see_player:
		_enter_state(State.ENGAGE)
		return
	if _leashed():
		_enter_state(State.RETURN)
		return
	if patrol_points.is_empty():
		_enter_state(State.GUARD)
		return
	var target: Vector3 = patrol_points[_patrol_idx]
	if _dist_to(target) <= 1.3:
		_desired_vel = Vector3.ZERO
		_dwell_t -= delta
		if _dwell_t <= 0.0:
			_dwell_t = randf_range(1.0, 2.0)
			_patrol_idx = (_patrol_idx + 1) % patrol_points.size()
	else:
		var v: Vector3 = _move_toward_goal(target, move_speed * 0.55, delta)
		_desired_vel = v
		if v.length() > 0.1:
			_set_face_dir(v)


## Ovoz/oxirgi ko'rilgan joyni tekshiradi, atrofga qaraydi.
func _do_investigate(delta: float) -> void:
	if _can_see_player:
		_enter_state(State.ENGAGE)
		return
	# Qattiq taymer — HAR kadr kamayadi (nuqtaga yetib bormasa ham qotib qolmaydi).
	_investigate_t -= delta
	if _last_known_pos == Vector3.INF or _investigate_t <= 0.0:
		_finish_investigate()
		return
	if _dist_to(_last_known_pos) <= 1.5:
		_desired_vel = Vector3.ZERO
		_look_t -= delta
		if _look_t <= 0.0:
			_look_t = randf_range(0.6, 1.0)
			_face_yaw = rotation.y + deg_to_rad(randf_range(-55.0, 55.0))
	else:
		var v: Vector3 = _move_toward_goal(_last_known_pos, move_speed * 0.8, delta)
		_desired_vel = v
		if v.length() > 0.1:
			_set_face_dir(v)


func _finish_investigate() -> void:
	if _is_guarding_role():
		_enter_state(State.RETURN)
	else:
		_last_known_pos = Vector3.INF
		_enter_state(State.ADVANCE)


## Jangda: melee yaqinlashadi/uradi, ranged masofa saqlab strafe qiladi va otadi.
func _do_engage(delta: float) -> void:
	if _leashed():
		_enter_state(State.RETURN)
		return
	if not _can_see_player and _time_since_seen > lose_interest_time:
		_enter_state(State.INVESTIGATE)
		return

	var ppos: Vector3 = _player.global_position
	var dist: float = _dist_to_player()

	# Granatasi bo'lsa — qulay masofada o'yinchiga uloqtirishi mumkin.
	if grenades > 0:
		_try_grenade(dist)

	if is_ranged:
		# Ko'rinmasa yoki uzoq — yaxshiroq joy izlash uchun siljiydi.
		if not _los_cached or dist > ranged_range:
			_enter_state(State.ADVANCE)
			return
		# Masofa saqlab strafe + otish.
		_desired_vel = _ranged_desired_vel(ppos, dist, delta)
		_set_face_dir(ppos - global_position)
		if attack_timer.is_stopped():
			attack_timer.start()
			_ranged_strike()
	else:
		# Melee — yaqin masofada zarbaga; aks holda yaqinlashadi.
		if dist <= attack_range and _can_see_player:
			_enter_state(State.ATTACK)
			return
		var goal: Vector3 = ppos if _can_see_player else _aim_or_player(ppos)
		var v: Vector3 = _move_toward_goal(goal, move_speed * _state_speed_factor(), delta)
		_desired_vel = v
		if v.length() > 0.1:
			_set_face_dir(v)
		else:
			_set_face_dir(ppos - global_position)


## Postga (ranged) / o'yinchiga (assault) / qanotga (flanker) siljiydi.
func _do_advance(delta: float) -> void:
	var dist: float = _dist_to_player()
	if grenades > 0 and _can_see_player:
		_try_grenade(dist)
	if _can_see_player:
		if is_ranged:
			if _los_cached and dist <= ranged_range:
				_enter_state(State.ENGAGE)
				return
		else:
			_enter_state(State.ENGAGE)
			return
	if _leashed():
		_enter_state(State.RETURN)
		return

	var spd: float = move_speed * _state_speed_factor()
	if is_ranged and not _aggressive:
		# O'q uzish postiga boradi; yetib borsa — o'yinchini kutib turadi (otish masofasiga kirsa ENGAGE).
		if _dist_to(guard_position) <= guard_radius:
			_desired_vel = Vector3.ZERO
			_face_yaw = _hold_yaw()
			return
		var v: Vector3 = _move_toward_goal(guard_position, spd, delta)
		_desired_vel = v
		if v.length() > 0.1:
			_set_face_dir(v)
	else:
		# Assault/Flanker — yoki "bosqin"dagi (aggressive) har qanday rol — o'yinchiga.
		var goal: Vector3
		if _aggressive:
			goal = _player.global_position   # to'g'ridan-to'g'ri o'yinchiga (storm)
		else:
			goal = _aim_or_player(_player.global_position)
			if role == Role.FLANKER and _dist_to_player() > attack_range * 2.5:
				goal = _flank_target()
		var v: Vector3 = _move_toward_goal(goal, spd, delta)
		_desired_vel = v
		if v.length() > 0.1:
			_set_face_dir(v)
		# Oxirgi ko'rilgan joyga yetib bordi-yu o'yinchi yo'q — tekshiradi (aggressive emas).
		if not _aggressive and _last_known_pos != Vector3.INF and _dist_to(_last_known_pos) <= 1.5 and not _can_see_player:
			_enter_state(State.INVESTIGATE)


## Postiga qaytadi.
func _do_return(delta: float) -> void:
	# O'yinchi yana yaqin va ko'rinsa — jangga qaytadi.
	if _can_see_player and _dist_post_to_player() <= engage_range and not _leashed():
		_enter_state(State.ENGAGE)
		return
	if _dist_to(guard_position) <= guard_radius * 0.6:
		_face_yaw = _hold_yaw()
		if role == Role.PATROL:
			_enter_state(State.PATROL)
		elif is_ranged:
			_enter_state(State.ADVANCE)
		else:
			_enter_state(State.GUARD)
		return
	var v: Vector3 = _move_toward_goal(guard_position, move_speed * 0.8, delta)
	_desired_vel = v
	if v.length() > 0.1:
		_set_face_dir(v)


## Melee zarba holati: turib, o'yinchiga qarab, taymer bo'sh bo'lsa uradi.
func _do_attack(_delta: float) -> void:
	_desired_vel = Vector3.ZERO
	if is_instance_valid(_player):
		_set_face_dir(_player.global_position - global_position)
	if _dist_to_player() > attack_range * 1.3:
		_enter_state(State.ENGAGE)
		return
	if attack_timer.is_stopped():
		attack_timer.start()
		_strike()


# --- Harakat quvuri (silliqlash) ---

## Joriy gorizontal tezlikni maqsad tezlikka tezlanish/sekinlash chegarasi bilan yaqinlashtiradi.
func _apply_movement(target_planar: Vector3, delta: float) -> void:
	var cur := Vector3(velocity.x, 0.0, velocity.z)
	var rate: float = accel if target_planar.length() > cur.length() else decel
	var nv: Vector3 = cur.move_toward(target_planar, rate * delta)
	velocity.x = nv.x
	velocity.z = nv.z


## Tanani _face_yaw tomon burilish tezligi chegarasi bilan buradi (keskin "snap" emas).
func _apply_rotation(delta: float) -> void:
	rotation.y = rotate_toward(rotation.y, _face_yaw, deg_to_rad(turn_rate_deg) * delta)


## Yo'nalishdan burilish (yaw) hisoblaydi. Belgisi qotirilgan: model oldi = -Z (look_at bilan bir xil).
func _yaw_from_dir(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


func _set_face_dir(dir: Vector3) -> void:
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length_squared() > 0.0004:
		_face_yaw = _yaw_from_dir(d)


## Postda turganda qarash yo'nalishi (face_dir_deg: 0 = janub/+Z, o'yinchi tomon).
func _hold_yaw() -> float:
	var d := Vector3(sin(deg_to_rad(face_dir_deg)), 0.0, cos(deg_to_rad(face_dir_deg)))
	return _yaw_from_dir(d)


# --- Navigatsiya ---

func _nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(nav.get_navigation_map()) != 0


## Yo'lni (kerak bo'lsa) qayta hisoblaydi — har kadr emas (tejamkor + barqaror).
func _request_path_to(goal: Vector3, delta: float) -> void:
	_repath_accum -= delta
	if _repath_accum <= 0.0 or _goal.distance_to(goal) > 1.5:
		_goal = goal
		nav.target_position = goal
		_repath_accum = repath_interval + randf() * 0.1


## Maqsad tomon yo'lning keyingi nuqtasiga qarab desired tezlik qaytaradi (navmesh tayyor bo'lsa).
func _move_toward_goal(goal: Vector3, speed: float, delta: float) -> Vector3:
	if not _nav_ready():
		return Vector3.ZERO
	_request_path_to(goal, delta)
	if nav.is_navigation_finished():
		return Vector3.ZERO
	var next_pos: Vector3 = nav.get_next_path_position()
	var dir: Vector3 = global_position.direction_to(next_pos)
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return Vector3.ZERO
	return dir.normalized() * speed


## Ranged: masofa saqlab yon tomonga strafe qiladi (ideal_range atrofida tursin).
func _ranged_desired_vel(player_pos: Vector3, dist: float, delta: float) -> Vector3:
	if tower_sniper:
		return Vector3.ZERO   # minora snayperi joyidan jilmaydi (faqat aylanadi/otadi)
	_strafe_flip_t -= delta
	if _strafe_flip_t <= 0.0:
		_strafe_flip_t = randf_range(1.5, 3.0)
		_strafe_sign = -_strafe_sign
	# To'siqqa urilsa — strafe yo'nalishini almashtiramiz, lekin sovish bilan
	# (har kadr emas — aks holda doimiy kontaktda titrab qoladi).
	_strafe_collide_cd -= delta
	if get_slide_collision_count() > 0 and _strafe_collide_cd <= 0.0:
		_strafe_sign = -_strafe_sign
		_strafe_collide_cd = 0.5
	var to := player_pos - global_position
	to.y = 0.0
	if to.length() < 0.1:
		return Vector3.ZERO
	var fwd := to.normalized()
	var side := fwd.cross(Vector3.UP) * _strafe_sign
	var radial := 0.0
	if dist < ideal_range - 1.0:
		radial = 1.0       # juda yaqin — orqaga
	elif dist > ideal_range + 2.0:
		radial = -1.0      # uzoq — yaqinlash
	var scale: float = 0.4 if role == Role.MARKSMAN else 0.9
	var v := side * 0.7 - fwd * radial * 0.6
	if v.length_squared() < 0.0001:
		return Vector3.ZERO
	return v.normalized() * move_speed * scale


## FLANKER: o'yinchining yon tomonidagi maqsad nuqta.
func _flank_target() -> Vector3:
	if not is_instance_valid(_player):
		return global_position
	var right := _player.global_transform.basis.x
	right.y = 0.0
	if right.length() < 0.01:
		right = Vector3.RIGHT
	return _player.global_position + right.normalized() * float(flank_side) * 8.0


## Granata: qulay masofada (LOS bilan) o'yinchiga uloqtiradi. Limitli (grenades soni).
func _try_grenade(dist: float) -> bool:
	if grenades <= 0 or _grenade_cd > 0.0:
		return false
	if dist < 8.0 or dist > 22.0:
		return false
	if not _los_cached or not is_instance_valid(_player):
		return false
	_throw_grenade()
	grenades -= 1
	_grenade_cd = 7.0
	return true


## Granata snaryadini hosil qilib o'yinchiga balistik yoy bilan uloqtiradi (mavjud tizim).
func _throw_grenade() -> void:
	if not ResourceLoader.exists("res://scenes/fx/grenade.tscn"):
		return
	var origin: Vector3 = global_position + Vector3(0, 1.3, 0) - global_transform.basis.z * 0.5
	var target: Vector3 = _player.global_position if is_instance_valid(_player) else _last_known_pos
	var to: Vector3 = target - origin
	var hdir: Vector3 = Vector3(to.x, 0.0, to.z)
	var d: float = hdir.length()
	if d < 0.3:
		return
	hdir = hdir.normalized()
	var g: Node3D = (load("res://scenes/fx/grenade.tscn") as PackedScene).instantiate()
	g.grenade_type = "frag"
	g.position = origin   # current_scene (Main) ildizda — local = global
	get_tree().current_scene.add_child(g)
	var h_speed: float = clampf(d * 0.75, 6.0, 15.0)
	g.linear_velocity = hdir * h_speed + Vector3.UP * 4.0
	g.angular_velocity = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
	if _anim != null and _anim.has_animation("attack"):
		_anim.play("attack")


## Oxirgi ko'rilgan joy ma'lum bo'lsa — o'sha; aks holda o'yinchining hozirgi joyi.
func _aim_or_player(ppos: Vector3) -> Vector3:
	return _last_known_pos if _last_known_pos != Vector3.INF else ppos


## Holatga qarab tezlik koeffitsienti (rolga ham bog'liq).
func _state_speed_factor() -> float:
	match _state:
		State.RETURN:
			return 0.8
		State.PATROL:
			return 0.55
		State.INVESTIGATE:
			return 0.8
		State.ADVANCE, State.ENGAGE:
			match role:
				Role.FLANKER:
					return 1.1
				Role.ASSAULT:
					return 1.0
				Role.MARKSMAN:
					return 0.7
				Role.RIFLEMAN:
					return 0.85
				_:
					return 0.9
		_:
			return 1.0


# --- Yaqin dushmanlardan itarilish (boids separation) ---

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


# --- Idrok (perception) ---

func _update_perception(delta: float) -> void:
	_time_since_seen += delta
	if _grenade_cd > 0.0:
		_grenade_cd -= delta
	_percept_accum -= delta
	if _percept_accum > 0.0:
		return
	_percept_accum = PERCEPT_INTERVAL + randf() * 0.05
	_can_see_player = _check_vision()
	_los_cached = _can_see_player
	if _can_see_player:
		_last_known_pos = _player.global_position
		_time_since_seen = 0.0


## Ko'rish: masofa (kvadrat) + konus arzon tekshiruvlardan keyingina LOS ray otadi.
func _check_vision() -> bool:
	if not is_instance_valid(_player):
		return false
	var to: Vector3 = _player.global_position - global_position
	if to.length_squared() > vision_range * vision_range:
		return false
	var flat := Vector3(to.x, 0.0, to.z)
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	if flat.length() > 0.01 and fwd.length() > 0.01:
		if flat.normalized().dot(fwd.normalized()) < cos(deg_to_rad(vision_fov_deg * 0.5)):
			# Konusdan tashqarida — faqat juda yaqin bo'lsa sezadi (orqa tomon).
			if to.length() > 4.0:
				return false
	return _has_line_of_sight()


## O'yinchi o'q uzganda (eshitish) — yaqin bo'lsa tovush joyini tekshiradi.
func _on_player_fired(pos: Vector3) -> void:
	if _state == State.DEAD or _state == State.ENGAGE or _state == State.ADVANCE or _state == State.ATTACK:
		return
	if global_position.distance_to(pos) <= hearing_range:
		_last_known_pos = pos
		if _state == State.GUARD or _state == State.PATROL or _state == State.RETURN:
			_enter_state(State.INVESTIGATE)


# --- Holat o'tishi ---

func _enter_state(s: State) -> void:
	_state = s
	match s:
		State.PATROL:
			_dwell_t = randf_range(1.0, 2.0)
		State.INVESTIGATE:
			_investigate_t = 4.0   # umumiy byudjet: yurish + qarash (qotib qolmaslik kafolati)
			_look_t = 0.0
		State.GUARD:
			_look_t = randf_range(1.0, 3.0)


func _is_guarding_role() -> bool:
	return role == Role.SENTRY or role == Role.PATROL or role == Role.RIFLEMAN or role == Role.MARKSMAN


## Postga bog'langan rol postdan juda uzoqlashganmi?
func _leashed() -> bool:
	if _aggressive or role == Role.ASSAULT or role == Role.FLANKER:
		return false
	return _dist_to(guard_position) > leash_range


## Wave failsafe (wave_manager chaqiradi): hech kim o'yinchiga yetolmasa — dushman "bosqin"ga
## o'tadi (leash bekor, to'g'ridan-to'g'ri o'yinchiga yuradi). Garnizon hissi boshda saqlanadi,
## lekin wave doim tugaydi va o'yinchi hech qachon "bo'sh maydon"da yolg'iz qolmaydi.
func go_aggressive() -> void:
	if _state == State.DEAD or _aggressive or tower_sniper:
		return   # minora snayperi "bosqin"da ham joyida qoladi (tushib ketmaydi)
	_aggressive = true
	leash_range = 99999.0
	if is_instance_valid(_player):
		_last_known_pos = _player.global_position
		_time_since_seen = 0.0
	if _state == State.GUARD or _state == State.PATROL or _state == State.RETURN or _state == State.INVESTIGATE:
		_enter_state(State.ADVANCE)


# --- Zarba (melee) ---

## Zarba: qisqa tayyorgarlikdan keyin o'yinchiga zarar yetkazadi.
func _strike() -> void:
	if _anim != null and _anim.has_animation("attack"):
		_anim.play("attack")
	await get_tree().create_timer(attack_windup, false).timeout
	# await dan KEYIN holat o'zgargan bo'lishi mumkin — qayta tekshiramiz.
	if _state != State.ATTACK:
		return
	if not is_instance_valid(_player):
		return
	if _dist_to_player() > attack_range * 1.3:
		return
	if _player.has_method("take_damage"):
		_player.take_damage(attack_damage)


## Masofadan otish: tayyorgarlikdan keyin, LOS bo'lsa, hitscan zarar beradi.
func _ranged_strike() -> void:
	if _anim != null and _anim.has_animation("attack"):
		_anim.play("attack")
	await get_tree().create_timer(attack_windup, false, true).timeout
	if _state != State.ENGAGE or not is_instance_valid(_player):
		return
	if not _has_line_of_sight():
		return
	_enemy_muzzle_flash()
	var muzzle_pos: Vector3 = global_position - global_transform.basis.z * 0.7 + Vector3(0, 1.0, 0)
	var hit_pos: Vector3 = _player.global_position + Vector3(0, 1.1, 0)
	_spawn_tracer(muzzle_pos, hit_pos)
	_spawn_impact(hit_pos)
	if _player.has_method("take_damage"):
		_player.take_damage(ranged_damage)


## O'q izi (tracer) — ikki nuqta orasida qisqa yorug' chiziq.
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


## Tekkan joyda kichik uchqun.
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
	# Minora snayperi ko'zlari balandroq — o'z panjarasi nurni to'smasin (pastga qaraydi).
	var eye_h: float = 1.9 if tower_sniper else 1.4
	var from: Vector3 = global_position + Vector3(0, eye_h, 0)
	var to: Vector3 = _player.global_position + Vector3(0, 1.2, 0)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1 | 2   # world + player
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	return not hit.is_empty() and hit.collider == _player


## Dushman quroli uchida qisqa alanga (otganda).
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
	flash.global_position = global_position - global_transform.basis.z * 0.7 + Vector3(0, 1.0, 0)
	get_tree().create_timer(0.07).timeout.connect(flash.queue_free)


# --- Yordamchi funksiyalar ---

func _update_anim() -> void:
	if _anim == null:
		return
	if _state == State.DEAD:
		return
	if _anim.current_animation == "attack":
		return
	var spd: float = Vector2(velocity.x, velocity.z).length()
	var want: String = "idle"
	if spd > move_speed * 0.55:
		want = "run"
	elif spd > 0.4:
		want = "walk"
	else:
		# Turgan holat — rolga/holatga qarab.
		if is_ranged and (_state == State.ENGAGE or _state == State.ATTACK or _state == State.ADVANCE):
			want = "aim"
		elif _state == State.GUARD or _state == State.INVESTIGATE or _state == State.RETURN:
			want = "alert"
		else:
			want = "idle"
	# Fallback: animatsiya hali GLB'da bo'lmasa (regeneratsiyadan oldin) — idle/run.
	if not _anim.has_animation(want):
		want = "run" if spd > 0.4 else "idle"
	if _anim.current_animation != want:
		_anim.play(want)


func _ensure_player() -> bool:
	if is_instance_valid(_player):
		return true
	_player = get_tree().get_first_node_in_group("player")
	return is_instance_valid(_player)


func _dist_to(p: Vector3) -> float:
	return Vector2(global_position.x - p.x, global_position.z - p.z).length()


func _dist_to_player() -> float:
	if not is_instance_valid(_player):
		return INF
	return _dist_to(_player.global_position)


func _dist_post_to_player() -> float:
	if not is_instance_valid(_player):
		return INF
	return Vector2(guard_position.x - _player.global_position.x, guard_position.z - _player.global_position.z).length()


# --- Zarar olish va o'lim ---

func take_damage(amount: float) -> void:
	if _state == State.DEAD:
		return
	health -= amount
	_flash()
	_blood_burst()
	# O'q tekkani — qayerdan otilganini bildiradi. ORQADAN otilsa ham DARROV sezadi:
	# o'sha tomonga buriladi (qarab qotib qolmaydi) va jangga kiradi (har qanday holatdan).
	if is_instance_valid(_player):
		_last_known_pos = _player.global_position
		_time_since_seen = 0.0
		var to: Vector3 = _player.global_position - global_position
		to.y = 0.0
		if to.length() > 0.1:
			_face_yaw = _yaw_from_dir(to)   # darrov shu tomonga buriladi (tez turn)
		if _state != State.ENGAGE and _state != State.ATTACK:
			_enter_state(State.ENGAGE)
	if health <= 0.0:
		_die()


func _flash() -> void:
	if _mesh_inst == null:
		return
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.emission_enabled = true
	m.emission = Color(1, 1, 1)
	_mesh_inst.material_override = m
	get_tree().create_timer(0.12).timeout.connect(_clear_flash)


func _clear_flash() -> void:
	if is_instance_valid(_mesh_inst):
		_mesh_inst.material_override = null


func _die() -> void:
	_state = State.DEAD
	set_physics_process(false)
	remove_from_group("enemy")
	set_collision_layer_value(3, false)
	collision_shape.set_deferred("disabled", true)
	Events.enemy_died.emit(self)
	_blood_pool()
	# Jasad TABIIY yerda yotsin: butun modelni gorizontal ag'daramiz.
	if _anim != null and _anim.has_animation("idle"):
		_anim.play("idle")
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(model, "rotation_degrees:x", 90.0, 0.4)
	tw.tween_property(model, "position:y", 0.13, 0.4)
	await get_tree().create_timer(corpse_lifetime, false).timeout
	queue_free()


## Tekkanda qisqa qizil "qon" purkagichi.
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


## O'lganda yerga qon ko'lmagi.
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
	get_tree().create_timer(corpse_lifetime, false).timeout.connect(p.queue_free)
