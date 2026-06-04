extends Node
## Jang/holat ovozlari (autoload "Sfx").
##
## `Events` signallariga "obuna bo'ladi" va mos SFX ni chaladi — jang skriptlariga
## (enemy.gd, weapon.gd, player.gd) TEGMAYDI. Loyihaning decoupling uslubiga mos.
##
## Otish va qadam tovushlari boshqa joyda (weapon.gd / player.gd). Bu yerda ULAR YO'Q
## hodisalar: dushman o'limi, zarar, hit-marker, qurol almashtirish, o'lim, to'lqin.
## "SFX" shinasiga ulanadi.
##
## DIQQAT: stream'lar `preload` (parse-vaqt) emas, `load` (runtime, _ready) bilan
## olinadi — aks holda yangi WAV hali import qilinmagan paytda autoload parse xatosi
## berib, import jarayonini buzadi (tovuq-tuxum). load() import tugagach ishlaydi.

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _prev_health: float = -1.0
var _weapon_inited: bool = false   ## Boshlang'ich equip'da "klak" chalmaslik uchun


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_streams = {
		"death": load("res://assets/audio/enemy_death.wav"),
		"hurt": load("res://assets/audio/player_hurt.wav"),
		"hit": load("res://assets/audio/hitmarker.wav"),
		"switch": load("res://assets/audio/weapon_switch.wav"),
		"pdeath": load("res://assets/audio/player_death.wav"),
		"wave": load("res://assets/audio/wave_start.wav"),
	}
	for _i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	Events.enemy_died.connect(_on_enemy_died)
	Events.player_health_changed.connect(_on_health)
	Events.target_hit.connect(_on_hit)
	Events.weapon_changed.connect(_on_weapon)
	Events.player_died.connect(_on_died)
	Events.wave_started.connect(_on_wave)


## Bo'sh pleyerga stream qo'yib chaladi (pool — bir vaqtda bir nechta ovoz uchun).
func _play(key: String, lo: float = 1.0, hi: float = 1.0) -> void:
	var s: AudioStream = _streams.get(key)
	if s == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = s
	p.pitch_scale = randf_range(lo, hi)
	p.play()


func _on_enemy_died(_enemy: Node) -> void:
	_play("death", 0.92, 1.08)   # ozgina pitch farqi — bir xil eshitilmasin


func _on_health(current: float, _max_health: float) -> void:
	if _prev_health >= 0.0 and current < _prev_health - 0.01:
		_play("hurt", 0.95, 1.05)
	_prev_health = current


func _on_hit() -> void:
	_play("hit", 0.97, 1.06)


func _on_weapon(_weapon_name: String) -> void:
	# Birinchi (boshlang'ich) equip'da chalmaymiz — faqat haqiqiy almashtirishda.
	if not _weapon_inited:
		_weapon_inited = true
		return
	_play("switch")


func _on_died() -> void:
	_play("pdeath")


func _on_wave(_wave: int) -> void:
	_play("wave")
