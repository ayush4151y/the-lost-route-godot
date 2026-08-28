extends Node3D
class_name IslandBuilder

var group: Node3D = null
var geos := []
var mats := []
var idle := []
var islands := []
var start_center: Vector2i
var end_center: Vector2i
var cf: CubeFactory
var end_cube = null

func _mat(color: int, emissive: int = 0x000000, em_int: float = 0.0, flat: bool = false) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = _hex(color)
	m.emissive_color = _hex(emissive)
	m.emissive_intensity = em_int
	m.roughness = 1.0
	m.metallic = 0.0
	m.specular_mode = StandardMaterial3D.SPECULAR_DISABLED
	m.flat_shading = flat
	mats.append(m)
	return m

func _hex(h: int) -> Color:
	return Color(float((h >> 16) & 0xff) / 255.0, float((h >> 8) & 0xff) / 255.0, float(h & 0xff) / 255.0, 1.0)

func _box(parent: Node3D, mat: StandardMaterial3D, x: float, y: float, z: float, sx: float, sy: float, sz: float) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var g = BoxMesh.new()
	g.size = Vector3(sx, sy, sz)
	geos.append(g)
	m.mesh = g
	m.material_override = mat
	m.position = Vector3(x, y, z)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(m)
	return m

func _blob(parent: Node3D, mat: StandardMaterial3D, x: float, y: float, z: float, r: float) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var g = SphereMesh.new()
	g.radius = r
	g.height = r * 2.0
	g.radial_segments = 5
	g.rings = 4
	geos.append(g)
	m.mesh = g
	m.material_override = mat
	m.position = Vector3(x, y, z)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(m)
	return m

func _hash(x: int, z: int) -> int:
	return Constants.hash2(x, z)

func _rng(x: int, z: int):
	return Constants.mulberry32(_hash(x, z))

func build(path: Array, cube_factory: CubeFactory):
	clear()
	cf = cube_factory
	var g = Node3D.new()
	group = g
	var grass = cf.material_for(Constants.GRASS, 0.12)
	var lip = _mat(0xa8ddb8)
	var dirt = _mat(0xb08968)
	var rock_a = _mat(0x9aa8b5, 0, 0, true)
	var rock_b = _mat(0x8b98a6, 0, 0, true)
	var crack = _mat(0x6d7783, 0, 0, true)
	var moss = _mat(0x6fae7a)
	var trunk = _mat(0x8a6248)
	var leaf = _mat(0x7cc576, 0, 0, true)
	var leaf2 = _mat(0x8fd98a, 0, 0, true)
	var flower_a = _mat(0xf28fbd)
	var flower_b = _mat(0xffd27a)
	var stone = _mat(0xcfd3dc, 0, 0, true)
	var pillar = _mat(0x98a0b0, 0, 0, true)
	var rune = _mat(0xe8dcb0, 0, 0, true)
	var wood = _mat(0xa07a4f, 0, 0, true)

	var first = path[0]
	var last = path[path.size() - 1]
	var d_start = path[1] - first
	var d_end = last - path[path.size() - 2]
	start_center = Vector2i(first.x - d_start.x, first.y - d_start.y)
	end_center = Vector2i(last.x + d_end.x, last.y + d_end.y)
	islands = [start_center, end_center]
	var sC = start_center
	var eC = end_center
	var path_set = {}
	for p in path:
		path_set[str(p.x) + "," + str(p.y)] = true

	var sB = Vector2i(sC.x - first.x, sC.y - first.y)
	var sP = Vector2i(-sB.y, sB.x)
	var eB = Vector2i(eC.x - last.x, eC.y - last.y)
	var eP = Vector2i(-eB.y, eB.x)

	_build_island(g, sC, path_set, grass, lip, dirt, rock_a, rock_b, crack, moss, null)
	_build_start_decor(g, sC, sB, sP, path_set, trunk, leaf, leaf2, flower_a, flower_b, stone, moss)
	var e_notch = {}
	e_notch[str(last.x + eP.x) + "," + str(last.y + eP.y)] = true
	e_notch[str(last.x - eP.x) + "," + str(last.y - eP.y)] = true
	_build_island(g, eC, path_set, grass, lip, dirt, rock_a, rock_b, crack, moss, e_notch)
	_build_end_ruins(g, eC, eB, eP, stone, pillar, rune, moss, dirt)

	add_child(g)
	idle.append({"group": g, "phase": float(_hash(sC.x, sC.y)) * 0.001})
	return g

func _build_island(g: Node3D, c: Vector2i, path_set: Dictionary, grass, lip, dirt, rock_a, rock_b, crack, moss, skip_set):
	var rng = _rng(c.x, c.y)
	var cells = []
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var x = c.x + dx
			var z = c.y + dz
			if path_set.has(str(x) + "," + str(z)):
				continue
			if skip_set != null and skip_set.has(str(x) + "," + str(z)):
				continue
			cells.append({"x": x, "z": z, "dx": dx, "dz": dz})
	for cell in cells:
		_box(g, grass, cell.x, 0.45, cell.z, 1, 1, 1)
		_box(g, lip, cell.x, 0.22, cell.z, 1.26, 0.18, 1.26)
		_box(g, dirt, cell.x, -0.62, cell.z, 1.42, 0.42, 1.42)
	var half = [1.1, 0.9, 0.72, 0.52, 0.34]
	var thk = [0.95, 0.8, 0.68, 0.56, 0.46]
	for k in range(5):
		var w = (half[k] * 2.0) * (1.0 + (rng.call() - 0.5) * 0.06)
		var t = thk[k] * (1.0 + (rng.call() - 0.5) * 0.12)
		var dx = (rng.call() - 0.5) * half[k] * 0.12
		var dz = (rng.call() - 0.5) * half[k] * 0.12
		var y = -1.45 - k * 0.82
		var rock = rock_a if (k % 2 == 0) else rock_b
		_box(g, rock, c.x + dx, y, c.y + dz, w, t, w)
	_blob(g, rock_a, c.x, -4.7, c.y, 0.3)
	for k in range(4):
		var a = rng.call() * TAU
		var r = 0.35 + rng.call() * 0.55
		_blob(g, rock_a, c.x + cos(a) * r, -2.1 - rng.call() * 1.5, c.y + sin(a) * r, 0.14 + rng.call() * 0.16)
	for k in range(4):
		var a = rng.call() * TAU
		var r = half[1 + (k % 4)] * 0.85
		_box(g, crack, c.x + cos(a) * r, -1.6 - k * 1.1, c.y + sin(a) * r, 0.12, 0.5, 0.12)
	for k in range(3):
		var a = rng.call() * TAU
		var r = half[1 + k] * 0.9
		_blob(g, moss, c.x + cos(a) * r, -1.7 - rng.call() * 2.2, c.y + sin(a) * r, 0.2 + rng.call() * 0.18)
	for k in range(3):
		var a = rng.call() * TAU
		var r = (0.25 + rng.call() * 0.5) * 1.2
		var rt = _box(g, dirt, c.x + cos(a) * r, -1.1 - rng.call() * 0.6, c.y + sin(a) * r, 0.07, 0.7 + rng.call() * 0.9, 0.07)
		rt.rotation.z = (rng.call() - 0.5) * 0.4
		rt.rotation.x = (rng.call() - 0.5) * 0.4
	var ring = cells.filter(func(cl): return abs(cl.dx) == 1 or abs(cl.dz) == 1)
	for cl in ring:
		var roll = rng.call()
		if roll < 0.4:
			_blob(g, _mat(0xcfd3dc, 0, 0, true), cl.x, 1.0, cl.z, 0.13 + rng.call() * 0.12)
			_blob(g, moss, cl.x, 0.95, cl.z, 0.1 + rng.call() * 0.08)
		elif roll < 0.62:
			_blob(g, moss, cl.x, 0.7, cl.z, 0.14)

func _build_start_decor(g: Node3D, c: Vector2i, sB: Vector2i, sP: Vector2i, path_set: Dictionary, trunk, leaf, leaf2, flower_a, flower_b, stone, moss):
	var tx = c.x + sB.x
	var tz = c.y + sB.y
	if not path_set.has(str(tx) + "," + str(tz)):
		_box(g, trunk, tx, 1.4, tz, 0.5, 1.1, 0.5)
		_blob(g, leaf, tx, 2.05, tz, 0.78)
		_blob(g, leaf2, tx + 0.35, 2.65, tz + 0.2, 0.52)
		_blob(g, leaf2, tx - 0.3, 2.55, tz - 0.3, 0.48)
	var sx = c.x + sP.x
	var sz = c.y + sP.y
	var ang = atan2(float(sB.x), float(sB.y))
	if not path_set.has(str(sx) + "," + str(sz)):
		var post = _box(g, trunk, sx, 0.95, sz, 0.12, 0.9, 0.12)
		post.rotation.y = ang
		var board = _box(g, trunk, sx, 1.45, sz, 0.62, 0.42, 0.1)
		board.rotation.y = ang
	for i in range(-1, 2):
		for j in range(-1, 2):
			if i == 0 and j == 0:
				continue
			var px = c.x + sB.x * i + sP.x * j
			var pz = c.y + sB.y * i + sP.y * j
			if path_set.has(str(px) + "," + str(pz)):
				continue
			var rng = _rng(px, pz)
			var roll = rng.call()
			if roll < 0.28:
				_box(g, (flower_a if roll < 0.13 else flower_b), px, 1.1, pz, 0.2, 0.4, 0.2)
				_blob(g, moss, px, 1.03, pz, 0.1)
			elif roll < 0.4:
				_blob(g, stone, px, 1.0, pz, 0.16 + rng.call() * 0.12)
			elif roll < 0.48:
				_box(g, flower_a, px, 1.15, pz, 0.16, 0.45, 0.16)

func _build_end_ruins(g: Node3D, c: Vector2i, eB: Vector2i, eP: Vector2i, stone, pillar, rune, moss, dirt):
	var rng = _rng(c.x, c.y)
	var cx = c.x + eB.x * 0.35
	var cz = c.y + eB.y * 0.35
	for k in range(7):
		var a = float(k) / 7.0 * TAU + rng.call() * 0.3
		var px = cx + cos(a) * 0.8
		var pz = cz + sin(a) * 0.8
		_blob(g, stone, px, 0.92, pz, 0.2 + rng.call() * 0.06)
		_blob(g, moss, px + (rng.call() - 0.5) * 0.2, 0.9, pz + (rng.call() - 0.5) * 0.2, 0.08)
	var rune_tile = _box(g, rune, cx, 0.85, cz, 0.42, 0.08, 0.42)
	rune_tile.rotation.y = rng.call() * PI
	for k in range(2):
		var side = 1 if k == 0 else -1
		var ph = 0.7 + rng.call() * 0.8
		var px = cx + eP.x * side * 0.9 + (rng.call() - 0.5) * 0.2
		var pz = cz + eP.y * side * 0.9 + (rng.call() - 0.5) * 0.2
		var pil = _box(g, pillar, px, ph / 2.0 + 0.55, pz, 0.34, ph, 0.34)
		pil.rotation.x = (rng.call() - 0.5) * 0.25
		pil.rotation.z = (rng.call() - 0.5) * 0.25
		_blob(g, stone, px, pil.position.y + ph / 2.0 + 0.1, pz, 0.16)
	for k in range(3):
		_blob(g, stone, c.x + eB.x * 0.85 + eP.x * 0.4 + (rng.call() - 0.5) * 0.4, 0.85 + k * 0.18, c.y + eB.y * 0.85 + eP.y * 0.4 + (rng.call() - 0.5) * 0.4, 0.16 + k * 0.05)

func is_on_island(x: int, z: int) -> bool:
	for c in islands:
		if c.x == x and c.y == z:
			return true
	return false

func build_end_only(_path: Array):
	if end_cube == null:
		end_cube = MeshInstance3D.new()
		add_child(end_cube)
	var t = TextureFactory.cube_texture(Constants.END)
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = t
	mat.emission_enabled = true
	mat.emission_texture = t
	mat.emission_intensity = 0.4
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	end_cube.mesh = _cube_mesh()
	end_cube.material_override = mat
	var ep = _path[_path.size() - 1]
	end_cube.position = Vector3(ep.x, -0.45, ep.y)

func _cube_mesh() -> BoxMesh:
	var g = BoxMesh.new()
	g.size = Vector3(1.0, 0.9, 1.0)
	return g

func update(dt: float):
	var t = Time.get_ticks_msec() / 1000.0
	for id in idle:
		id["group"].position.y = sin(t * 0.6 + id["phase"]) * 0.015

func clear():
	if group != null:
		group.queue_free()
		group = null
	start_center = Vector2i.ZERO
	end_center = Vector2i.ZERO
	islands = []
	geos = []
	mats = []
	idle = []
