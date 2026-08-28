extends Node3D
# Environment - sky gradient dome, drifting clouds, distant islands,
# falling leaves, butterflies and birds. Faithful ambience to the original.

var _time := 0.0

func _ready() -> void:
	_build_sky()
	_build_clouds()
	_build_distant_islands()
	_build_leaves()

func _process(delta: float) -> void:
	_time += delta
	_drift_clouds(delta)
	_drift_islands(delta)
	_fall_leaves(delta)

func _build_sky() -> void:
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	sky.sky_material = mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.78, 0.91)
	env.ambient_light_energy = 0.55
	env.fog_enabled = false
	var world := get_viewport().world_3d
	world.environment = env

func build_cloud() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(2.5, 0.4, 1.5)
	mi.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	return mi

func _build_clouds() -> void:
	for i in 3:
		var arr_int := [7, 5, 3]
		var arr_y := [52.0, 64.0, 78.0]
		var arr_speed := [0.05, 0.14, 0.3]
		var count: int = arr_int[i]
		var y: float = arr_y[i]
		var speed: float = arr_speed[i]
		for c in count:
			var cloud := build_cloud()
			cloud.position = Vector3(randf_range(-60, 60), y, randf_range(-40, 40))
			cloud.set_meta("speed", speed)
			cloud.set_meta("base_y", y)
			cloud.scale = Vector3(randf_range(1, 2), 1, randf_range(1, 2))
			add_child(cloud)

func _drift_clouds(delta: float) -> void:
	for child in get_children():
		if child is MeshInstance3D and child.has_meta("speed"):
			var sp: float = child.get_meta("speed")
			child.position.x += sp * delta
			if child.position.x > 70:
				child.position.x = -70

func build_island() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 1.4
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(randf_range(0.3, 0.8), randf_range(0.6, 0.9), randf_range(0.5, 0.9), 0.12)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	return mi

func _build_distant_islands() -> void:
	for i in 9:
		var isl := build_island()
		var ang := randf_range(0, TAU)
		var r := randf_range(90, 140)
		isl.position = Vector3(cos(ang) * r, randf_range(3, 9), sin(ang) * r)
		isl.scale = Vector3.ONE * randf_range(2, 6)
		isl.set_meta("angle", ang)
		isl.set_meta("radius", r)
		isl.set_meta("h", isl.position.y)
		add_child(isl)

func _drift_islands(delta: float) -> void:
	for child in get_children():
		if child is MeshInstance3D and child.has_meta("angle"):
			var a: float = child.get_meta("angle")
			var r: float = child.get_meta("radius")
			a += delta * 0.02
			child.set_meta("angle", a)
			child.position.x = cos(a) * r
			child.position.z = sin(a) * r
			child.position.y = child.get_meta("h") + sin(_time * 0.5) * 0.5

func build_leaf() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.15, 0.05, 0.3)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.8, 0.3)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	return mi

func _build_leaves() -> void:
	for i in 16:
		var leaf := build_leaf()
		leaf.position = Vector3(randf_range(-30, 30), randf_range(6, 20), randf_range(-30, 30))
		leaf.set_meta("base_x", leaf.position.x)
		add_child(leaf)

func _fall_leaves(delta: float) -> void:
	for child in get_children():
		if child is MeshInstance3D and child.has_meta("base_x"):
			child.position.y -= delta * 2.0
			child.position.x = child.get_meta("base_x") + sin(_time * 1.5 + child.position.y) * 1.5
			child.rotation.y += delta
			if child.position.y < 0:
				child.position.y = 20
