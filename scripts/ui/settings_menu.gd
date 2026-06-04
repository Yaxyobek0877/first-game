extends Control
## Sozlanmalar menyusi — ovoz, sezgirlik, to'liq ekran.
##
## Ham bosh menyudan, ham pauza menyusidan ochiladi: overlay (ustiga) sifatida
## instance qilinadi. Yopilganda `closed` signalini yuboradi va o'zini o'chiradi.
##
## process_mode = ALWAYS: pauza paytida ham ishlaydi (pauza menyusi ustida).
## Qiymatlar GameSettings autoload orqali o'qiladi/yoziladi (darhol qo'llanadi + saqlanadi).

signal closed

@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var sens_slider: HSlider = %SensSlider
@onready var master_value: Label = %MasterValue
@onready var music_value: Label = %MusicValue
@onready var sfx_value: Label = %SfxValue
@onready var sens_value: Label = %SensValue
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var back_button: Button = %BackButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Boshlang'ich qiymatlarni GameSettings'dan olamiz (set_value_no_signal —
	# slayderni dasturiy to'ldirganda value_changed ishlamasin, qayta saqlamasin).
	master_slider.set_value_no_signal(GameSettings.master_volume)
	music_slider.set_value_no_signal(GameSettings.music_volume)
	sfx_slider.set_value_no_signal(GameSettings.sfx_volume)
	sens_slider.set_value_no_signal(GameSettings.mouse_sensitivity)
	fullscreen_check.set_pressed_no_signal(GameSettings.fullscreen)
	_refresh_labels()

	# Signallarga ulanamiz.
	master_slider.value_changed.connect(_on_master)
	music_slider.value_changed.connect(_on_music)
	sfx_slider.value_changed.connect(_on_sfx)
	sens_slider.value_changed.connect(_on_sens)
	fullscreen_check.toggled.connect(_on_fullscreen)
	back_button.pressed.connect(_on_back)
	back_button.grab_focus()


func _refresh_labels() -> void:
	master_value.text = "%d%%" % roundi(GameSettings.master_volume * 100.0)
	music_value.text = "%d%%" % roundi(GameSettings.music_volume * 100.0)
	sfx_value.text = "%d%%" % roundi(GameSettings.sfx_volume * 100.0)
	# Sezgirlik 0.0025 = "1.0x" (standart). Foydalanuvchiga tushunarli ko'paytmada.
	sens_value.text = "%.2fx" % (GameSettings.mouse_sensitivity / 0.0025)


func _on_master(v: float) -> void:
	GameSettings.set_master_volume(v)
	_refresh_labels()


func _on_music(v: float) -> void:
	GameSettings.set_music_volume(v)
	_refresh_labels()


func _on_sfx(v: float) -> void:
	GameSettings.set_sfx_volume(v)
	_refresh_labels()


func _on_sens(v: float) -> void:
	GameSettings.set_mouse_sensitivity(v)
	_refresh_labels()


func _on_fullscreen(on: bool) -> void:
	GameSettings.set_fullscreen(on)


func _on_back() -> void:
	closed.emit()
	queue_free()


## Esc bilan ham yopilsin (qulay). Boshqa Esc ishlovchilarga o'tmasin.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()
