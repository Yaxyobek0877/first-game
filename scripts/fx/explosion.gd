extends Node3D
## Portlash effekti + radius bo'yicha zarar (granata frag uchun).
##
## VFX (tween bilan — AnimationPlayer kerak emas, ishonchli):
##   - kengayuvchi emissiv olov shar (o'sib, so'nadi)
##   - yorqin yorug'lik chaqnashi (OmniLight, tez so'nadi)
##   - bir nechta tutun bulutchasi (ko'tariladi, kengayadi, so'nadi)
##   - yer bo'ylab kengayuvchi zarba halqasi
## Zarar: markaz atrofidagi `radius` ichidagi `take_damage`'li tanalar (player + enemy);
##   masofaga qarab kamayadi (falloff) + devor orqasida bo'lsa LOS bilan kamaytiriladi.
## O'zini avtomatik o'chiradi — hech qanday osilib qolgan tugun qoldirmaydi.
##
## Ishlatish: instance qil → `position` (yoki global_position) o'rnat → current_scene'ga
## add_child qil. _ready o'zi VFX+zarar+ovozni boshlaydi.

@export var max_damage: float = 80.0
@export var radius: float = 5.0
@export var do_damage: bool = true        ## smoke/flash uchun false qilsa bo'ladi
@export var sfx_path: String = "res://assets/audio/explosion.wav"

const LIFETIME := 1.6                      ## eng uzun effektdan keyin o'chish (s)


func _ready() -> void:
	_spawn_vfx()
	if do_damage:
		_apply_damage()
	_play_sfx()
	Events.explosion.emit(global_position, radius)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)


# --- VFX -------------------------------------------------------------------

func _spawn_vfx() -> void:
	# 1) Olov shar — emissiv, kengayadi, so'nadi
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.4; sm.height = 0.8
	ball.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.75, 0.32, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.2)
	mat.emission_energy_multiplier = 4.0
	ball.material_override = mat
	add_child(ball)
	ball.scale = Vector3.ONE * 0.3
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ball, "scale", Vector3.ONE * (radius * 0.6), 0.28) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.45).set_delay(0.12)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.45).set_delay(0.12)

	# 2) Yorug'lik chaqnashi
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = 8.0
	light.omni_range = radius * 2.5
	add_child(light)
	create_tween().tween_property(light, "light_energy", 0.0, 0.35) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# 3) Tutun bulutchalari
	for _i in 6:
		var puff := MeshInstance3D.new()
		var ps := SphereMesh.new(); ps.radius = 0.5; ps.height = 1.0
		puff.mesh = ps
		var pmat := StandardMaterial3D.new()
		pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var g := randf_range(0.16, 0.30)
		pmat.albedo_color = Color(g, g * 0.95, g * 0.9, 0.5)
		puff.material_override = pmat
		add_child(puff)
		var ang := randf() * TAU
		var off := Vector3(cos(ang), 0.0, sin(ang)) * randf_range(0.3, radius * 0.5)
		puff.position = off + Vector3(0.0, randf_range(0.2, 0.6), 0.0)
		puff.scale = Vector3.ONE * randf_range(0.4, 0.8)
		var pt := create_tween().set_parallel(true)
		pt.tween_property(puff, "position",
			puff.position + Vector3(off.x * 0.4, randf_range(1.5, 2.6), off.z * 0.4), 1.3)
		pt.tween_property(puff, "scale", Vector3.ONE * randf_range(1.4, 2.3), 1.3)
		pt.tween_property(pmat, "albedo_color:a", 0.0, 1.3).set_delay(0.25)

	# 4) Zarba halqasi (yer bo'ylab)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 0.05; tm.outer_radius = 0.25
	ring.mesh = tm
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_color = Color(1.0, 0.85, 0.5, 0.55)
	ring.material_override = rmat
	add_child(ring)
	ring.position.y = 0.12
	var rt := create_tween().set_parallel(true)
	rt.tween_property(ring, "scale", Vector3(radius * 3.0, 1.0, radius * 3.0), 0.42).set_ease(Tween.EASE_OUT)
	rt.tween_property(rmat, "albedo_color:a", 0.0, 0.42)

	# 5) Uchqun zarrachalari (yorqin, tez — bir martalik portlash)
	var embers := GPUParticles3D.new()
	embers.amount = 28
	embers.lifetime = 0.9
	embers.one_shot = true
	embers.explosiveness = 1.0
	embers.local_coords = false
	var epm := ParticleProcessMaterial.new()
	epm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	epm.emission_sphere_radius = 0.3
	epm.direction = Vector3(0, 1, 0)
	epm.spread = 90.0
	epm.initial_velocity_min = 4.0
	epm.initial_velocity_max = 10.0
	epm.gravity = Vector3(0, -14.0, 0)
	epm.scale_min = 0.04
	epm.scale_max = 0.10
	epm.color = Color(1.0, 0.7, 0.3)
	embers.process_material = epm
	var emesh := SphereMesh.new(); emesh.radius = 0.05; emesh.height = 0.1
	var emat := StandardMaterial3D.new()
	emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	emat.emission_enabled = true
	emat.emission = Color(1.0, 0.6, 0.2)
	emat.albedo_color = Color(1.0, 0.7, 0.3)
	emesh.material = emat
	embers.draw_pass_1 = emesh
	add_child(embers)
	embers.emitting = true

	# 6) Parchalar (qoramtir, og'irroq — uchib chiqib, tushadi)
	var debris := GPUParticles3D.new()
	debris.amount = 9
	debris.lifetime = 1.3
	debris.one_shot = true
	debris.explosiveness = 1.0
	debris.local_coords = false
	var dpm := ParticleProcessMaterial.new()
	dpm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	dpm.emission_sphere_radius = 0.2
	dpm.direction = Vector3(0, 1, 0)
	dpm.spread = 70.0
	dpm.initial_velocity_min = 3.0
	dpm.initial_velocity_max = 8.0
	dpm.gravity = Vector3(0, -16.0, 0)
	dpm.angular_velocity_min = -400.0
	dpm.angular_velocity_max = 400.0
	dpm.scale_min = 0.06
	dpm.scale_max = 0.16
	dpm.color = Color(0.15, 0.13, 0.11)
	debris.process_material = dpm
	var dmesh := BoxMesh.new(); dmesh.size = Vector3(0.12, 0.12, 0.12)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.16, 0.14, 0.12)
	dmesh.material = dmat
	debris.draw_pass_1 = dmesh
	add_child(debris)
	debris.emitting = true

	# 7) Kuygan iz (yerda qoramtir disk — qisqa qoladi)
	var scorch := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 0.7
	cyl.bottom_radius = radius * 0.7
	cyl.height = 0.02
	scorch.mesh = cyl
	var scm := StandardMaterial3D.new()
	scm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	scm.albedo_color = Color(0.05, 0.04, 0.03, 0.55)
	scorch.material_override = scm
	add_child(scorch)
	scorch.position.y = 0.02
	create_tween().tween_property(scm, "albedo_color:a", 0.18, 0.5)


# --- Zarar -----------------------------------------------------------------

func _apply_damage() -> void:
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), global_position)
	q.collision_mask = 6          # player (layer2=val2) + enemy (layer3=val4) = 6
	q.collide_with_areas = false
	q.collide_with_bodies = true
	var hits := space.intersect_shape(q, 24)
	var seen := {}
	for h in hits:
		var col: Object = h.get("collider")
		if col == null or not col.has_method("take_damage"):
			continue
		var id: int = col.get_instance_id()
		if seen.has(id):
			continue
		seen[id] = true
		var tpos: Vector3 = (col as Node3D).global_position
		var dist: float = global_position.distance_to(tpos)
		var factor: float = clampf(1.0 - dist / radius, 0.0, 1.0)
		factor = factor * factor          # silliq falloff (yaqin = ko'p)
		# Devor orqasida bo'lsa zararni kamaytiramiz (LOS — faqat world=1 to'siqlar).
		# MUHIM: ikkala uchni ham yerdan ko'taramiz, aks holda yer (pol) sathidagi
		# portlashda nur darrov polga urilib, har doim "to'silgan" deb hisoblanardi.
		var los_from: Vector3 = global_position + Vector3(0, 0.6, 0)
		var los_to: Vector3 = tpos + Vector3(0, 0.9, 0)
		var rq := PhysicsRayQueryParameters3D.create(los_from, los_to, 1)
		rq.collide_with_areas = false
		if not space.intersect_ray(rq).is_empty():
			factor *= 0.35
		var dmg: float = max_damage * factor
		if dmg >= 1.0:
			col.take_damage(dmg)


# --- Ovoz ------------------------------------------------------------------

func _play_sfx() -> void:
	if sfx_path == "":
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = load(sfx_path)
	p.bus = "SFX"
	p.unit_size = 16.0
	p.max_distance = 90.0
	add_child(p)
	p.play()
