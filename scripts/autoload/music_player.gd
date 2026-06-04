extends Node
## Fon musiqasi (autoload "MusicPlayer").
##
## Menyu va jang treklarini chaladi va ular orasida silliq o'tadi (crossfade).
## "Music" shinasiga (bus) ulanadi — sozlanmalardagi musiqa balandligi shu yerga ta'sir qiladi.
## Sahnalar almashganda ham musiqa uzilmaydi (autoload — sahnadan tashqarida yashaydi).
##
## Ishlatish:
##   MusicPlayer.play_menu()    — bosh menyu / sozlanmalar / avatar ekranlarida
##   MusicPlayer.play_combat()  — gameplay (player.gd _ready da chaqiriladi)

const MENU := "res://assets/audio/menu_music.wav"
const COMBAT := "res://assets/audio/combat_music.wav"
const FADE := 1.0   ## Crossfade davomiyligi (s)

var _a: AudioStreamPlayer       ## Hozir chalinayotgan
var _b: AudioStreamPlayer       ## Crossfade uchun ikkinchi pleyer
var _current: String = ""       ## Joriy trek yo'li (qayta chalmaslik uchun)
var _tween: Tween


func _ready() -> void:
	# Pauzada ham musiqa o'chmasin.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = _make_player()
	_b = _make_player()


func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	return p


func play_menu() -> void:
	_play(MENU)


func play_combat() -> void:
	_play(COMBAT)


## Berilgan trekka silliq o'tadi. Allaqachon o'sha trek chalinayotgan bo'lsa — hech narsa.
func _play(path: String) -> void:
	if _current == path and _a.playing:
		return
	_current = path
	var stream := _load_looped(path)
	if stream == null:
		return

	# _a (eski) ni _b ga ko'chiramiz, _a ga yangi trekni qo'yamiz, keyin crossfade.
	var old := _b
	_b = _a
	_a = old
	_a.stream = stream
	_a.volume_db = -80.0
	_a.play()

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_a, "volume_db", 0.0, FADE)
	_tween.tween_property(_b, "volume_db", -80.0, FADE)
	# Eski trekni fade tugagach to'xtatamiz (resurs bo'shasin).
	_tween.chain().tween_callback(_b.stop)


## WAV ni yuklab, loop (takror) rejimini yoqadi. WAV import'ida loop yo'q —
## shuning uchun bu yerda runtime'da yoqamiz (butun namuna bo'ylab).
func _load_looped(path: String) -> AudioStream:
	var s := load(path)
	if s is AudioStreamWAV:
		var w: AudioStreamWAV = s
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		# 16-bit mono: 1 namuna = 2 bayt. loop_end = oxirgi namuna.
		var bytes_per_frame: int = 2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1
		var frames: int = w.data.size() / maxi(1, bytes_per_frame)
		if frames > 1:
			w.loop_end = frames - 1
	return s


## Musiqani silliq so'ndirib to'xtatadi (gameplay boshlanganda — o'yin paytida musiqa yo'q).
func fade_out() -> void:
	_current = ""
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_a, "volume_db", -80.0, FADE)
	_tween.tween_property(_b, "volume_db", -80.0, FADE)
	_tween.set_parallel(false)
	_tween.tween_callback(_a.stop)
	_tween.tween_callback(_b.stop)


## Musiqani to'xtatadi (kerak bo'lsa).
func stop() -> void:
	_current = ""
	_a.stop()
	_b.stop()
