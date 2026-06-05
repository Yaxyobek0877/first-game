extends Node
## To'lqin (wave) boshqaruvchisi — rollarga ega Kron garnizoni.
##
## Har to'lqin "mudofaa garnizoni" sifatida boshlanadi: qo'riqchilar postlarni ushlaydi,
## patrullar yuradi, miltiqchilar otish chizig'ini, snayperlar baland postni egallaydi,
## hujumchilar/qanotchilar bosim oshiradi. To'lqin sayin tarkib og'irlashadi (lekin hech
## qachon zombi to'dasi emas). Tirik dushmanlar tugaganda keyingi to'lqin boshlanadi.

const Enemy = preload("res://scripts/enemies/enemy.gd")

@export var enemy_scene: PackedScene
@export var first_wave_delay: float = 1.5
@export var between_wave_delay: float = 3.0
@export var base_count: int = 2
## Shuncha vaqt (s) hech bir dushman o'lmasa (o'yinchi bekinib/uzoqda tursa) — qolgan
## dushmanlar "bosqin"ga o'tadi va o'yinchiga bostirib keladi (wave doim tugaydi).
@export var stall_limit: float = 10.0

var _wave: int = 0
var _spawning: bool = false
var _stall_timer: float = 0.0   ## Oxirgi o'limdan beri o'tgan vaqt (failsafe uchun)

## Hujumchi/qanotchi spawn nuqtalari (shimol + flanglar — o'yinchidan uzoq).
var _spawn_points: Array[Vector3] = [
	Vector3(-16, 0, -24), Vector3(0, 0, -25), Vector3(16, 0, -24),
	Vector3(-24, 0, -8), Vector3(24, 0, -8),
	Vector3(-8, 0, -22), Vector3(8, 0, -22),
	Vector3(-24, 0, 8), Vector3(24, 0, 8),
]

## Qo'riqchi/miltiqchi postlari (pana qutilar ustida — janubga, o'yinchi tomon qaraydi).
const GUARD_POSTS: Array[Vector3] = [
	Vector3(0, 0, -18),    # markaz-old, 3x3 quti — asosiy chiziq
	Vector3(8, 0, -10),    # sharq 2x2
	Vector3(-9, 0, -12),   # g'arb 2x2
	Vector3(0, 0, 0),      # markaz 2x2 — "obyekt"
]
## Minora tepasidagi snayper postlari (platforma sirti ~5.15 — ozgina yuqoridan tushadi).
const TOWER_POSTS: Array[Vector3] = [
	Vector3(19, 5.3, -2),
	Vector3(-19, 5.3, -2),
]
## Snayper (overwatch) postlari — baland/uzoq burchaklar (minoralar to'lsa, yerdagi zaxira).
const MARKSMAN_POSTS: Array[Vector3] = [
	Vector3(17, 0, -15),   # shimoli-sharq 3x3
	Vector3(-17, 0, -15),  # shimoli-g'arb 3x3
	Vector3(0, 0, -24),    # orqa-markaz
]
## Patrul yo'llari (nuqtalar bo'ylab aylanadi).
const PATROL_LOOPS: Array = [
	[Vector3(8, 0, -10), Vector3(0, 0, -18), Vector3(-9, 0, -12)],   # old chiziq
	[Vector3(13, 0, 4), Vector3(17, 0, -15)],                         # o'ng yo'lak
	[Vector3(-14, 0, 3), Vector3(-17, 0, -15)],                       # chap yo'lak
]


func _ready() -> void:
	if enemy_scene == null:
		enemy_scene = load("res://scenes/enemies/enemy.tscn")
	# Dushman o'lganda failsafe taymerini qayta boshlaymiz (jang davom etyapti).
	Events.enemy_died.connect(_on_enemy_died)
	# create_timer(..., false): pauzaga bo'ysunadi — game over paytida spawn bo'lmaydi.
	await get_tree().create_timer(first_wave_delay, false).timeout
	_start_wave()


func _process(delta: float) -> void:
	if _wave <= 0 or _spawning:
		return
	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		_spawning = true
		_next_wave_after_delay()
		return
	# Failsafe: uzoq vaqt hech kim o'lmasa (o'yinchi bekinib turibdi yoki dushmanlar yetolmaydi)
	# — qolgan barcha dushmanlar "bosqin"ga o'tadi (har biri o'yinchiga to'g'ridan-to'g'ri yuradi).
	_stall_timer += delta
	if _stall_timer >= stall_limit:
		_stall_timer = 0.0
		for e in enemies:
			if e.has_method("go_aggressive"):
				e.go_aggressive()
		print("[WM] Bosqin! Dushmanlar o'yinchiga bostirib kelmoqda.")


func _on_enemy_died(_e: Node) -> void:
	_stall_timer = 0.0   # jangda muvaffaqiyat bor — failsafe taymerini tiklaymiz


func _next_wave_after_delay() -> void:
	await get_tree().create_timer(between_wave_delay, false).timeout
	_start_wave()


func _start_wave() -> void:
	_wave += 1
	_stall_timer = 0.0   # har yangi wave failsafe taymerini yangidan boshlaydi
	var count: int = base_count + _wave
	var roles: Array = _composition(_wave, count)
	# Postlarni taqsimlash uchun nusxalar (pop bilan — ikkitasi bir postga tushmasin).
	var guard_posts: Array = GUARD_POSTS.duplicate()
	var tower_posts: Array = TOWER_POSTS.duplicate()
	var marksman_posts: Array = MARKSMAN_POSTS.duplicate()
	var patrol_n: int = 0
	var spawn_n: int = 0
	for i in count:
		var e: Node3D = enemy_scene.instantiate()
		var r: int = roles[i]
		e.role = r
		match r:
			Enemy.Role.SENTRY, Enemy.Role.RIFLEMAN:
				var post: Vector3 = guard_posts.pop_front() if not guard_posts.is_empty() else GUARD_POSTS[i % GUARD_POSTS.size()]
				e.position = post
				e.guard_position = post
			Enemy.Role.MARKSMAN:
				# Avval MINORA tepasini egallaydi (snayper o'sha yerda turadi); to'lsa — yerdagi post.
				var mp: Vector3
				if not tower_posts.is_empty():
					mp = tower_posts.pop_front()
					e.tower_sniper = true
				elif not marksman_posts.is_empty():
					mp = marksman_posts.pop_front()
				else:
					mp = MARKSMAN_POSTS[i % MARKSMAN_POSTS.size()]
				e.position = mp
				e.guard_position = mp
			Enemy.Role.PATROL:
				var loop: Array = PATROL_LOOPS[patrol_n % PATROL_LOOPS.size()]
				patrol_n += 1
				var pts: Array[Vector3] = []
				for p in loop:
					pts.append(p)
				e.patrol_points = pts
				e.position = loop[0]
				e.guard_position = loop[0]
			_:
				# ASSAULT / FLANKER — shimol/flangdan, ozgina tasodifiy siljish bilan.
				var sp: Vector3 = _spawn_points[(spawn_n + _wave * 2) % _spawn_points.size()]
				spawn_n += 1
				sp += Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
				e.position = sp
				if r == Enemy.Role.FLANKER:
					e.flank_side = 1 if (i % 2 == 0) else -1
		get_tree().current_scene.add_child(e)
	_spawning = false
	Events.wave_started.emit(_wave)
	print("To'lqin ", _wave, " boshlandi: ", count, " dushman")


## To'lqin tarkibi (rollar ro'yxati). Har doim mudofaa "tayanchi" bor, bosim oshib boradi.
func _composition(wave: int, count: int) -> Array:
	var roles: Array = []
	if wave == 1:
		# Har wave'da o'yinchiga keladigan rusher BOR (bo'sh maydon hissi bo'lmasin):
		# 2 hujumchi bostirib keladi + 1 qo'riqchi postni ushlaydi (rol hissi).
		roles = [Enemy.Role.ASSAULT, Enemy.Role.ASSAULT, Enemy.Role.SENTRY]
	elif wave == 2:
		roles = [Enemy.Role.ASSAULT, Enemy.Role.FLANKER, Enemy.Role.SENTRY, Enemy.Role.RIFLEMAN]
	elif wave == 3:
		roles = [Enemy.Role.ASSAULT, Enemy.Role.ASSAULT, Enemy.Role.FLANKER, Enemy.Role.RIFLEMAN, Enemy.Role.MARKSMAN]
	else:
		# Byudjet-asosli: avval "ziravor" rollar (kam, lekin xilma-xillik beradi) —
		# bular count'ga ALBATTA sig'adi (yig'indisi count'dan oshmaydi). Qolgan
		# o'rinni mudofaa tayanchi (sentry/patrul/miltiqchi) bilan to'ldiramiz.
		var marksmen: int = clampi(wave / 3, 1, 3)
		var flankers: int = clampi((wave - 3) / 2, 1, 2)
		var assault: int = clampi(wave / 3, 1, 3)   # rusher bosimi (har doim biroz bor)
		for i in marksmen:
			roles.append(Enemy.Role.MARKSMAN)
		for i in flankers:
			roles.append(Enemy.Role.FLANKER)
		for i in assault:
			roles.append(Enemy.Role.ASSAULT)
		# Qolganini mudofaa tayanchi bilan to'ldiramiz (takror naqsh).
		var backbone: Array = [Enemy.Role.SENTRY, Enemy.Role.SENTRY, Enemy.Role.PATROL, Enemy.Role.RIFLEMAN]
		var bi: int = 0
		while roles.size() < count:
			roles.append(backbone[bi % backbone.size()])
			bi += 1
	# Kam bo'lsa to'ldiramiz, ko'p bo'lsa kesamiz (aniq count).
	while roles.size() < count:
		roles.append(Enemy.Role.ASSAULT)
	return roles.slice(0, count)
