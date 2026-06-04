extends CanvasLayer
## Pauza menyusi — Esc bilan o'yinni to'xtatadi/davom ettiradi.
##
## process_mode = ALWAYS: pauza paytida ham ishlaydi (aks holda Esc bilan
## davom ettirib bo'lmaydi). O'yinchi halok bo'lganda (game over) ishlamaydi —
## o'sha holatni GameOver ekrani boshqaradi.

const SETTINGS_SCENE := preload("res://scenes/ui/settings_menu.tscn")

@onready var resume_button: Button = $Panel/CenterContainer/VBoxContainer/ResumeButton
@onready var restart_button: Button = $Panel/CenterContainer/VBoxContainer/RestartButton
@onready var settings_button: Button = $Panel/CenterContainer/VBoxContainer/SettingsButton
@onready var menu_button: Button = $Panel/CenterContainer/VBoxContainer/MenuButton
@onready var quit_button: Button = $Panel/CenterContainer/VBoxContainer/QuitButton

var _paused: bool = false
var _game_over: bool = false   ## O'yin tugagach Esc pauza menyusini ochmasin
var _settings_open: bool = false  ## Sozlanmalar overlay ochiqmi (Esc shunda pauzani almashtirmasin)


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.player_died.connect(_on_player_died)
	resume_button.pressed.connect(_resume)
	restart_button.pressed.connect(_on_restart)
	settings_button.pressed.connect(_on_settings)
	menu_button.pressed.connect(_on_main_menu)
	quit_button.pressed.connect(_on_quit)


func _on_player_died() -> void:
	_game_over = true


func _input(event: InputEvent) -> void:
	# Sozlanmalar overlay ochiq bo'lsa — Esc o'sha overlay'ni yopadi (bu yerda emas).
	if event.is_action_pressed("pause") and not _game_over and not _settings_open:
		if _paused:
			_resume()
		else:
			_pause()


## Pauza menyusidan sozlanmalarni ustiga (overlay) ochadi.
func _on_settings() -> void:
	var s := SETTINGS_SCENE.instantiate()
	add_child(s)
	_settings_open = true
	s.closed.connect(func() -> void:
		_settings_open = false
		resume_button.grab_focus())


func _pause() -> void:
	_paused = true
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Aim/zoom qotib qolmasligi uchun kamera FOV'ini tiklaymiz.
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		cam.fov = 75.0
	resume_button.grab_focus()


func _resume() -> void:
	_paused = false
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_restart() -> void:
	# Avval pauzani yechamiz (bayroq SceneTree'da saqlanadi), keyin qayta yuklaymiz.
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().reload_current_scene()


func _on_main_menu() -> void:
	# Pauzani yechib, bosh menyuga qaytamiz.
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_quit() -> void:
	get_tree().quit()
