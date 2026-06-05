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
@onready var fps_check: CheckButton = %FpsCheck
@onready var controls_list: VBoxContainer = %ControlsList
@onready var reset_controls: Button = %ResetControls
@onready var back_button: Button = %BackButton

## Action -> ko'rsatiladigan nom (Boshqaruv ro'yxatida).
const ACTION_NAMES := {
	"move_forward": "Oldinga", "move_back": "Orqaga", "move_left": "Chapga", "move_right": "O'ngga",
	"jump": "Sakrash", "sprint": "Yugurish", "crouch": "Cho'kkalash", "prone": "Yotish",
	"lean_left": "Chapga engashish", "lean_right": "O'ngga engashish",
	"shoot": "Otish", "aim": "Mo'ljal (aim)", "reload": "Qayta o'qlash",
	"weapon_1": "Qurol 1", "weapon_2": "Qurol 2",
	"grenade": "Granata", "grenade_cycle": "Granata turi",
	"interact": "Olish (pickup)", "inventory": "Inventar",
}

var _listening_action: String = ""   ## Hozir qaysi action uchun tugma kutilmoqda
var _listening_button: Button = null
var _rebind_rows: Dictionary = {}     ## action -> Button (matnni yangilash uchun)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Boshlang'ich qiymatlarni GameSettings'dan olamiz (set_value_no_signal —
	# slayderni dasturiy to'ldirganda value_changed ishlamasin, qayta saqlamasin).
	master_slider.set_value_no_signal(GameSettings.master_volume)
	music_slider.set_value_no_signal(GameSettings.music_volume)
	sfx_slider.set_value_no_signal(GameSettings.sfx_volume)
	sens_slider.set_value_no_signal(GameSettings.mouse_sensitivity)
	fullscreen_check.set_pressed_no_signal(GameSettings.fullscreen)
	fps_check.set_pressed_no_signal(GameSettings.show_fps)
	_refresh_labels()

	# Signallarga ulanamiz.
	master_slider.value_changed.connect(_on_master)
	music_slider.value_changed.connect(_on_music)
	sfx_slider.value_changed.connect(_on_sfx)
	sens_slider.value_changed.connect(_on_sens)
	fullscreen_check.toggled.connect(_on_fullscreen)
	fps_check.toggled.connect(_on_fps)
	reset_controls.pressed.connect(_on_reset_controls)
	back_button.pressed.connect(_on_back)
	back_button.grab_focus()
	_build_controls()


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


func _on_fps(on: bool) -> void:
	GameSettings.set_show_fps(on)


func _on_back() -> void:
	closed.emit()
	queue_free()


## "Boshqaruv" ro'yxatini quradi — har action uchun [nom | tugma] qatori.
func _build_controls() -> void:
	for c in controls_list.get_children():
		c.queue_free()
	_rebind_rows.clear()
	for a in GameSettings.REBINDABLE:
		if not InputMap.has_action(a):
			continue
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_lbl := Label.new()
		name_lbl.text = ACTION_NAMES.get(a, a)
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 0)
		btn.add_theme_font_size_override("font_size", 18)
		btn.text = GameSettings.binding_text(a)
		btn.pressed.connect(_begin_rebind.bind(a, btn))
		row.add_child(btn)
		controls_list.add_child(row)
		_rebind_rows[a] = btn


## Tugmani bosganda — keyingi bosilgan tugma/sichqonchani shu action'ga bog'laymiz.
func _begin_rebind(action: String, btn: Button) -> void:
	if _listening_action != "":
		return
	_listening_action = action
	_listening_button = btn
	btn.text = "[ tugma bosing ]"
	btn.release_focus()


## Rebind kutilayotganda bosilgan tugmani ushlaymiz (Esc — bekor qiladi).
func _input(event: InputEvent) -> void:
	if _listening_action == "":
		return
	var captured := false
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_listening_button.text = GameSettings.binding_text(_listening_action)
			_clear_listening()
			get_viewport().set_input_as_handled()
			return
		captured = true
	elif event is InputEventMouseButton and event.pressed:
		captured = true
	if not captured:
		return
	GameSettings.set_binding(_listening_action, event)
	_listening_button.text = GameSettings.binding_text(_listening_action)
	_clear_listening()
	get_viewport().set_input_as_handled()


func _clear_listening() -> void:
	_listening_action = ""
	_listening_button = null


func _on_reset_controls() -> void:
	GameSettings.reset_bindings()
	for a in _rebind_rows:
		_rebind_rows[a].text = GameSettings.binding_text(a)


## Esc bilan ham yopilsin (qulay). Boshqa Esc ishlovchilarga o'tmasin.
func _unhandled_input(event: InputEvent) -> void:
	# Rebind kutilayotganda Esc'ni _input bekor qiladi — bu yerga yetmaydi.
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()
