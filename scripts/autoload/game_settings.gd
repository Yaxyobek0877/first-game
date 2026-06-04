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

## Sozlama o'zgarganda yuboriladi (UI o'zaro sinxron bo'lishi uchun, kelajak uchun).
signal changed()


func _ready() -> void:
	# Pauzada ham ishlasin (sozlanmalar menyusi pauzada ochiladi).
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_all()


## Barcha sozlamalarni AudioServer/Display ga qo'llaydi (o'yin boshlanganda).
func apply_all() -> void:
	_apply_bus("Master", master_volume)
	_apply_bus("Music", music_volume)
	_apply_bus("SFX", sfx_volume)
	_apply_window()


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
