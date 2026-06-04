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
var health: float
var _is_dead: bool = false       ## O'lim oqimi faqat bir marta ishlashi uchun (qayta o'lmaslik)

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
	# HUD boshlang'ich jonni ko'rsatishi uchun signal yuboramiz.
	Events.player_health_changed.emit(health, max_health)


func _unhandled_input(event: InputEvent) -> void:
	# Sichqoncha harakati — faqat qamalgan holatda atrofga qaraymiz.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Chap/o'ng — butun tanani Y o'qi atrofida aylantiramiz.
		rotate_y(-event.relative.x * mouse_sensitivity)
		# Yuqori/past — faqat boshni (kamerani) X o'qi atrofida.
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		# Boshni 90 darajadan ortiq egmaslik uchun cheklaymiz (orqaga ag'darilmaslik).
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))

	# Esc — sichqonchani bo'shatish/qaytarish (pauza menyusi uchun asos).
	if event.is_action_pressed("pause"):
		_toggle_mouse_capture()


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


## Dushmanlar shu funksiyani chaqirib o'yinchiga zarar yetkazadi.
func take_damage(amount: float) -> void:
	if _is_dead:
		return
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


func _toggle_mouse_capture() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
