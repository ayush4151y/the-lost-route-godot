extends Node3D
# IslandBuilder - builds the start and end floating islands around the path
# ends. Start island gets a tree + sign; end island gets stone ruins.
# Faithful to the original island visuals (grass slab, dirt, rocks below).

const CubeFactory = preload("res://scripts/world/cube_factory.gd")

# attach to a parent node; builds islands at given anchors (Vector2i)
func build(parent: Node3D, start_anchor: Vector2i, end_anchor: Vector2i) -> void:
	_build_island(parent, start_anchor, true)
	_build_island(parent, end_anchor, false)

func _slab_mat(flat: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.66, 0.83, 0.73)
	mat.roughness = 0.9
	return mat

func _build_island(parent: Node3D, anchor: Vector2i, is_start: bool) -> void:
	var root := Node3D.new()
	root.position = Vector3(anchor.x, 0, anchor.y)
	parent.add_child(root)

	# grass slab
	var slab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3.0, 0.5, 3.0)
	slab.mesh = bm
	slab.material_override = _slab_mat(true)
	slab.position = Vector3(0, 0.2, 0)
	root.add_child(slab)

	# dirt below
	var dirt := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(2.6, 0.4, 2.6)
	dirt.mesh = dm
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.45, 0.33, 0.22)
	dirt.material_override = dmat
	dirt.position = Vector3(0, -0.15, 0)
	root.add_child(dirt)

	# tapered rock stack below
	for i in 5:
		var rock := MeshInstance3D.new()
		var rm := BoxMesh.new()
		var size := 2.4 - i * 0.4
		rm.size = Vector3(size, 0.5, size)
		rock.mesh = rm
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color.hex(0x9aa8b5) if i % 2 == 0 else Color.hex(0x8b98a6)
		rock.material_override = rmat
		rock.position = Vector3(randf_range(-0.3, 0.3), -0.6 - i * 0.5, randf_range(-0.3, 0.3))
		root.add_child(rock)

	if is_start:
		_build_tree(root)
		_build_sign(root)
	else:
		_build_ruins(root)
		_build_rune(root)

	# gentle bob
	var tween := root.create_tween().set_loops()
	tween.tween_property(root, "position:y", 0.015, 2.0)\
		.as_relative().set_trans(Tween.TRANS_SINE)
	tween.tween_property(root, "position:y", -0.015, 2.0)\
		.as_relative().set_trans(Tween.TRANS_SINE)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _build_tree(root: Node3D) -> void:
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.15
	tm.bottom_radius = 0.2
	tm.height = 1.0
	trunk.mesh = tm
	trunk.material_override = _mat(Color(0.5, 0.35, 0.2))
	trunk.position = Vector3(1.0, 0.9, 1.0)
	root.add_child(trunk)
	for i in 3:
		var leaf := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.4
		lm.height = 0.8
		leaf.mesh = lm
		leaf.material_override = _mat(Color(0.3, 0.75, 0.3))
		leaf.position = Vector3(1.0 + randf_range(-0.2, 0.2), 1.3 + i * 0.35, 1.0 + randf_range(-0.2, 0.2))
		root.add_child(leaf)

func _build_sign(root: Node3D) -> void:
	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.04
	pm.bottom_radius = 0.04
	pm.height = 0.7
	post.mesh = pm
	post.material_override = _mat(Color(0.5, 0.35, 0.2))
	post.position = Vector3(-1.2, 0.5, -0.8)
	root.add_child(post)
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.3, 0.05)
	board.mesh = bm
	board.material_override = _mat(Color(0.6, 0.45, 0.25))
	board.position = Vector3(-1.2, 0.75, -0.8)
	board.rotation_degrees.y = 30
	root.add_child(board)

func _build_ruins(root: Node3D) -> void:
	for i in 2:
		var pillar := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.2
		pm.bottom_radius = 0.2
		pm.height = 1.4
		pillar.mesh = pm
		pillar.material_override = _mat(Color(0.7, 0.68, 0.6))
		pillar.position = Vector3(1.0 + randf_range(-0.2, 0.2), 0.8, -1.0 + i * 1.2)
		pillar.rotation.z = deg_to_rad(randf_range(-5, 5))
		root.add_child(pillar)
	# stone pile
	for i in 4:
		var stone := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.15
		sm.height = 0.3
		stone.mesh = sm
		stone.material_override = _mat(Color(0.68, 0.66, 0.58))
		stone.position = Vector3(randf_range(-1.0, 1.0), 0.3, randf_range(-1.0, 1.0))
		root.add_child(stone)

func _build_rune(root: Node3D) -> void:
	var rune := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 0.08, 0.6)
	rune.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.91, 0.86, 0.69)
	m.emission_enabled = true
	m.emission = Color(0.8, 0.7, 0.3)
	m.emission_energy_multiplier = 0.4
	rune.material_override = m
	rune.position = Vector3(0, 0.28, 0)
	root.add_child(rune)
