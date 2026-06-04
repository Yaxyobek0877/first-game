extends CanvasLayer
## "O'yin tugadi" ekrani.
##
## Vazifasi: o'yinchi halok bo'lganda (Events.player_died) ekranni ko'rsatish,
## o'yinni pauza qilish va "Qayta boshlash" tugmasi orqali sahnani qayta yuklash.
##
## MUHIM nuance — process_mode:
## Butun o'yinni get_tree().paused = true bilan muzlatamiz. Lekin pauza paytida
## oddiy tugunlar (PROCESS_MODE_PAUSABLE) ishlamaydi — tugma ham bosilmaydi.
## Shuning uchun bu ekranni PROCESS_MODE_ALWAYS qilamiz: pauzadan qat'i nazar ishlaydi.

@onready var restart_button: Button = $Panel/CenterContainer/VBoxContainer/RestartButton
@onready var menu_button: Button = $Panel/CenterContainer/VBoxContainer/MenuButton


func _ready() -> void:
	# Boshida yashirin turadi — faqat o'lim signalida ko'rinadi.
	visible = false
	# Pauzada ham jonli qolishi shart (aks holda restart tugmasi ishlamaydi).
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.player_died.connect(_on_player_died)
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_main_menu)


func _on_player_died() -> void:
	visible = true
	# Butun SceneTree'ni muzlatamiz — dushmanlar va o'q-otish to'xtaydi.
	get_tree().paused = true
	# Sichqonchani bo'shatamiz — tugmani bosa olish uchun.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Aim/zoom qotib qolmasligi uchun kamera FOV'ini tiklaymiz.
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		cam.fov = 75.0
	# Klaviatura/gamepad bilan ham bosish mumkin bo'lsin.
	restart_button.grab_focus()


func _on_restart_pressed() -> void:
	# DIQQAT — tartib muhim: pauza bayrog'i SceneTree'da saqlanadi va sahna
	# qayta yuklangach ham qolib ketadi. Shuning uchun AVVAL pauzani yechamiz,
	# keyin sichqonchani qamab, so'ng sahnani qayta yuklaymiz.
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().reload_current_scene()


func _on_main_menu() -> void:
	# Pauzani yechib, bosh menyuga qaytamiz.
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
