extends RigidBody3D
## Tashlanadigan granata snaryadi. Yer/devorlardan sakraydi; fuse tugagach turiga
## mos effektni hosil qiladi: frag → portlash (zarar), smoke → tutun, flash → flashbang.
##
## Collision: layer=0 (hech kim "ko'rmaydi" — o'q nuri/player unga tegmaydi),
## mask=1 (faqat world bilan to'qnashadi — pol/devordan sakraydi). Shu sabab granata
## o'yinchiga yoki dushmanga yopishib qolmaydi va otish nuriga xalaqit bermaydi.

@export var grenade_type: String = "frag"   ## "frag" | "smoke" | "flash"
@export var fuse_time: float = 1.6

const EXPLOSION := preload("res://scenes/fx/explosion.tscn")

var _done: bool = false
var _bounce_cd: float = 0.0
var _age: float = 0.0
var _mesh_mat: StandardMaterial3D = null


func _ready() -> void:
	gravity_scale = 1.4
	mass = 0.4
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.45
	pm.friction = 0.6
	physics_material_override = pm
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_contact)
	# Turiga qarab rang (frag — qoramtir yashil; smoke — kulrang; flash — och po'lat).
	var mesh := get_node_or_null("Mesh") as MeshInstance3D
	if mesh != null:
		var mat := StandardMaterial3D.new()
		match grenade_type:
			"smoke": mat.albedo_color = Color(0.42, 0.42, 0.45)
			"flash": mat.albedo_color = Color(0.72, 0.72, 0.6)
			_: mat.albedo_color = Color(0.17, 0.22, 0.16)
		mat.metallic = 0.4
		mat.roughness = 0.6
		mesh.material_override = mat
		_mesh_mat = mat
	get_tree().create_timer(fuse_time).timeout.connect(_detonate)


func _process(delta: float) -> void:
	if _bounce_cd > 0.0:
		_bounce_cd -= delta
	_age += delta
	# Fyus tugashiga yaqin — qizil "ogohlantirish" miltillashi (tezlashib boradi).
	if _mesh_mat != null:
		var remain: float = fuse_time - _age
		if remain <= 1.0:
			var rate: float = lerpf(6.0, 26.0, clampf(1.0 - remain, 0.0, 1.0))
			_mesh_mat.emission_enabled = true
			_mesh_mat.emission = Color(1.0, 0.25, 0.12)
			_mesh_mat.emission_energy_multiplier = (0.5 + 0.5 * sin(_age * rate)) * 4.0


func _on_contact(_body: Node) -> void:
	# Yerga/devorga tegganda "tink" (juda tez takrorlanmasin, sekin tekkanda jim).
	if _bounce_cd <= 0.0 and linear_velocity.length() > 1.5:
		_bounce_cd = 0.15
		var p := AudioStreamPlayer3D.new()
		p.stream = load("res://assets/audio/grenade_bounce.wav")
		p.bus = "SFX"
		p.max_distance = 40.0
		add_child(p)
		p.play()
		p.finished.connect(p.queue_free)


func _detonate() -> void:
	if _done:
		return
	_done = true
	var pos := global_position
	var parent := get_tree().current_scene
	if parent == null:
		queue_free()
		return
	match grenade_type:
		"smoke":
			_spawn("res://scenes/fx/smoke.tscn", pos, parent)
		"flash":
			_spawn("res://scenes/fx/flashbang.tscn", pos, parent)
		_:
			var ex := EXPLOSION.instantiate()
			parent.add_child(ex)
			ex.global_position = pos
	queue_free()


## Berilgan effekt sahnasini hosil qiladi; hali mavjud bo'lmasa (2-bosqich) — zaxira
## sifatida portlash (test buzilmasligi uchun).
func _spawn(path: String, pos: Vector3, parent: Node) -> void:
	if ResourceLoader.exists(path):
		var s := (load(path) as PackedScene).instantiate()
		parent.add_child(s)
		(s as Node3D).global_position = pos
	else:
		var ex := EXPLOSION.instantiate()
		parent.add_child(ex)
		ex.global_position = pos
