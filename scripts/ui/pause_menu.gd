extends CanvasLayer
## Pauza menyusi — Esc bilan o'yinni to'xtatadi/davom ettiradi.
##
## process_mode = ALWAYS: pauza paytida ham ishlaydi (aks holda Esc bilan
## davom ettirib bo'lmaydi). O'yinchi halok bo'lganda (game over) ishlamaydi —
## o'sha holatni GameOver ekrani boshqaradi.

@onready var resume_button: Button = $Panel/CenterContainer/VBoxContainer/ResumeButton
@onready var restart_button: Button = $Panel/CenterContainer/VBoxContainer/RestartButton
@onready var quit_button: Button = $Panel/CenterContainer/VBoxContainer/QuitButton

var _paused: bool = false
var _game_over: bool = false   ## O'yin tugagach Esc pauza menyusini ochmasin


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.player_died.connect(_on_player_died)
	resume_button.pressed.connect(_resume)
	restart_button.pressed.connect(_on_restart)
	quit_button.pressed.connect(_on_quit)


func _on_player_died() -> void:
	_game_over = true


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not _game_over:
		if _paused:
			_resume()
		else:
			_pause()


func _pause() -> void:
	_paused = true
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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


func _on_quit() -> void:
	get_tree().quit()
