extends Node3D
## Arena: o'yin boshlanganda navigatsiya to'rini (navmesh) bir marta "pishiramiz".
##
## NEGA CSG'dan emas? Pol va to'siqlar CSGBox3D — ulardan to'g'ridan-to'g'ri navmesh
## pishirish Godot'da ishonchsiz (CSG collision'ini parser yaxshi o'qiy olmaydi).
##
## Yechim: navigatsiya uchun maxsus yordamchi STATIC collision shape'lar
## ("nav_source" guruhidagi StaticBody3D + BoxShape3D) qo'yamiz va faqat o'shalardan
## pishiramiz. Ular 8-qatlamda (boshqa hech narsa to'qnashmaydi) — ko'rinmaydi va
## o'yinga xalaqit bermaydi. Collision shape'dan pishirish — Godot tavsiya qiladigan,
## GPU "stall" bermaydigan runtime usuli.

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	# on_thread = false: kichik geometriya, sinxron (darhol tayyor) — headless uchun ishonchli.
	nav_region.bake_navigation_mesh(false)
	# Tekshiruv: navmesh haqiqatan hosil bo'ldimi? 0 bo'lsa — dushman yura olmaydi.
	var poly_count: int = nav_region.navigation_mesh.get_polygon_count()
	print("Arena navmesh tayyor: ", poly_count, " ko'pburchak")
