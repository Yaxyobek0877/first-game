extends Node
## UI tovushlari (autoload "UiSound").
##
## SceneTree'ga qo'shilgan HAR QANDAY tugma (BaseButton — Button, CheckButton, ...)
## ning `pressed` signaliga avtomatik ulanadi va bosilganda "klik" tovushini chaladi.
## Shu sabab har bir menyuda alohida ulash shart emas — yangi tugma ham o'zi ovozli bo'ladi.
## "SFX" shinasiga (bus) ulanadi — sozlanmalardagi SFX balandligi ta'sir qiladi.

const CLICK := preload("res://assets/audio/ui_click.wav")

var _player: AudioStreamPlayer


func _ready() -> void:
	# Pauzada ham ishlasin (pauza/sozlanmalar menyularidagi tugmalar uchun).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = "SFX"
	_player.stream = CLICK
	add_child(_player)
	# Bundan keyin qo'shiladigan tugmalar:
	get_tree().node_added.connect(_on_node_added)
	# Allaqachon daraxtda turgan tugmalar (autoload kechroq ulansa):
	_connect_existing(get_tree().root)


func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.pressed.is_connected(play_click):
		n.pressed.connect(play_click)


func _connect_existing(n: Node) -> void:
	if n is BaseButton and not n.pressed.is_connected(play_click):
		n.pressed.connect(play_click)
	for c in n.get_children():
		_connect_existing(c)


func play_click() -> void:
	_player.play()
