extends CanvasLayer
## Ekran ustidagi ma'lumot paneli (HUD = Heads-Up Display).
## O'zi hech kimni bilmaydi — faqat Events signallariga "obuna bo'ladi"
## va son o'zgarganda matnni yangilaydi. Bu — toza decoupling.

@onready var ammo_label: Label = $AmmoLabel
@onready var health_label: Label = $HealthLabel
@onready var score_label: Label = $ScoreLabel
@onready var weapon_label: Label = $WeaponLabel
@onready var wave_label: Label = $WaveLabel
@onready var record_label: Label = $RecordLabel

const RECORD_PATH := "user://record.save"
var score: int = 0
var record: int = 0


func _ready() -> void:
	# Signallarga ulanamiz (obuna bo'lamiz).
	Events.ammo_changed.connect(_on_ammo_changed)
	Events.player_health_changed.connect(_on_health_changed)
	Events.enemy_died.connect(_on_enemy_died)
	Events.weapon_changed.connect(_on_weapon_changed)
	Events.wave_started.connect(_on_wave_started)
	_load_record()
	_update_score()
	_update_record()


func _on_ammo_changed(current: int, max_ammo: int) -> void:
	ammo_label.text = "O'q-dori: %d / %d" % [current, max_ammo]


func _on_health_changed(current: float, max_health: float) -> void:
	health_label.text = "Jon: %d / %d" % [int(current), int(max_health)]


func _on_enemy_died(_enemy: Node) -> void:
	score += 1
	if score > record:
		record = score
		_save_record()
		_update_record()
	_update_score()


func _on_weapon_changed(weapon_name: String) -> void:
	weapon_label.text = "Qurol: %s" % weapon_name


func _on_wave_started(wave: int) -> void:
	wave_label.text = "To'lqin: %d" % wave


func _update_score() -> void:
	score_label.text = "Ochko: %d" % score


func _update_record() -> void:
	record_label.text = "Rekord: %d" % record


func _load_record() -> void:
	if FileAccess.file_exists(RECORD_PATH):
		var f := FileAccess.open(RECORD_PATH, FileAccess.READ)
		if f != null:
			record = f.get_32()
			f.close()


func _save_record() -> void:
	var f := FileAccess.open(RECORD_PATH, FileAccess.WRITE)
	if f != null:
		f.store_32(record)
		f.close()
