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
@onready var crosshair: TextureRect = $Crosshair
@onready var hitmarker: TextureRect = $Hitmarker
@onready var weapon_icon: TextureRect = $WeaponIcon
@onready var damage_overlay: ColorRect = $DamageOverlay
@onready var fps_label: Label = $FpsLabel
@onready var grenade_label: Label = $GrenadeLabel

## Qurol ikonkalari (qurol almashganda almashtiriladi).
const TEX_AVTOMAT := preload("res://assets/ui/hud/icon_avtomat.png")
const TEX_SNIPER := preload("res://assets/ui/hud/icon_sniper.png")
const TEX_TOPPONCHA := preload("res://assets/ui/hud/icon_topponcha.png")

const RECORD_PATH := "user://record.save"
var score: int = 0
var record: int = 0
var _prev_health: float = -1.0   ## Zarar (jon kamayishi) ni aniqlash uchun
var _fps_accum: float = 1.0      ## FPS yorlig'ini sekinroq yangilash uchun (boshida darrov chiqsin)


func _ready() -> void:
	# Signallarga ulanamiz (obuna bo'lamiz).
	Events.ammo_changed.connect(_on_ammo_changed)
	Events.player_health_changed.connect(_on_health_changed)
	Events.enemy_died.connect(_on_enemy_died)
	Events.weapon_changed.connect(_on_weapon_changed)
	Events.wave_started.connect(_on_wave_started)
	Events.target_hit.connect(_on_target_hit)
	Events.scoped.connect(_on_scoped)
	Events.grenade_changed.connect(_on_grenade_changed)
	# FPS ko'rsatkichi: Sozlamalardan ko'rinishi olinadi, o'zgarsa jonli yangilanadi.
	fps_label.visible = GameSettings.show_fps
	GameSettings.changed.connect(_on_settings_changed)
	_load_record()
	_update_score()
	_update_record()


## FPS yorlig'i ko'rinsa — sekundiga ~4 marta yangilanadi (har kadr emas — barqaror raqam).
func _process(delta: float) -> void:
	if not fps_label.visible:
		return
	_fps_accum += delta
	if _fps_accum >= 0.25:
		_fps_accum = 0.0
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


## Sozlama o'zgarganda (masalan pauza menyusida FPS yoqilsa) — ko'rinishni yangilaymiz.
func _on_settings_changed() -> void:
	fps_label.visible = GameSettings.show_fps


func _on_ammo_changed(current: int, max_ammo: int) -> void:
	ammo_label.text = "O'q-dori: %d / %d" % [current, max_ammo]


func _on_health_changed(current: float, max_health: float) -> void:
	health_label.text = "Jon: %d / %d" % [int(current), int(max_health)]
	# Jon KAMAYSA (zarar) — ekran chetlari qizil "chaqnaydi".
	if _prev_health >= 0.0 and current < _prev_health - 0.01:
		_flash_damage()
	_prev_health = current


## Zarar olganda qizil overlay chaqnashi.
func _flash_damage() -> void:
	damage_overlay.color = Color(0.7, 0.0, 0.0, 0.45)
	var tw := create_tween()
	tw.tween_property(damage_overlay, "color:a", 0.0, 0.4)


## O'q nishonga tekkanda crosshair qisqa "hit-marker" (qizarib, kattalashadi).
func _on_target_hit() -> void:
	# Alohida hit-marker belgisi qisqa chaqnaydi (oq → shaffof).
	hitmarker.modulate = Color(1, 1, 1, 1)
	var hm := create_tween()
	hm.tween_property(hitmarker, "modulate:a", 0.0, 0.25)
	# Crosshair ham qizarib kattalashadi.
	crosshair.modulate = Color(1.0, 0.4, 0.3)
	crosshair.scale = Vector2(1.5, 1.5)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(crosshair, "modulate", Color.WHITE, 0.18)
	tw.tween_property(crosshair, "scale", Vector2.ONE, 0.18)


func _on_enemy_died(_enemy: Node) -> void:
	score += 1
	if score > record:
		record = score
		_save_record()
		_update_record()
	_update_score()


func _on_weapon_changed(weapon_name: String) -> void:
	weapon_label.text = "Qurol: %s" % weapon_name
	# Qurol turiga mos ikonka (nomi bo'yicha: snayper / topponcha / avtomat).
	var ln := weapon_name.to_lower()
	if ln.contains("nayper"):
		weapon_icon.texture = TEX_SNIPER
	elif ln.contains("opponcha"):
		weapon_icon.texture = TEX_TOPPONCHA
	else:
		weapon_icon.texture = TEX_AVTOMAT


func _on_wave_started(wave: int) -> void:
	wave_label.text = "To'lqin: %d" % wave


## Granata turi/soni o'zgarganda (GrenadeThrower yuboradi).
func _on_grenade_changed(grenade_type: String, count: int) -> void:
	var names := {"frag": "Frag", "smoke": "Tutun", "flash": "Flash"}
	grenade_label.text = "Granata: %s ×%d" % [names.get(grenade_type, grenade_type), count]


## Snayper durbiniga qaraganda (scoped) — oddiy crosshair yashiriladi
## (durbin overlay o'zining nishon chiziqlarini ko'rsatadi).
func _on_scoped(active: bool) -> void:
	crosshair.visible = not active


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
