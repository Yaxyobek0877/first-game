extends Control
## Bosh menyu — o'yin ochilganda birinchi ko'rinadigan ekran.
## "Boshlash" o'yin sahnasiga o'tadi, "Avatar / Jihoz" loadout ekrani,
## "Sozlamalar" overlay sozlanmalar menyusi, "Chiqish" dasturni yopadi.

const SETTINGS_SCENE := preload("res://scenes/ui/settings_menu.tscn")

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var loadout_button: Button = $CenterContainer/VBoxContainer/LoadoutButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton


func _ready() -> void:
	# Menyuda sichqoncha erkin bo'lsin (o'yinda player uni qamaydi).
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Pauzadan qaytib kelgan bo'lsak — har ehtimolga qarshi pauzani yechamiz.
	get_tree().paused = false
	start_button.pressed.connect(_on_start)
	loadout_button.pressed.connect(_on_loadout)
	settings_button.pressed.connect(_on_settings)
	quit_button.pressed.connect(_on_quit)
	start_button.grab_focus()
	# Menyu musiqasi (autoload — sahna almashsa ham uzilmaydi).
	MusicPlayer.play_menu()


func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_loadout() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/loadout.tscn")


func _on_settings() -> void:
	# Sozlanmalarni ustiga (overlay) ochamiz; yopilganda fokusni qaytaramiz.
	var s := SETTINGS_SCENE.instantiate()
	add_child(s)
	s.closed.connect(func() -> void: settings_button.grab_focus())


func _on_quit() -> void:
	get_tree().quit()
