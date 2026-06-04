extends Node3D
## Tutun buluti (smoke granata) — ~11s ko'rinishni to'sadi, so'ng so'nadi. Zarar bermaydi.
## GPUParticles3D: yumshoq "puff" teksturali billboardlar, sekin ko'tariladi va kengayadi.

const EMIT_TIME := 6.0      ## qancha vaqt yangi zarracha chiqarsin
const LIFETIME := 11.0      ## umumiy yashash vaqti (so'ng o'chadi)
const PUFF := "res://assets/textures/smoke_puff.png"


func _ready() -> void:
	var p := GPUParticles3D.new()
	p.amount = 60
	p.lifetime = 5.5
	p.one_shot = false
	p.local_coords = false
	p.randomness = 0.5
	p.fixed_fps = 30

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.3
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 35.0
	pm.gravity = Vector3(0, 0.25, 0)            # sekin ko'tariladi
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.9
	pm.scale_min = 2.2
	pm.scale_max = 4.6
	pm.color = Color(0.55, 0.55, 0.58, 0.5)
	p.process_material = pm

	var qm := QuadMesh.new()
	qm.size = Vector2(2.0, 2.0)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.albedo_color = Color(0.52, 0.52, 0.55, 0.5)
	if ResourceLoader.exists(PUFF):
		mat.albedo_texture = load(PUFF)
	qm.material = mat
	p.draw_pass_1 = qm
	add_child(p)
	p.emitting = true

	get_tree().create_timer(EMIT_TIME).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.emitting = false)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)
