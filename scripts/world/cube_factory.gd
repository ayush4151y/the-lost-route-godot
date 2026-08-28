extends Node3D
class_name CubeFactory

const NORMAL_Y := 0.5
const HIDDEN_Y := -0.8

var palette := {
	Constants.GRASS: {"albedo": 0x4caf50, "emissive": 0x2e7d32},
	Constants.ICE: {"albedo": 0x2196f3, "emissive": 0x1565c0},
	Constants.FIRE: {"albedo": 0xff9800, "emissive": 0xe65100},
	Constants.TNT: {"albedo": 0xb71c1c, "emissive": 0x4a0000},
	Constants.HEART: {"albedo": 0xe91e63, "emissive": 0x880e4f},
	Constants.START: {"albedo": 0x57c25b, "emissive": 0x2e7d32},
	Constants.END: {"albedo": 0xffd24a, "emissive": 0xc79100},
}

var tex_factory: TextureFactory
var materials := {}
var box_geo: BoxMesh
var decoy_geo: BoxMesh
var cubes := {}          # "x,z" -> MeshInstance3D
var path_cubes := []      # MeshInstance3D in path order
var decoy_cubes := []
var path_line: Node3D = null
var blast_props := []
var gm = null

func _ready():
	tex_factory = TextureFactory.new()
	box_geo = BoxMesh.new()
	box_geo.size = Vector3(0.9, 0.9, 0.9)
	decoy_geo = BoxMesh.new()
	decoy_geo.size = Vector3(0.7, 0.8, 0.7)

func material_for(type: String, emissive_intensity := 0.18) -> StandardMaterial3D:
	var key = type + "_" + str(emissive_intensity)
	if materials.has(key):
		return materials[key]
	var p = palette[type]
	var m = StandardMaterial3D.new()
	m.albedo_texture = tex_factory.cube_texture(type)
	m.albedo_color = Color(1, 1, 1, 1)
	m.emissive_texture = tex_factory.cube_texture(type)
	m.emissive_color = _hex(p["emissive"])
	m.emissive_intensity = emissive_intensity
	m.roughness = 1.0
	m.metallic = 0.0
	m.specular_mode = StandardMaterial3D.SPECULAR_DISABLED
	materials[key] = m
	return m

func _hex(h: int) -> Color:
	return Color(float((h >> 16) & 0xff) / 255.0, float((h >> 8) & 0xff) / 255.0, float(h & 0xff) / 255.0, 1.0)

func clear():
	for c in path_cubes + decoy_cubes:
		c.queue_free()
	if path_line != null:
		path_line.queue_free()
		path_line = null
	for f in blast_props:
		f.queue_free()
	blast_props = []
	materials = {}
	cubes = {}
	path_cubes = []
	decoy_cubes = []

func build_from_path(path: Array, blocks: BlockManager, start_index: int = 0):
	if start_index == 0:
		clear()
	for i in range(start_index, path.size()):
		var pos = path[i]
		var is_start = (i == 0)
		var is_end = (i == path.size() - 1)
		var type = Constants.GRASS
		if not is_start and not is_end and blocks != null:
			type = blocks.type_of(i)
		var mat_type = type
		if is_start:
			mat_type = Constants.START
		elif is_end:
			mat_type = Constants.END
		var cube = MeshInstance3D.new()
		cube.mesh = box_geo
		cube.material_override = material_for(mat_type, 0.18)
		cube.position = Vector3(float(pos.x), HIDDEN_Y, float(pos.y))
		cube.visible = false
		cube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cube.set_meta("path_index", i)
		cube.set_meta("is_start", is_start)
		cube.set_meta("is_end", is_end)
		cube.set_meta("type", type)
		cube.set_meta("revealed", is_start or is_end)
		cube.set_meta("hidden", true)
		add_child(cube)
		cubes[str(pos.x) + "," + str(pos.y)] = cube
		path_cubes.append(cube)
		if is_start:
			_reveal(cube, Constants.START)
		if is_end:
			_reveal(cube, Constants.END)

	if blocks != null:
		for d in blocks.decoys:
			var key = str(d.x) + "," + str(d.y)
			if cubes.has(key):
				continue
			var dc = MeshInstance3D.new()
			dc.mesh = decoy_geo
			dc.material_override = material_for(Constants.TNT, 0.18)
			dc.position = Vector3(float(d.x), HIDDEN_Y, float(d.y))
			dc.visible = false
			dc.set_meta("type", Constants.TNT)
			dc.set_meta("hidden", true)
			add_child(dc)
			cubes[key] = dc
			decoy_cubes.append(dc)

func _reveal(cube: MeshInstance3D, type: String):
	if cube.get_meta("revealed"):
		return
	cube.set_meta("revealed", true)
	cube.material_override = material_for(type, 0.32)

func reveal_type(cube: MeshInstance3D):
	if cube == null:
		return
	var t = cube.get_meta("type")
	if t == Constants.GRASS or cube.get_meta("revealed"):
		return
	_reveal(cube, t)

func rise_cube_at(index: int):
	var cube = path_cubes[index] if index < path_cubes.size() else null
	if cube == null:
		return
	gm.play_sfx("cube-rise", 0.6)
	cube.visible = true
	cube.set_meta("hidden", false)
	reveal_type(cube)
	if abs(cube.position.y - NORMAL_Y) < 0.01:
		return
	_tween_y(cube, NORMAL_Y, 0.3)

func hint_rise_at(index: int):
	var cube = path_cubes[index] if index < path_cubes.size() else null
	if cube == null:
		return
	cube.visible = true
	cube.set_meta("hidden", false)
	reveal_type(cube)
	var m = cube.material_override
	if m != null:
		m.emissive_color = Color(1.0, 0.835, 0.31)
		m.emissive_intensity = 0.6
	await get_tree().create_timer(0.6).timeout
	if m != null and is_instance_valid(m):
		var t = cube.get_meta("type")
		var p = palette[t]
		m.emissive_color = _hex(p["emissive"])
		m.emissive_intensity = 0.32
	if abs(cube.position.y - NORMAL_Y) < 0.01:
		return
	_tween_y(cube, NORMAL_Y, 0.3)

func rise_decoy_at(x: int, z: int):
	var cube = cubes.get(str(x) + "," + str(z))
	if cube == null:
		return
	gm.play_sfx("cube-rise", 0.6)
	cube.visible = true
	cube.set_meta("hidden", false)
	_tween_y(cube, NORMAL_Y, 0.3, flash_after.bind(cube))

func flash_after(cube: MeshInstance3D):
	var m = cube.material_override
	if m == null:
		return
	var orig_e = m.emissive_color
	var orig_i = m.emissive_intensity
	m.emissive_color = Color(0.30, 0.82, 0.85)
	m.emissive_intensity = 0.6
	await get_tree().create_timer(0.25).timeout
	if is_instance_valid(m):
		m.emissive_color = orig_e
		m.emissive_intensity = orig_i

func blast_at(x: int, z: int, on_done: Callable):
	var cube = cubes.get(str(x) + "," + str(z))
	var flash = MeshInstance3D.new()
	flash.mesh = SphereMesh.new()
	flash.mesh.radius = 0.5
	flash.mesh.height = 1.0
	var fm = StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.95, 0.84)
	fm.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	fm.emissive_color = Color(1.0, 0.95, 0.84)
	fm.emissive_intensity = 1.0
	flash.material_override = fm
	var base_pos = Vector3(float(x), NORMAL_Y, float(z))
	if cube != null:
		base_pos = cube.position
	flash.position = base_pos
	add_child(flash)
	blast_props.append(flash)
	var tw = create_tween()
	tw.tween_property(flash, "scale", Vector3(3.2, 3.2, 3.2), 0.45)
	tw.parallel().tween_property(fm, "albedo_color:a", 0.0, 0.45)
	if cube != null:
		var tw2 = create_tween()
		tw2.tween_property(cube, "position:y", cube.position.y + 0.6, 0.15)
	await get_tree().create_timer(0.48).timeout
	if cube != null:
		cube.visible = false
		cube.position.y = HIDDEN_Y
	if is_instance_valid(flash):
		flash.queue_free()
	blast_props.erase(flash)
	if on_done != null:
		on_done.call()

func start_idle_animations():
	for cube in path_cubes:
		if cube == null:
			continue
		if cube.get_meta("is_start"):
			_pulse(cube, _hex(palette[Constants.START]["emissive"]), 0.3, 1.2)
		elif cube.get_meta("is_end"):
			_pulse(cube, _hex(palette[Constants.END]["emissive"]), 0.3, 0.9)

func _pulse(cube: MeshInstance3D, emissive_color: Color, intensity: float, duration: float):
	if cube == null:
		return
	var m = cube.material_override
	if m == null:
		return
	var orig = 0.18
	var tw = create_tween()
	tw.set_loops()
	tw.tween_method(func(v):
		if is_instance_valid(m):
			m.emissive_intensity = orig + v * intensity
		if is_instance_valid(cube):
			var s = 1.0 + v * 0.04
			cube.scale = Vector3(s, s, s)
	, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE)

func draw_path_line(path: Array, start_index: int = 0):
	remove_path_line()
	path_line = Node3D.new()
	add_child(path_line)
	for i in range(start_index, path.size()):
		var p = path[i]
		var b = MeshInstance3D.new()
		b.mesh = box_geo
		var m = StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.43, 0.0)
		m.emissive_color = Color(1.0, 0.43, 0.0)
		m.emissive_intensity = 0.6
		b.material_override = m
		b.scale = Vector3(1.0, 0.15, 1.0)
		b.position = Vector3(float(p.x), 0.98, float(p.y))
		path_line.add_child(b)

func remove_path_line():
	if path_line != null:
		path_line.queue_free()
		path_line = null

func show_path_wave(start_index: int = 0):
	for i in range(start_index, path_cubes.size()):
		if i >= path_cubes.size():
			break
		var cube = path_cubes[i]
		cube.visible = true
		_tween_y(cube, NORMAL_Y, 0.25)
		cube.set_meta("hidden", false)
		gm.play_sfx("cube-rise", 0.45)
		await get_tree().create_timer(0.1).timeout

func hide_path_wave(start_index: int = 0):
	for i in range(start_index, path_cubes.size()):
		if i >= path_cubes.size():
			break
		var cube = path_cubes[i]
		if cube.get_meta("is_start") or cube.get_meta("is_end"):
			continue
		_tween_y(cube, HIDDEN_Y, 0.2)
		cube.set_meta("hidden", true)
		await get_tree().create_timer(0.08).timeout

func sink_old_cubes(keep_index: int):
	for cube in path_cubes:
		if cube.get_meta("path_index") < keep_index and not cube.get_meta("hidden"):
			_tween_y(cube, HIDDEN_Y, 0.2)
			cube.set_meta("hidden", true)

func retype_cube(index: int, type: String):
	var cube = path_cubes[index] if index < path_cubes.size() else null
	if cube == null:
		return
	cube.set_meta("type", type)
	cube.material_override = material_for(type, 0.18)
	cube.set_meta("revealed", false)

func _tween_y(cube: MeshInstance3D, to_y: float, dur: float, done: Callable = Callable()):
	if cube == null or not is_instance_valid(cube):
		if done != null:
			done.call()
		return
	var tw = create_tween()
	tw.tween_property(cube, "position:y", to_y, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if done != null:
		tw.tween_callback(done)
