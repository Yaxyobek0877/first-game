extends CharacterBody3D
## Birinchi shaxs (FPS) o'yinchi nazoratchisi.
## CharacterBody3D — bu fizikaga bo'ysunadigan, lekin biz qo'lda boshqaradigan tana.
##
## Vazifalari:
##   - WASD bilan yurish, Shift bilan yugurish
##   - Sichqoncha bilan atrofga qarash (mouse look)
##   - Probel (Space) bilan sakrash + gravitatsiya
##   - Esc bilan sichqonchani bo'shatish (pauza/menyu uchun)

# --- Sozlamalar (Inspector'dan o'zgartirsa bo'ladi, @export shuni beradi) ---
@export var walk_speed: float = 5.0           ## Oddiy yurish tezligi (m/s)
@export var sprint_speed: float = 8.0         ## Yugurish tezligi (Shift bosilganda)
@export var jump_velocity: float = 5.0        ## Sakrash kuchi
@export var gravity: float = 20.0             ## Tortishish (haqiqiy 9.8 dan kattaroq — "tezroq" his uchun)
@export var mouse_sensitivity: float = 0.0025 ## Sichqoncha sezgirligi

# --- Cho'kkalash (Ctrl) / yotish (Z) holatlari ---
@export var stand_height: float = 1.8    ## Tik turgandagi kapsula balandligi
@export var crouch_height: float = 1.1   ## Cho'kkalagandagi
@export var prone_height: float = 0.8    ## Yotgandagi (kapsula min = 2*radius = 0.8)
@export var stand_head: float = 1.6      ## Kamera balandligi — tik
@export var crouch_head: float = 0.95    ## — cho'kkalagan
@export var prone_head: float = 0.4      ## — yotgan
@export var crouch_speed: float = 2.8    ## Cho'kkalab yurish tezligi
@export var prone_speed: float = 1.3     ## Yotib emaklash tezligi
@export var stance_lerp: float = 10.0    ## Holat o'tishi silliqligi (balandlik/kamera)

enum Stance { STAND, CROUCH, PRONE }     ## Indeks ham balandlik tartibi: 0=eng baland
var _stance: int = Stance.STAND
var _want_prone: bool = false            ## Z bilan almashtiriladigan yotish istagi (toggle)
var _cur_height: float = 1.8             ## Joriy (silliq) kapsula balandligi
var _cur_head: float = 1.6               ## Joriy (silliq) kamera balandligi

# --- Sirpanish (slide) — ikkita Ctrl (double-tap) bilan ---
@export var slide_speed: float = 9.5     ## Slayd boshidagi oldinga tezlik (m/s)
@export var slide_duration: float = 0.65 ## Slayd davomiyligi (s)
@export var slide_cooldown: float = 0.5  ## Slaydlar orasidagi minimal tanaffus (s)
const SLIDE_DOUBLE_TAP := 0.30           ## Ikki Ctrl orasidagi maksimal vaqt (s)
var _sliding: bool = false
var _slide_t: float = 0.0                ## Qolgan slayd vaqti
var _slide_cd: float = 0.0               ## Cooldown taymeri
var _slide_dir: Vector3 = Vector3.ZERO   ## Slayd yo'nalishi (boshlanishda qotiriladi)
var _crouch_tap_time: float = -999.0     ## Oxirgi Ctrl bosilgan vaqt (double-tap aniqlash)

# --- Egilish (lean / peek) — Q chapga, E o'ngga (beli bukilishi hissi) ---
@export var lean_offset: float = 0.45    ## Egilganda kamera yon siljishi (m)
@export var lean_angle: float = 14.0     ## Egilganda kamera ag'darilishi (daraja) — beli bukilishi
@export var lean_lerp: float = 10.0      ## Egilish silliqligi
const SLIDE_ROLL_DEG := 6.0              ## Slaydda kamera ag'darilishi (daraja)
var _lean: float = 0.0                   ## Joriy egilish: -1 (chap) .. +1 (o'ng)
var _slide_roll_cur: float = 0.0         ## Slayd ag'darilishi (silliq, _update_view_lean'da)

# --- Narvon (ladder) — minoraga chiqish/tushish ---
@export var climb_speed: float = 3.2     ## Narvonda yuqori/quyi tezlik (m/s)
var _climbing: bool = false              ## Hozir narvondami
var _climb_ladder: Area3D = null         ## Joriy narvon zonasi (metama'lumot manbai)
var _near_ladders: Array = []            ## Ustida turgan narvon zonalari (kirish uchun)
var _climb_cd: float = 0.0               ## Sakrab tushgach darrov qayta yopishmaslik sovishi
var _climb_bob_phase: float = 0.0        ## Kamera tebranishi (chiqish hissi) fazasi
var _climb_step_t: float = 0.0           ## Narvon "pog'ona" tovushi intervali

# --- Jon ---
@export var max_health: float = 100.0
@export var regen_rate: float = 8.0      ## Jon tiklanish tezligi (HP/s)
@export var regen_delay: float = 4.0     ## Zarardan keyin shu vaqtdan so'ng tiklanish boshlanadi
var health: float
var _is_dead: bool = false       ## O'lim oqimi faqat bir marta ishlashi uchun (qayta o'lmaslik)
var _since_damage: float = 999.0 ## Oxirgi zarardan beri o'tgan vaqt (regen uchun)
var _step_player: AudioStreamPlayer   ## Qadam tovushi
var _step_time: float = 0.0           ## Keyingi qadamgacha qolgan vaqt

# --- Sahnadagi tugunlarga havola (@onready — sahna yuklangach to'ldiriladi) ---
@onready var head: Node3D = $Head             ## Yuqoriga/pastga qarash shu tugunni aylantiradi
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	health = max_health
	# Dushman o'yinchini topa olishi uchun "player" guruhiga qo'shamiz.
	# Dushman get_tree().get_first_node_in_group("player") orqali bizni topadi —
	# qattiq yo'l (path) yozmasdan, decoupling saqlanadi.
	add_to_group("player")
	# O'yin boshlanganda sichqonchani "qamab" qo'yamiz — ekrandan chiqib ketmaydi.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Kapsula shaklini nusxalaymiz (runtime balandlik o'zgarishi saqlangan resursga tegmasin).
	collision_shape.shape = collision_shape.shape.duplicate()
	_cur_height = (collision_shape.shape as CapsuleShape3D).height
	_cur_head = head.position.y
	# Sichqoncha sezgirligini sozlanmalardan olamiz (jonli — o'zgarsa yangilanadi).
	mouse_sensitivity = GameSettings.mouse_sensitivity
	GameSettings.changed.connect(func() -> void: mouse_sensitivity = GameSettings.mouse_sensitivity)
	# O'yin paytida musiqa eshitilmasin — menyu trekini silliq so'ndiramiz.
	MusicPlayer.fade_out()
	# Qadam tovushi pleyeri (WAV — protsedural SFX). "SFX" shinasiga ulanadi.
	_step_player = AudioStreamPlayer.new()
	_step_player.stream = load("res://assets/audio/footstep.wav")
	_step_player.bus = "SFX"
	add_child(_step_player)
	# HUD boshlang'ich jonni ko'rsatishi uchun signal yuboramiz.
	# call_deferred — HUD signalga ulanib ulgurishi uchun (aks holda birinchi zarbada
	# qizil chaqnash ishlamaydi, chunki HUD _prev_health -1 da qoladi).
	Events.player_health_changed.emit.call_deferred(health, max_health)


func _unhandled_input(event: InputEvent) -> void:
	# Sichqoncha harakati — faqat qamalgan holatda atrofga qaraymiz.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Chap/o'ng — butun tanani Y o'qi atrofida aylantiramiz.
		rotate_y(-event.relative.x * mouse_sensitivity)
		# Yuqori/past — faqat boshni (kamerani) X o'qi atrofida.
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		# Boshni 90 darajadan ortiq egmaslik uchun cheklaymiz (orqaga ag'darilmaslik).
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
	# Esc (pauza) endi PauseMenu tomonidan boshqariladi — bu yerda emas.


func _physics_process(delta: float) -> void:
	# Egilish (Q/E) + kamera ag'darilishi — har kadr, holatdan qat'i nazar (return'lardan oldin).
	_update_view_lean(delta)

	# 0) Narvon rejimi — normal harakatdan OLDIN (gravitatsiya/stance'siz).
	if _climb_cd > 0.0:
		_climb_cd -= delta
	if _climbing:
		_process_climb(delta)
		return
	var to_climb: Area3D = _ladder_to_climb()
	if to_climb != null:
		_start_climb(to_climb)
		_process_climb(delta)
		return

	# 0.5) Sirpanish (slide) — ikkita Ctrl bilan. Boshlangan bo'lsa normal harakatdan oldin.
	if _slide_cd > 0.0:
		_slide_cd -= delta
	if _sliding:
		_process_slide(delta)
		return
	if _check_slide_start():
		_start_slide()
		_process_slide(delta)
		return

	# 1) Gravitatsiya — yerda turmagan bo'lsak, pastga tortamiz.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2) Cho'kkalash/yotish holatini yangilaymiz (silliq balandlik + kamera + obstruksiya).
	_update_stance(delta)

	# 3) Sakrash — faqat tik turganda va yerda. (Cho'kkalagan/yotgan holatda sakralmaydi.)
	if Input.is_action_just_pressed("jump") and is_on_floor() and _stance == Stance.STAND:
		velocity.y = jump_velocity

	# 4) Yurish yo'nalishini hisoblaymiz.
	#    get_vector(chap, o'ng, oldinga, orqaga) -> Vector2 qaytaradi.
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Yo'nalishni o'yinchi qaragan tomonga moslaymiz (transform.basis).
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var speed: float = _current_speed()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		# Tugma bosilmasa — tezlikni silliq nolga tushiramiz (to'satdan to'xtamaydi).
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	# 4) Harakatni qo'llaymiz — Godot devorlar/yer bilan to'qnashuvni o'zi hal qiladi.
	move_and_slide()

	# 5) Qadam tovushi — yerda yurganda interval bilan.
	_footsteps(delta)

	# 6) Jon tiklanishi — zarardan keyin biroz kutib, sekin tiklanadi.
	_regen(delta)


## Cho'kkalash/yotish holatini boshqaradi: kiritishni o'qiydi, balandlik joy bo'lsa
## ko'tariladi (obstruksiya tekshiruvi), kapsula va kamerani SILLIQ moslaydi.
func _update_stance(delta: float) -> void:
	# Z — yotishni toggle qiladi; Ctrl — har doim cho'kkalashga majbur (yotishni bekor qiladi).
	if Input.is_action_just_pressed("prone"):
		_want_prone = not _want_prone
	var crouch_held: bool = Input.is_action_pressed("crouch")
	if crouch_held:
		_want_prone = false

	var desired: int = Stance.PRONE if _want_prone else (Stance.CROUCH if crouch_held else Stance.STAND)

	# Pastroqqa (yoki bir xil) o'tish doim mumkin; balandroqqa — faqat tepada joy bo'lsa.
	if desired < _stance:
		_stance = _resolve_stance(desired)   # ko'tarilish: tepada to'siq bo'lsa pastroqda qoladi
	else:
		_stance = desired

	# Silliq o'tish: balandlik va kamera maqsadga lerp bilan yaqinlashadi.
	_cur_height = lerpf(_cur_height, _stance_height(_stance), clampf(delta * stance_lerp, 0.0, 1.0))
	_cur_head = lerpf(_cur_head, _stance_head(_stance), clampf(delta * stance_lerp, 0.0, 1.0))
	_apply_capsule(_cur_height)
	head.position.y = _cur_head


## desired'dan boshlab (eng baland xohlangan) PRONE'gacha — tepada joy bo'lgan eng balandini qaytaradi.
func _resolve_stance(desired: int) -> int:
	for s in range(desired, Stance.PRONE + 1):   # desired, ..., PRONE
		if not _stance_blocked(_stance_height(s)):
			return s
	return Stance.PRONE   # hammasi to'silган bo'lsa (kam ehtimol) — yotgan holatda qolamiz


## Berilgan balandlikdagi kapsula o'yinchi joyida dunyo (world, 1-qatlam) geometriyasi
## bilan kesishadimi? (Tepada quti/platforma bo'lsa tik turishga yo'l qo'ymaymiz.)
func _stance_blocked(h: float) -> bool:
	var space := get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38   # asl 0.4 dan biroz kichik — devorga yopishganda noto'g'ri bloklamasin
	cap.height = h
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = cap
	params.transform = Transform3D(Basis(), global_position + Vector3(0.0, h * 0.5, 0.0))
	params.collision_mask = 1   # faqat world (dushman boshda tursa ham turaveramiz)
	params.exclude = [get_rid()]
	return space.intersect_shape(params, 1).size() > 0


func _stance_height(s: int) -> float:
	match s:
		Stance.CROUCH: return crouch_height
		Stance.PRONE: return prone_height
		_: return stand_height


func _stance_head(s: int) -> float:
	match s:
		Stance.CROUCH: return crouch_head
		Stance.PRONE: return prone_head
		_: return stand_head


## Joriy holatga mos yurish tezligi (yugurish faqat tik turganda).
func _current_speed() -> float:
	match _stance:
		Stance.CROUCH: return crouch_speed
		Stance.PRONE: return prone_speed
		_: return sprint_speed if Input.is_action_pressed("sprint") else walk_speed


## Ikkita Ctrl (double-tap) bosilganini aniqlaydi (yerda, slaydsiz, cooldownsiz).
func _check_slide_start() -> bool:
	if not Input.is_action_just_pressed("crouch"):
		return false
	var now: float = Time.get_ticks_msec() / 1000.0
	if not is_on_floor() or _sliding or _slide_cd > 0.0:
		_crouch_tap_time = now
		return false
	var is_double: bool = (now - _crouch_tap_time) < SLIDE_DOUBLE_TAP
	_crouch_tap_time = now
	return is_double


## Slaydni boshlaydi: yo'nalishni qotiradi (harakatda — shu tomon; jim — qaragan tomon).
func _start_slide() -> void:
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	if horiz.length() > 0.5:
		_slide_dir = horiz.normalized()
	else:
		_slide_dir = (-transform.basis.z).normalized()   # qaragan tomon (oldinga)
	_sliding = true
	_slide_t = slide_duration
	_want_prone = false
	_stance = Stance.CROUCH   # slayd past holatda


## Slayd kadri: qotirilgan yo'nalishda tezligi sekinlashib, past kamerada oldinga sirpanadi.
func _process_slide(delta: float) -> void:
	_slide_t -= delta
	if not is_on_floor():
		velocity.y -= gravity * delta
	# Tezlik slide_speed dan crouch_speed gacha silliq pasayadi (ishqalanish hissi).
	var frac: float = clampf(_slide_t / slide_duration, 0.0, 1.0)
	var spd: float = lerpf(crouch_speed, slide_speed, frac)
	velocity.x = _slide_dir.x * spd
	velocity.z = _slide_dir.z * spd
	# Past holat + biroz qo'shimcha tushish (slayd kamera ag'darilishi _update_view_lean'da).
	var k: float = clampf(delta * stance_lerp, 0.0, 1.0)
	_cur_height = lerpf(_cur_height, crouch_height, k)
	_cur_head = lerpf(_cur_head, crouch_head - 0.12, k)
	_apply_capsule(_cur_height)
	head.position.y = _cur_head
	move_and_slide()
	_regen(delta)
	# Sakrash slaydni bekor qiladi (slide-jump); vaqt tugasa yoki sekinlashsa ham tugaydi.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		_end_slide()
		velocity.y = jump_velocity
		return
	if _slide_t <= 0.0 or Vector2(velocity.x, velocity.z).length() < crouch_speed * 0.6:
		_end_slide()


## Slaydni tugatadi: cooldown qo'yadi (holat keyin _update_stance da; roll _update_view_lean'da so'nadi).
func _end_slide() -> void:
	_sliding = false
	_slide_cd = slide_cooldown


## Egilish (Q/E) + kamera ag'darilishi: yon siljish (head.position.x) + roll (head.rotation.z).
## Slaydda lean o'rniga slayd ag'darilishi; narvonda head.position.x ni climb bob boshqaradi.
func _update_view_lean(delta: float) -> void:
	var target := 0.0
	if not _climbing and not _sliding and not _is_dead:
		if Input.is_action_pressed("lean_right"):
			target += 1.0
		if Input.is_action_pressed("lean_left"):
			target -= 1.0
		target = _lean_allowed(target)
	_lean = lerpf(_lean, target, clampf(delta * lean_lerp, 0.0, 1.0))
	# Slayd ag'darilishi — faqat slaydda; silliq kirib-chiqadi.
	var sroll: float = SLIDE_ROLL_DEG if _sliding else 0.0
	_slide_roll_cur = lerpf(_slide_roll_cur, sroll, clampf(delta * 9.0, 0.0, 1.0))
	if not _climbing:
		head.position.x = _lean * lean_offset   # yon siljish (egilish)
	# Roll: egilish (o'ng=manfiy) + slayd ag'darilishi (beli bukilishi hissi).
	head.rotation.z = deg_to_rad(-_lean * lean_angle + _slide_roll_cur)


## Egilish yo'nalishida devor bo'lsa egilmaymiz (kamera devorga kirib ketmasin).
func _lean_allowed(target: float) -> float:
	if is_zero_approx(target):
		return 0.0
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0.0, _cur_head, 0.0)
	var to := from + global_transform.basis.x * (lean_offset * 1.3 * target)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1   # faqat world
	q.exclude = [get_rid()]
	return 0.0 if not space.intersect_ray(q).is_empty() else target


## Kapsula balandligini o'rnatadi va markazini ko'taradi (oyoq yerda qoladi, tepaga "sakramaydi").
func _apply_capsule(h: float) -> void:
	var shape := collision_shape.shape as CapsuleShape3D
	if shape == null:
		return
	shape.height = maxf(h, 2.0 * shape.radius)   # kapsula balandligi >= 2*radius bo'lishi shart
	collision_shape.position.y = shape.height * 0.5


func _regen(delta: float) -> void:
	if _is_dead:
		return
	_since_damage += delta
	if _since_damage >= regen_delay and health < max_health:
		health = minf(max_health, health + regen_rate * delta)
		Events.player_health_changed.emit(health, max_health)


## Yerda harakatlanganda qadam tovushini interval bilan chaladi (yugurganda tezroq).
func _footsteps(delta: float) -> void:
	if _step_player == null or _step_player.stream == null:
		return
	var moving: bool = is_on_floor() and Vector2(velocity.x, velocity.z).length() > 1.0
	if not moving:
		_step_time = 0.0
		return
	_step_time -= delta
	if _step_time <= 0.0:
		_step_player.pitch_scale = randf_range(0.9, 1.1)
		_step_player.play()
		_step_time = 0.32 if Input.is_action_pressed("sprint") else 0.46


# --- Narvon (ladder) chiqish/tushish ---

## Narvon zonasi (arena.gd) chaqiradi — yaqindagi narvonni ro'yxatga olamiz.
func enter_ladder(a: Area3D) -> void:
	if not _near_ladders.has(a):
		_near_ladders.append(a)


func exit_ladder(a: Area3D) -> void:
	_near_ladders.erase(a)


## Narvonga kirish kerakmi? Yaqin narvon bor va o'yinchi narvon tomon harakatlansa — ha.
func _ladder_to_climb() -> Area3D:
	if _climb_cd > 0.0 or _near_ladders.is_empty():
		return null
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_dir == Vector2.ZERO:
		return null
	var wish: Vector3 = transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	wish.y = 0.0
	if wish.length() < 0.1:
		return null
	wish = wish.normalized()
	for a in _near_ladders:
		if not is_instance_valid(a):
			continue
		var center: Vector3 = a.get_meta("center")
		var to_c: Vector3 = Vector3(center.x - global_position.x, 0.0, center.z - global_position.z)
		if to_c.length() < 0.4:
			# Narvon o'qida turibmiz — yuqoriga (W) bossa chiqamiz.
			if Input.is_action_pressed("move_forward"):
				return a
			continue
		if wish.dot(to_c.normalized()) > 0.35:
			return a
	return null


## Narvonga "yopishamiz": o'qqa surilamiz, holatni STAND ga majburlaymiz, tezlikni nollaymiz.
func _start_climb(lad: Area3D) -> void:
	if _sliding:
		_end_slide()   # slayd o'rtasida narvonga o'tilsa — slaydni toza tugatamiz (kamera ag'darilishi tiklanadi)
	_climbing = true
	_climb_ladder = lad
	var center: Vector3 = lad.get_meta("center")
	global_position.x = center.x
	global_position.z = center.z
	velocity = Vector3.ZERO
	# Cho'kkalash/yotish bekor — narvonda tik turamiz.
	_want_prone = false
	_stance = Stance.STAND
	_cur_height = stand_height
	_cur_head = stand_head
	_apply_capsule(stand_height)
	_climb_step_t = 0.0


## Narvon rejimi: W=yuqori, S=quyi; o'qqa tortib turamiz; Space=sakrab tushish;
## tepada platformaga chiqamiz; yerga yetganda tushamiz.
func _process_climb(delta: float) -> void:
	var lad: Area3D = _climb_ladder
	if lad == null or not is_instance_valid(lad):
		_stop_climb()
		return
	var center: Vector3 = lad.get_meta("center")
	var exit_dir: Vector3 = lad.get_meta("exit_dir")
	var top_y: float = lad.get_meta("top_y")
	var climb_in: float = Input.get_axis("move_back", "move_forward")   # W=+1, S=-1

	# Narvondan sakrab tushish.
	if Input.is_action_just_pressed("jump"):
		_stop_climb()
		velocity = -exit_dir * 4.5 + Vector3(0.0, 4.0, 0.0)
		_climb_cd = 0.4
		move_and_slide()
		return

	# Tepaga yetdi — platformaga "chiqib" olamiz (snap, chetга snag bo'lmasin).
	if climb_in > 0.0 and global_position.y >= top_y:
		_stop_climb()
		global_position += exit_dir * 1.3
		global_position.y = top_y + 0.05
		velocity = Vector3.ZERO
		_climb_cd = 0.4   # zona hali ustimizda — darrov qayta-yopishmaslik (flicker oldini olish)
		return

	# Narvon o'qiga tortib turamiz (yopishib tursin).
	var to_c: Vector3 = Vector3(center.x - global_position.x, 0.0, center.z - global_position.z)
	if to_c.length() > 1.4:
		_stop_climb()   # qandaydir tarzda uzoqlashdi — tushib ketamiz
		return
	velocity.x = clampf(to_c.x * 8.0, -walk_speed, walk_speed)
	velocity.z = clampf(to_c.z * 8.0, -walk_speed, walk_speed)
	# W=yuqori, S=quyi. Tugma bosilmasa — yengil pastga "siljiydi" (mid-air'da qotib
	# qolmaslik uchun, oxir-oqibat yerga tushadi). Yuqoriga chiqish faqat W bilan.
	if climb_in > 0.0:
		velocity.y = climb_speed
	elif climb_in < 0.0:
		velocity.y = -climb_speed
	else:
		velocity.y = -1.2

	move_and_slide()
	_climb_feedback(delta, climb_in if climb_in != 0.0 else -0.4)

	# Pastga yetdi va yuqoriga bosilmayapti — narvondan tushamiz. Yer yaqinida (y<0.6)
	# ham tushamiz: aks holda narvonsiz gravitatsiya yo'qligi uchun yer ustida osilib
	# qolardi. Faqat W (climb_in>0) bosilsa osilib turamiz (yuqoriga chiqish davom etadi).
	if climb_in <= 0.0 and (is_on_floor() or global_position.y <= 0.6):
		_stop_climb()


func _stop_climb() -> void:
	_climbing = false
	_climb_ladder = null
	head.position.x = 0.0
	head.position.y = _cur_head   # bob'ni tiklaymiz (stance qiymatiga)


## Chiqish hissi: kamera vertikal tebranadi + yengil chayqalish + pog'ona tovushi.
func _climb_feedback(delta: float, climb_in: float) -> void:
	var moving: bool = absf(climb_in) > 0.1
	if moving:
		_climb_bob_phase += delta * 7.0
	var amp: float = 1.0 if moving else 0.0
	head.position.y = stand_head + sin(_climb_bob_phase) * 0.06 * amp
	head.position.x = cos(_climb_bob_phase * 0.5) * 0.025 * amp
	if moving and _step_player != null and _step_player.stream != null:
		_climb_step_t -= delta
		if _climb_step_t <= 0.0:
			_climb_step_t = 0.45
			_step_player.pitch_scale = randf_range(0.8, 0.95)
			_step_player.play()


## Dushmanlar shu funksiyani chaqirib o'yinchiga zarar yetkazadi.
func take_damage(amount: float) -> void:
	if _is_dead:
		return
	_since_damage = 0.0   # tiklanish taymerini qayta boshlaymiz
	health = maxf(0.0, health - amount)
	Events.player_health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()


func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	# Narvonda/slaydda o'lsa — kamera ofseti/holatni toza tiklaymiz (osilib qolmasin).
	if _climbing:
		_stop_climb()
	if _sliding:
		_end_slide()
	# Sichqonchani bo'shatamiz va o'yinchini "muzlatamiz" (boshqaruvni o'chiramiz).
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_physics_process(false)        # harakat to'xtaydi
	set_process_unhandled_input(false)  # qarash/Esc to'xtaydi
	# "O'yin tugadi" ekrani shu signalni eshitadi va pauzani O'ZI qo'yadi.
	# DIQQAT: pauzani BU YERDA qo'ymaymiz — aks holda GameOver UI ham muzlab,
	# qayta boshlash tugmasi ishlamay qolishi mumkin.
	Events.player_died.emit()
	print("O'yinchi halok bo'ldi!")
