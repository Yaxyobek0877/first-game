extends Node
## Global o'yin sozlamalari (autoload "GameSettings").
##
## Ovoz balandligi (Master/Music/SFX), sichqoncha sezgirligi va to'liq ekran —
## hammasi shu yerda turadi va `user://settings.cfg` ga saqlanadi (o'yin yopilib
## qayta ochilganda esda qoladi). Sozlanmalar menyusi shu qiymatlarni o'zgartiradi.
##
## Decoupling: ovoz AudioServer shinalariga (bus) yoziladi; sahnalar bir-birini
## bilmaydi. Sezgirlikni player.gd to'g'ridan-to'g'ri shu yerdan o'qiydi (live).

const PATH := "user://settings.cfg"

## Ovoz balandliklari 0.0..1.0 (chiziqli). db ga aylantirilib bus'ga yoziladi.
var master_volume: float = 0.9
var music_volume: float = 0.6
var sfx_volume: float = 0.9
## Sichqoncha sezgirligi (player.gd `_unhandled_input` da ishlatiladi).
var mouse_sensitivity: float = 0.0025
var fullscreen: bool = false
## Ekrandagi FPS ko'rsatkichi ko'rinsinmi (HUD shuni o'qiydi).
var show_fps: bool = false

## Rebind qilsa bo'ladigan action'lar (Settings "Boshqaruv" bo'limida ko'rinadi).
const REBINDABLE := [
	"move_forward", "move_back", "move_left", "move_right",
	"jump", "sprint", "crouch", "prone", "lean_left", "lean_right",
	"shoot", "aim", "reload", "weapon_1", "weapon_2",
	"grenade", "grenade_cycle", "interact", "inventory",
]
## action -> loyiha standart hodisalari (reset uchun, _ready'da olinadi).
var _default_events: Dictionary = {}

## Sozlama o'zgarganda yuboriladi (UI o'zaro sinxron bo'lishi uchun, kelajak uchun).
signal changed()


func _ready() -> void:
	# Pauzada ham ishlasin (sozlanmalar menyusi pauzada ochiladi).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_defaults()   # standart tugmalarni saqlaymiz (reset uchun) — yuklashdan OLDIN
	load_settings()
	apply_all()


# --- Boshqaruv (tugma bog'lanishlari / rebind) ---

## Loyiha standart tugma hodisalarini saqlaymiz (reset shulardan tiklaydi).
func _capture_defaults() -> void:
	for a in InputMap.get_actions():
		_default_events[a] = InputMap.action_get_events(a).duplicate()


## Action'ga yangi tugma bog'laydi (eski(lar)ni o'chirib). Toza hodisa yasaydi.
func set_binding(action: String, event: InputEvent) -> void:
	var clean := _clean_event(event)
	if clean == null or not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, clean)
	_save_deferred()


## Barcha tugmalarni standartga qaytaradi.
func reset_bindings() -> void:
	for a in _default_events:
		if not InputMap.has_action(a):
			continue
		InputMap.action_erase_events(a)
		for e in _default_events[a]:
			InputMap.action_add_event(a, e)
	_save_deferred()


## Action'ning joriy (birinchi) tugmasi matni — UI uchun.
func binding_text(action: String) -> String:
	if not InputMap.has_action(action):
		return "—"
	var evs := InputMap.action_get_events(action)
	return event_text(evs[0]) if not evs.is_empty() else "—"


func event_text(e: InputEvent) -> String:
	if e is InputEventKey:
		var kc: int = (e as InputEventKey).physical_keycode
		if kc == 0:
			kc = (e as InputEventKey).keycode
		return OS.get_keycode_string(kc)
	if e is InputEventMouseButton:
		match (e as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "Sichqoncha chap"
			MOUSE_BUTTON_RIGHT: return "Sichqoncha o'ng"
			MOUSE_BUTTON_MIDDLE: return "Sichqoncha o'rta"
			MOUSE_BUTTON_WHEEL_UP: return "G'ildirak yuqori"
			MOUSE_BUTTON_WHEEL_DOWN: return "G'ildirak past"
			_: return "Sichqoncha %d" % (e as InputEventMouseButton).button_index
	return "?"


## Xom hodisadan toza InputEvent (faqat tugma/sichqoncha; pozitsiya va h.k. tashlanadi).
func _clean_event(e: InputEvent) -> InputEvent:
	if e is InputEventKey:
		var k := InputEventKey.new()
		var src := e as InputEventKey
		k.physical_keycode = src.physical_keycode if src.physical_keycode != 0 else src.keycode
		return k
	if e is InputEventMouseButton:
		var m := InputEventMouseButton.new()
		m.button_index = (e as InputEventMouseButton).button_index
		return m
	return null


func _serialize_event(e: InputEvent) -> Dictionary:
	if e is InputEventKey:
		var src := e as InputEventKey
		return {"t": "k", "c": (src.physical_keycode if src.physical_keycode != 0 else src.keycode)}
	if e is InputEventMouseButton:
		return {"t": "m", "b": (e as InputEventMouseButton).button_index}
	return {}


func _deserialize_event(d: Dictionary) -> InputEvent:
	match d.get("t", ""):
		"k":
			var k := InputEventKey.new(); k.physical_keycode = int(d.get("c", 0)); return k
		"m":
			var m := InputEventMouseButton.new(); m.button_index = int(d.get("b", 1)); return m
	return null


## Saqlangan bog'lanishlarni InputMap'ga qo'llaydi (yuklashda).
func _apply_binds(binds: Dictionary) -> void:
	for a in binds:
		if not InputMap.has_action(a):
			continue
		var e := _deserialize_event(binds[a])
		if e != null:
			InputMap.action_erase_events(a)
			InputMap.action_add_event(a, e)


## Barcha sozlamalarni AudioServer/Display ga qo'llaydi (o'yin boshlanganda).
func apply_all() -> void:
	_apply_bus("Master", master_volume)
	_apply_bus("Music", music_volume)
	_apply_bus("SFX", sfx_volume)
	_apply_window()
	_apply_fps()


## FPS chegarasi: cheksiz (0) — qurilma imkoniyatiga qarab chiqaradi (60 ga qotirilmaydi).
## Vsync project.godot da o'chirilgan (window/vsync/vsync_mode=0).
func _apply_fps() -> void:
	Engine.max_fps = 0


## Chiziqli 0..1 ovozni shinaning (bus) db qiymatiga yozadi. 0 da mute.
func _apply_bus(bus_name: String, v: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var muted: bool = v <= 0.001
	AudioServer.set_bus_mute(idx, muted)
	if not muted:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(v, 0.001, 1.0)))


func _apply_window() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


# --- O'rnatuvchilar (UI shulardan foydalanadi: darhol qo'llaydi + saqlaydi) ---

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_bus("Master", master_volume)
	_save_deferred()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_bus("Music", music_volume)
	_save_deferred()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_bus("SFX", sfx_volume)
	_save_deferred()


func set_mouse_sensitivity(v: float) -> void:
	mouse_sensitivity = clampf(v, 0.0002, 0.02)
	_save_deferred()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_window()
	_save_deferred()


func set_show_fps(on: bool) -> void:
	show_fps = on
	_save_deferred()   # changed signal HUD'ni jonli yangilaydi


# --- Saqlash / yuklash (ConfigFile — oddiy INI uslubidagi format) ---

var _save_queued: bool = false

## Tez-tez chaqirilsa (slayder sudralganda) diskka bir marta yozadi (kadr oxirida).
func _save_deferred() -> void:
	changed.emit()
	if _save_queued:
		return
	_save_queued = true
	save_settings.call_deferred()


func save_settings() -> void:
	_save_queued = false
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "show_fps", show_fps)
	# Tugma bog'lanishlari (rebind) — har action'ning birinchi hodisasini saqlaymiz.
	var binds := {}
	for a in REBINDABLE:
		if InputMap.has_action(a):
			var evs := InputMap.action_get_events(a)
			if not evs.is_empty():
				binds[a] = _serialize_event(evs[0])
	cfg.set_value("input", "binds", binds)
	cfg.save(PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return   # fayl yo'q — standart qiymatlar qoladi
	master_volume = cfg.get_value("audio", "master", master_volume)
	music_volume = cfg.get_value("audio", "music", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	mouse_sensitivity = cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity)
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	show_fps = cfg.get_value("video", "show_fps", show_fps)
	_apply_binds(cfg.get_value("input", "binds", {}))
