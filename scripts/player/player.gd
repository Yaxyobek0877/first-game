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


func _ready() -> void:
	health = max_health
	# Dushman o'yinchini topa olishi uchun "player" guruhiga qo'shamiz.
	# Dushman get_tree().get_first_node_in_group("player") orqali bizni topadi —
	# qattiq yo'l (path) yozmasdan, decoupling saqlanadi.
	add_to_group("player")
	# O'yin boshlanganda sichqonchani "qamab" qo'yamiz — ekrandan chiqib ketmaydi.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
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
	# 1) Gravitatsiya — yerda turmagan bo'lsak, pastga tortamiz.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2) Sakrash — faqat yerda turganda.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# 3) Yurish yo'nalishini hisoblaymiz.
	#    get_vector(chap, o'ng, oldinga, orqaga) -> Vector2 qaytaradi.
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Yo'nalishni o'yinchi qaragan tomonga moslaymiz (transform.basis).
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var speed: float = sprint_speed if Input.is_action_pressed("sprint") else walk_speed

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
	# Sichqonchani bo'shatamiz va o'yinchini "muzlatamiz" (boshqaruvni o'chiramiz).
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_physics_process(false)        # harakat to'xtaydi
	set_process_unhandled_input(false)  # qarash/Esc to'xtaydi
	# "O'yin tugadi" ekrani shu signalni eshitadi va pauzani O'ZI qo'yadi.
	# DIQQAT: pauzani BU YERDA qo'ymaymiz — aks holda GameOver UI ham muzlab,
	# qayta boshlash tugmasi ishlamay qolishi mumkin.
	Events.player_died.emit()
	print("O'yinchi halok bo'ldi!")
