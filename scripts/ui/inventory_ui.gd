extends CanvasLayer
## Inventar oynasi (Tab bilan ochiladi). Qurollar (Loadout), granatalar (GrenadeThrower),
## jon paketlari (Inventory) ko'rsatadi; jon paketini ishlatish (davolanish) mumkin.
## Ochilganda o'yin pauza bo'ladi va sichqoncha bo'shaydi. Player skriptiga TEGMAYDI.
## UI kod bilan quriladi (dinamik ro'yxatlar).

const HEAL := 50.0
const GNAMES := {"frag": "Frag", "smoke": "Tutun", "flash": "Flash"}

var _open: bool = false
var _weapons_box: VBoxContainer
var _grenades_box: VBoxContainer
var _health_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	visible = false
	_build()
	Inventory.changed.connect(func() -> void: if _open: _refresh())
	Events.grenade_changed.connect(func(_t: String, _c: int) -> void: if _open: _refresh())


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.82)
	dim.anchor_right = 1.0; dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.anchor_right = 1.0; center.anchor_bottom = 1.0
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for s in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 30)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.custom_minimum_size = Vector2(440, 0)
	margin.add_child(vb)
	var title := Label.new()
	title.text = "Inventar"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	vb.add_child(title)
	vb.add_child(_section("Qurollar"))
	_weapons_box = VBoxContainer.new(); vb.add_child(_weapons_box)
	vb.add_child(_section("Granatalar"))
	_grenades_box = VBoxContainer.new(); vb.add_child(_grenades_box)
	vb.add_child(_section("Jon paketlari"))
	var hrow := HBoxContainer.new()
	_health_label = Label.new()
	_health_label.add_theme_font_size_override("font_size", 20)
	_health_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(_health_label)
	var use_btn := Button.new()
	use_btn.text = "Ishlatish (davolanish)"
	use_btn.add_theme_font_size_override("font_size", 18)
	use_btn.pressed.connect(_on_use_health)
	hrow.add_child(use_btn)
	vb.add_child(hrow)
	var close_btn := Button.new()
	close_btn.text = "Yopish (Tab)"
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(_close)
	vb.add_child(close_btn)


func _section(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	return l


func _row(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 20)
	return l


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if _open:
			get_viewport().set_input_as_handled()
			_close()
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:   # faqat gameplay'dan ochiladi
			get_viewport().set_input_as_handled()
			_open_inv()
	elif _open and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()


func _open_inv() -> void:
	_open = true
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func _close() -> void:
	_open = false
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _refresh() -> void:
	for c in _weapons_box.get_children():
		c.queue_free()
	var weapons: Array = Loadout.get_weapons()
	if weapons.is_empty():
		_weapons_box.add_child(_row("—"))
	for w in weapons:
		_weapons_box.add_child(_row("•  " + str(w.display_name)))
	for c in _grenades_box.get_children():
		c.queue_free()
	var counts: Dictionary = {}
	# InventoryUI Main'ning bolasi — GrenadeThrower esa uning sherigi (sibling).
	var gt := get_parent().get_node_or_null("GrenadeThrower")
	if gt != null and gt.has_method("get_counts"):
		counts = gt.get_counts()
	for k in ["frag", "smoke", "flash"]:
		_grenades_box.add_child(_row("•  %s  ×%d" % [GNAMES.get(k, k), int(counts.get(k, 0))]))
	_health_label.text = "Jon paketlari: ×%d   (har biri +%d jon)" % [Inventory.health_packs, int(HEAL)]


func _on_use_health() -> void:
	Inventory.use_health_pack()
	_refresh()
