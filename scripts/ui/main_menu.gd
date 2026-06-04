extends Control
## Bosh menyu — o'yin ochilganda birinchi ko'rinadigan ekran.
## "Boshlash" o'yin sahnasiga o'tadi, "Chiqish" dasturni yopadi.

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton


func _ready() -> void:
	# Menyuda sichqoncha erkin bo'lsin (o'yinda player uni qamaydi).
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Pauzadan qaytib kelgan bo'lsak — har ehtimolga qarshi pauzani yechamiz.
	get_tree().paused = false
	start_button.pressed.connect(_on_start)
	quit_button.pressed.connect(_on_quit)
	start_button.grab_focus()


func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_quit() -> void:
	get_tree().quit()
