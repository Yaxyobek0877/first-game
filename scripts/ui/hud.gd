extends CanvasLayer
## Ekran ustidagi ma'lumot paneli (HUD = Heads-Up Display).
## O'zi hech kimni bilmaydi — faqat Events signallariga "obuna bo'ladi"
## va son o'zgarganda matnni yangilaydi. Bu — toza decoupling.

@onready var ammo_label: Label = $AmmoLabel
@onready var health_label: Label = $HealthLabel
@onready var score_label: Label = $ScoreLabel

var score: int = 0


func _ready() -> void:
	# Signallarga ulanamiz (obuna bo'lamiz).
	Events.ammo_changed.connect(_on_ammo_changed)
	Events.player_health_changed.connect(_on_health_changed)
	Events.enemy_died.connect(_on_enemy_died)
	_update_score()


func _on_ammo_changed(current: int, max_ammo: int) -> void:
	ammo_label.text = "O'q-dori: %d / %d" % [current, max_ammo]


func _on_health_changed(current: float, max_health: float) -> void:
	health_label.text = "Jon: %d / %d" % [int(current), int(max_health)]


func _on_enemy_died(_enemy: Node) -> void:
	score += 1
	_update_score()


func _update_score() -> void:
	score_label.text = "Ochko: %d" % score
