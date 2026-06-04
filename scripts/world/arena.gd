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


## Kuzatuv minorasi: 4 oyoq + platforma + panjara + tom, ostida nav-to'siq.
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

	# Platforma (tepada).
	var plat_y: float = leg_h
	_mesh_box(t, Vector3(3.2, 0.3, 3.2), Vector3(0, plat_y, 0), _wood)
	_add_collision(body, Vector3(3.2, 0.3, 3.2), Vector3(0, plat_y, 0))

	# Panjara (4 tomon).
	var r_y: float = plat_y + 0.5
	_mesh_box(t, Vector3(3.2, 0.6, 0.12), Vector3(0, r_y, 1.55), _wood)
	_mesh_box(t, Vector3(3.2, 0.6, 0.12), Vector3(0, r_y, -1.55), _wood)
	_mesh_box(t, Vector3(0.12, 0.6, 3.2), Vector3(1.55, r_y, 0), _wood)
	_mesh_box(t, Vector3(0.12, 0.6, 3.2), Vector3(-1.55, r_y, 0), _wood)

	# Tom ustunlari + tom.
	var post_y: float = plat_y + 0.95
	for sx2 in [-1.0, 1.0]:
		for sz2 in [-1.0, 1.0]:
			_mesh_box(t, Vector3(0.12, 1.1, 0.12), Vector3(sx2 * 1.4, post_y, sz2 * 1.4), _dark)
	_mesh_box(t, Vector3(3.7, 0.18, 3.7), Vector3(0, post_y + 0.62, 0), _dark)

	# Nav-to'siq: butun tagligini qoplaydi — dushmanlar minorani aylanib o'tadi.
	_nav_obstacle(Vector3(3.2, 6.0, 3.2), base + Vector3(0, 3.0, 0))


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
