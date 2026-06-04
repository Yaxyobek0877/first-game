extends Control
## Avatar / jihoz ekrani — o'yinchi qurollarini (slot 1/2) tanlaydi va avatarda ko'radi.
##
## Chap tomonda 3D avatar (Aros askari) aylanib turadi va tanlangan (fokusdagi) slot
## quroli uning oldida ko'rinadi. O'ng tomonda ikki slot uchun tanlov + statistika.
## "Jangga kirish" tanlangan jihoz bilan o'yinni boshlaydi (Loadout autoload saqlaydi).

@onready var pivot: Node3D = %AvatarPivot
@onready var holder: Node3D = %WeaponHolder
@onready var slot1_option: OptionButton = %Slot1Option
@onready var slot2_option: OptionButton = %Slot2Option
@onready var stats_label: Label = %StatsLabel
@onready var start_button: Button = %StartButton
@onready var back_button: Button = %BackButton

var _weapon_instance: Node3D = null
var _focus: int = 0   ## Avatarda ko'rsatilayotgan slot (oxirgi o'zgartirilgan)


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	MusicPlayer.play_menu()

	_populate(slot1_option)
	_populate(slot2_option)
	_select_current()

	slot1_option.item_selected.connect(func(idx: int) -> void: _on_slot_changed(0, idx))
	slot2_option.item_selected.connect(func(idx: int) -> void: _on_slot_changed(1, idx))
	start_button.pressed.connect(_on_start)
	back_button.pressed.connect(_on_back)

	_refresh()
	start_button.grab_focus()


func _process(delta: float) -> void:
	# Avatar sekin aylanadi (turntable ko'rgazma).
	if pivot != null:
		pivot.rotate_y(delta * 0.6)


## OptionButton'ni barcha mavjud qurollar bilan to'ldiradi (ko'rinadigan nom bilan).
func _populate(opt: OptionButton) -> void:
	opt.clear()
	for p in Loadout.ALL:
		opt.add_item(Loadout.weapon_display_name(p))


## Joriy tanlangan slotlarni OptionButton'larda belgilaydi.
func _select_current() -> void:
	var i0: int = Loadout.ALL.find(Loadout.slots[0])
	var i1: int = Loadout.ALL.find(Loadout.slots[1])
	if i0 >= 0:
		slot1_option.select(i0)
	if i1 >= 0:
		slot2_option.select(i1)


func _on_slot_changed(slot: int, idx: int) -> void:
	if idx < 0 or idx >= Loadout.ALL.size():
		return
	Loadout.set_slot(slot, Loadout.ALL[idx])
	_focus = slot   # o'zgartirilgan slotni avatarda ko'rsatamiz
	_refresh()


func _refresh() -> void:
	_show_weapon(Loadout.slots[_focus])
	_update_stats()


## Avatardagi qurol modelini almashtiradi (fokusdagi slot quroli).
func _show_weapon(path: String) -> void:
	if _weapon_instance != null:
		_weapon_instance.queue_free()
		_weapon_instance = null
	var w: Resource = load(path)
	if w == null or w.view_model == "":
		return
	var scene: PackedScene = load(w.view_model)
	if scene == null:
		return
	_weapon_instance = scene.instantiate()
	holder.add_child(_weapon_instance)
	# Avatarda yaxshi ko'rinishi uchun: kattaroq + yon tomoni ko'ringan holatda.
	_weapon_instance.scale = Vector3.ONE * 2.2
	_weapon_instance.rotation_degrees = Vector3(0, 90, 0)


## Ikkala slot quroli statistikasini ko'rsatadi.
func _update_stats() -> void:
	stats_label.text = "%s\n\n%s" % [_stat_line(0), _stat_line(1)]


func _stat_line(slot: int) -> String:
	var w: Resource = load(Loadout.slots[slot])
	if w == null:
		return ""
	var fire: String = "Avtomat" if w.auto_fire else "Yakka"
	var scope: String = " · Durbin" if w.is_scope else ""
	var marker: String = "▶ " if slot == _focus else "   "
	return "%s%d-slot: %s\n      Zarar %d · O'q %d · %s%s" % [
		marker, slot + 1, w.display_name, int(w.damage), w.max_ammo, fire, scope]


func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
