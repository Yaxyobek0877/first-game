extends Node3D
## Arena: o'yin boshlanganda qo'shimcha bezak/to'siqlarni (minoralar, bochkalar,
## voronkalar, qum-qop devorlar) protsedural quradi va navigatsiya to'rini (navmesh)
## bir marta "pishiradi".
##
## NEGA CSG'dan emas? Pol va to'siqlar CSGBox3D — ulardan to'g'ridan-to'g'ri navmesh
## pishirish Godot'da ishonchsiz (CSG collision'ini parser yaxshi o'qiy olmaydi).
##
## Yechim: navigatsiya uchun maxsus yordamchi STATIC collision shape'lar
## ("nav_source" guruhidagi StaticBody3D + BoxShape3D) qo'yamiz va faqat o'shalardan
## pishiramiz. Ular 8-qatlamda (boshqa hech narsa to'qnashmaydi). Yangi minoralar uchun
## ham xuddi shunday nav-to'siq qo'shamiz (BAKE'dan OLDIN) — dushmanlar ularni aylanib o'tadi.

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var nav_sources: Node3D = $NavigationRegion3D/NavSources

# Materiallar (kod ichida bir marta yaratiladi — bezaklar uchun).
var _wood: StandardMaterial3D
var _metal: StandardMaterial3D
var _dark: StandardMaterial3D
var _dirt: StandardMaterial3D


func _ready() -> void:
	_make_materials()
	_build_details()   # minoralar + bezaklar (BAKE'dan oldin — nav to'g'ri "kesilsin")
	# on_thread = false: kichik geometriya, sinxron (darhol tayyor) — headless uchun ishonchli.
	nav_region.bake_navigation_mesh(false)
	# Tekshiruv: navmesh haqiqatan hosil bo'ldimi? 0 bo'lsa — dushman yura olmaydi.
	var poly_count: int = nav_region.navigation_mesh.get_polygon_count()
	print("Arena navmesh tayyor: ", poly_count, " ko'pburchak")


func _make_materials() -> void:
	_wood = _mat(Color(0.34, 0.21, 0.11), 0.9, 0.0)
	_metal = _mat(Color(0.30, 0.32, 0.34), 0.5, 0.4)
	_dark = _mat(Color(0.12, 0.12, 0.13), 0.7, 0.2)
	_dirt = _mat(Color(0.18, 0.13, 0.08), 1.0, 0.0)


func _mat(color: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


## Barcha qo'shimcha bezak/to'siqlarni joylashtiradi.
func _build_details() -> void:
	# Ikki kuzatuv minorasi (flanglarda) — landmark va balandlik hissi.
	_build_tower(Vector3(-19, 0, -2))
	_build_tower(Vector3(19, 0, -2))

	# Bochkalar (collision + nav-to'siq bilan).
	for p in [Vector3(-16, 0, 2), Vector3(-21, 0, -5), Vector3(16, 0, 2),
			Vector3(21, 0, -5), Vector3(3, 0, -3), Vector3(-4, 0, -5)]:
		_barrel(p)

	# Voronkalar (snaryad izlari) — faqat ko'rinish (yassi disk).
	for p in [Vector3(-7, 0, -8), Vector3(7, 0, -9), Vector3(0, 0, -15),
			Vector3(-11, 0, 7), Vector3(11, 0, 8), Vector3(0, 0, 10)]:
		_crater(p)

	# Qum-qop past devorlar (o'yinchiga oldinda pana) — collision + nav-to'siq.
	_low_wall(Vector3(-6, 0, 13), Vector3(4.5, 1.1, 1.2))
	_low_wall(Vector3(6, 0, 13), Vector3(4.5, 1.1, 1.2))


## Kuzatuv minorasi: 4 oyoq + platforma + panjara + (baland) tom + NARVON.
## O'yinchi janub yuzidagi narvondan chiqib-tusha oladi (player.gd climb mexanikasi).
func _build_tower(base: Vector3) -> void:
	var t := Node3D.new()
	t.name = "Tower"
	t.position = base
	add_child(t)

	# Bitta StaticBody — barcha qattiq qismlar (oyoq/platforma) to'qnashuvi shu yerda.
	var body := StaticBody3D.new()
	body.collision_layer = 1   # "world"
	body.collision_mask = 0
	t.add_child(body)

	var leg_h: float = 5.0
	# 4 oyoq (burchaklarda).
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var lp := Vector3(sx * 1.2, leg_h * 0.5, sz * 1.2)
			_mesh_box(t, Vector3(0.3, leg_h, 0.3), lp, _wood)
			_add_collision(body, Vector3(0.3, leg_h, 0.3), lp)

	# Platforma (tepada). Sirt: plat_y + 0.15 = 5.15.
	var plat_y: float = leg_h
	var plat_top: float = plat_y + 0.15
	_mesh_box(t, Vector3(3.2, 0.3, 3.2), Vector3(0, plat_y, 0), _wood)
	_add_collision(body, Vector3(3.2, 0.3, 3.2), Vector3(0, plat_y, 0))

	# Panjara (bel balandligi 0.9) — ko'rinish + COLLISION (o'yinchi chetdan tushmasin).
	# 3 tomon to'liq; janub (narvon) tomoni o'rtada ochiq (faqat narvondan o'tiladi).
	var r_h: float = 0.9
	var r_y: float = plat_top + r_h * 0.5
	for rail in [
		[Vector3(3.2, r_h, 0.12), Vector3(0, r_y, -1.55)],     # shimol
		[Vector3(0.12, r_h, 3.2), Vector3(1.55, r_y, 0)],      # sharq
		[Vector3(0.12, r_h, 3.2), Vector3(-1.55, r_y, 0)],     # g'arb
		[Vector3(1.0, r_h, 0.12), Vector3(-1.1, r_y, 1.55)],   # janub (chap segment)
		[Vector3(1.0, r_h, 0.12), Vector3(1.1, r_y, 1.55)],    # janub (o'ng segment)
	]:
		_mesh_box(t, rail[0], rail[1], _wood)
		_add_collision(body, rail[0], rail[1])

	# Tom — BALAND (o'yinchi tik tursin: platforma ustida ~2.5 m bo'shliq).
	var post_h: float = 2.55
	var post_cy: float = plat_top + post_h * 0.5
	for sx2 in [-1.0, 1.0]:
		for sz2 in [-1.0, 1.0]:
			_mesh_box(t, Vector3(0.12, post_h, 0.12), Vector3(sx2 * 1.4, post_cy, sz2 * 1.4), _dark)
	_mesh_box(t, Vector3(3.7, 0.18, 3.7), Vector3(0, plat_top + post_h + 0.1, 0), _dark)

	# --- NARVON (janub yuzida) ---
	_build_ladder(t, plat_top)

	# Nav-to'siq: tagligi + narvon (dushmanlar minora va narvonni aylanib o'tadi).
	_nav_obstacle(Vector3(3.4, 6.0, 4.8), base + Vector3(0, 3.0, 0.6))


## Narvon: 2 yon ustun + ko'ndalang pog'onalar (ko'rinish, collision'siz) +
## climb Area3D (o'yinchini sezadi, metama'lumot bilan).
func _build_ladder(t: Node3D, plat_top: float) -> void:
	var lz: float = 2.3                 # narvon z (local) — platforma chetidan tashqarida (snag bo'lmasin)
	var top: float = plat_top + 0.15    # narvon balandligi (~5.3)
	# 2 vertikal yon ustun
	for sx in [-0.32, 0.32]:
		_mesh_box(t, Vector3(0.07, top, 0.07), Vector3(sx, top * 0.5, lz), _wood)
	# ko'ndalang pog'onalar
	var y: float = 0.35
	while y <= top - 0.2:
		_mesh_box(t, Vector3(0.78, 0.06, 0.06), Vector3(0, y, lz), _wood)
		y += 0.4

	# Climb zonasi (Area3D) — platforma chetidan narvon oldigacha keng (yuqori/quyi kirish).
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2             # faqat player (layer 2)
	area.monitoring = true
	area.monitorable = false
	area.add_to_group("ladder")
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.3, plat_top + 0.8, 2.2)
	cs.shape = sh
	cs.position = Vector3(0, (plat_top + 0.8) * 0.5, 1.8)
	area.add_child(cs)
	t.add_child(area)

	# Metama'lumotlar (player o'qiydi) — DUNYO koordinatasida.
	var base := t.position
	area.set_meta("center", Vector3(base.x, 0.0, base.z + lz))   # narvon o'qi (x,z)
	area.set_meta("exit_dir", Vector3(0, 0, -1))                 # platformaga (tower -z)
	area.set_meta("top_y", base.y + plat_top)                    # platforma sirti (oyoq darajasi)
	area.body_entered.connect(_on_ladder_body.bind(area, true))
	area.body_exited.connect(_on_ladder_body.bind(area, false))


## Narvon zonasiga o'yinchi kirsa/chiqsa — player.gd ga xabar beramiz (duck typing).
func _on_ladder_body(body: Node, area: Area3D, entered: bool) -> void:
	if entered:
		if body.has_method("enter_ladder"):
			body.enter_ladder(area)
	elif body.has_method("exit_ladder"):
		body.exit_ladder(area)


## Bochka — ko'rinadigan silindr + collision + kichik nav-to'siq.
func _barrel(pos: Vector3) -> void:
	var b := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.4
	cm.bottom_radius = 0.4
	cm.height = 1.1
	b.mesh = cm
	b.material_override = _metal
	b.position = pos + Vector3(0, 0.55, 0)
	add_child(b)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.4
	sh.height = 1.1
	cs.shape = sh
	cs.position = pos + Vector3(0, 0.55, 0)
	body.add_child(cs)

	_nav_obstacle(Vector3(1.0, 2.0, 1.0), pos + Vector3(0, 1.0, 0))


## Voronka (snaryad izi) — faqat ko'rinish (yassi qoramtir disk), navga ta'sir qilmaydi.
func _crater(pos: Vector3) -> void:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.5
	cm.bottom_radius = 1.7
	cm.height = 0.12
	m.mesh = cm
	m.material_override = _dirt
	m.position = pos + Vector3(0, 0.03, 0)
	add_child(m)


## Past qum-qop devor — ko'rinish + collision + nav-to'siq (pana sifatida).
func _low_wall(pos: Vector3, size: Vector3) -> void:
	_mesh_box(self, size, pos + Vector3(0, size.y * 0.5, 0), _dirt)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	_add_collision(body, size, pos + Vector3(0, size.y * 0.5, 0))
	_nav_obstacle(size + Vector3(0.4, 2.0, 0.4), pos + Vector3(0, 1.0, 0))


# --- Past darajali yordamchilar ---

## Ko'rinadigan quti (MeshInstance3D) qo'shadi (lokal koordinatada parent ichida).
func _mesh_box(parent: Node3D, size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


## Mavjud StaticBody3D ga quti-to'qnashuv (CollisionShape3D + BoxShape3D) qo'shadi.
func _add_collision(body: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	body.add_child(cs)


## Navmesh "kesuvchi" to'siq qo'shadi: nav_source guruhi, 8-qatlam, NavSources ostida.
## DIQQAT: bake'dan OLDIN chaqirilishi shart (nav o'sha paytda o'qiladi).
func _nav_obstacle(size: Vector3, pos: Vector3) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = 8
	b.collision_mask = 0
	b.add_to_group("nav_source")
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	nav_sources.add_child(b)
	b.position = pos
