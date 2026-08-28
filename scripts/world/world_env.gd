extends Node3D
class_name WorldEnv

var clouds := []
var drift := []
var leaves := []
var butterflies := []
var birds := []
var rng = RandomNumberGenerator.new()
var environment: Environment

func _ready():
	rng.randomize()
	_build_sky()
	_build_lights()
	_build_clouds()
	_build_distant_islands()
	_build_leaves()
	_build_butterflies()
	_build_birds()

func _build_sky():
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sm = ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.42, 0.71, 0.86)
	sm.sky_horizon_color = Color(0.66, 0.87, 0.94)
	sm.ground_horizon_color = Color(0.86, 0.82, 0.66)
	sm.ground_bottom_color = Color(0.78, 0.86, 0.90)
	sky.sky_material = sm
	env.sky = sky
	env.fog_enabled = true
	env.fog_light_color = Color(0.74, 0.83, 0.88)
	env.fog_light_energy = 0.9
	env.fog_density = 0.006
	env.ambient_light_color = Color(0.62, 0.78, 0.91)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	var we = WorldEnvironment.new()
	we.environment = env
	environment = env
	add_child(we)

func _build_lights():
	var sun = DirectionalLight3D.new()
	sun.position = Vector3(12, 18, 6)
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(25), 0)
	sun.light_color = Color(1.0, 0.9, 0.69)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.shadow_bias = 0.0004
	sun.shadow_normal_bias = 0.02
	add_child(sun)
	var fill = DirectionalLight3D.new()
	fill.position = Vector3(-6, 6, -6)
	fill.light_color = Color(0.53, 0.72, 0.91)
	fill.light_energy = 0.35
	add_child(fill)

func _mat(color: Color, opacity: float, depth: bool) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	if opacity < 1.0:
		m.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = opacity
	m.flags_unshadowed = true
	m.specular_mode = StandardMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	return m

func _build_clouds():
	var layers = [
		{"count": 7, "y": 52, "speed": 0.05, "op": 0.4, "smin": 2.4, "w": 3.4, "wrap": 145},
		{"count": 5, "y": 64, "speed": 0.14, "op": 0.6, "smin": 1.7, "w": 2.4, "wrap": 125},
		{"count": 3, "y": 78, "speed": 0.3, "op": 0.85, "smin": 1.2, "w": 1.8, "wrap": 105},
	]
	var mat = _mat(Color.WHITE, 0.5, false)
	for L in layers:
		for i in range(L["count"]):
			var g = Node3D.new()
			var n = 2 + int(rng.randf() * 3)
			for j in range(n):
				var b: MeshInstance3D
				if j % 2 == 1:
					b = MeshInstance3D.new()
					var bm = BoxMesh.new()
					var w = L["w"] * (0.8 + rng.randf() * 0.9)
					bm.size = Vector3(w, L["smin"] / 2.0, L["w"] * (0.7 + rng.randf() * 0.6))
					b.mesh = bm
					b.position = Vector3((j - n / 2.0) * w * 0.7, (rng.randf() - 0.5) * 0.5, (rng.randf() - 0.5) * 1.4)
				else:
					b = MeshInstance3D.new()
					var bm = SphereMesh.new()
					var s = L["smin"] * (1.0 + rng.randf() * 1.2)
					bm.radius = s
					bm.height = s * 2.0
					bm.radial_segments = 4
					bm.rings = 3
					b.mesh = bm
					b.position = Vector3((j - n / 2.0) * s * 1.4, (rng.randf() - 0.5) * 0.5, (rng.randf() - 0.5) * 1.2)
				b.material_override = mat
				g.add_child(b)
			var a = rng.randf() * TAU
			var r = 30 + rng.randf() * (L["wrap"] - 30)
			g.position = Vector3(cos(a) * r, L["y"] + (rng.randf() - 0.5) * 7, sin(a) * r)
			g.set_meta("speed", L["speed"])
			g.set_meta("wrap", L["wrap"])
			g.set_meta("dir", 1 if rng.randf() < 0.5 else -1)
			add_child(g)
			clouds.append(g)

func _build_distant_islands():
	var colors = [Color(0.78, 0.90, 0.89), Color(0.84, 0.85, 0.94), Color(0.95, 0.86, 0.78), Color(0.78, 0.84, 0.92)]
	var mat = _mat(colors[0], 0.12, false)
	for i in range(9):
		var g = Node3D.new()
		var s = 2.5 + rng.randf() * 5
		var la = 2 + int(rng.randf() * 3)
		for j in range(la):
			var w = s * (1 - j * 0.22)
			var b = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(w, 0.5 + (la - j) * 0.4, w)
			b.mesh = bm
			b.material_override = mat
			b.position = Vector3((rng.randf() - 0.5) * w, 0.4 + j, (rng.randf() - 0.5) * w)
			g.add_child(b)
		var cone = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = s * 0.4
		cm.height = s * 0.8
		cone.mesh = cm
		cone.material_override = mat
		cone.position.y = la
		g.add_child(cone)
		var a = rng.randf() * TAU
		var r = 90 + rng.randf() * 50
		g.position = Vector3(cos(a) * r, 3 + rng.randf() * 6, sin(a) * r)
		g.set_meta("speed", 0.02 + rng.randf() * 0.04)
		g.set_meta("wrap", 160)
		g.set_meta("dir", 1 if rng.randf() < 0.5 else -1)
		add_child(g)
		drift.append(g)

func _build_leaves():
	var colors = [Color(0.66, 0.85, 0.51), Color(0.79, 0.90, 0.69), Color(0.56, 0.76, 0.48)]
	for i in range(16):
		var b = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.09, 0.02, 0.11)
		b.mesh = bm
		b.material_override = _mat(colors[i % 3], 0.85, false)
		b.position = Vector3((rng.randf() - 0.5) * 46, 6 + rng.randf() * 14, (rng.randf() - 0.5) * 46)
		b.set_meta("vy", 0.35 + rng.randf() * 0.5)
		b.set_meta("sway", 0.4 + rng.randf() * 0.8)
		b.set_meta("phase", rng.randf() * 6)
		b.set_meta("rot", rng.randf() * 6)
		add_child(b)
		leaves.append(b)

func _build_butterflies():
	var mat = _mat(Color(0.94, 0.65, 0.78), 0.9, false)
	for i in range(4):
		var g = Node3D.new()
		for s in [-1, 1]:
			var w = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(0.16, 0.24, 0.02)
			w.mesh = bm
			w.material_override = mat
			w.position.x = 0.08 * s
			g.add_child(w)
		g.position = Vector3((rng.randf() - 0.5) * 30, 4 + rng.randf() * 3, (rng.randf() - 0.5) * 30)
		g.set_meta("phase", rng.randf() * 6)
		g.set_meta("cx", g.position.x)
		g.set_meta("cz", g.position.z)
		add_child(g)
		butterflies.append(g)

func _build_birds():
	var mat = _mat(Color(0.23, 0.29, 0.35), 1.0, false)
	for i in range(3):
		var g = Node3D.new()
		for s in [-1, 1]:
			var w = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(0.6, 0.02, 0.35)
			w.mesh = bm
			w.material_override = mat
			w.position.x = 0.3 * s
			w.rotation.y = 0.6 * s
			g.add_child(w)
		var a = rng.randf() * TAU
		g.position = Vector3(cos(a) * 15, 8 + rng.randf() * 4, sin(a) * 15)
		g.set_meta("angle", a)
		g.set_meta("radius", 12 + rng.randf() * 10)
		g.set_meta("speed", 0.15 + rng.randf() * 0.15)
		g.set_meta("yBase", g.position.y)
		add_child(g)
		birds.append(g)

func update(dt: float):
	var t = Time.get_ticks_msec() / 1000.0
	for g in clouds:
		g.position.x += g.get_meta("speed") * g.get_meta("dir") * dt
		if abs(g.position.x) > g.get_meta("wrap"):
			g.set_meta("dir", -g.get_meta("dir"))
	for g in drift:
		g.position.x += g.get_meta("speed") * g.get_meta("dir") * dt
		if abs(g.position.x) > g.get_meta("wrap"):
			g.set_meta("dir", -g.get_meta("dir"))
	for leaf in leaves:
		leaf.position.y -= leaf.get_meta("vy") * dt
		leaf.position.x += sin(t * leaf.get_meta("sway") + leaf.get_meta("phase")) * dt * 0.6
		leaf.position.z += cos(t * leaf.get_meta("sway") * 0.8 + leaf.get_meta("phase")) * dt * 0.4
		leaf.rotation.z += leaf.get_meta("rot") * dt
		if leaf.position.y < -1.5:
			leaf.position.y = 20
			leaf.position.x = (rng.randf() - 0.5) * 46
			leaf.position.z = (rng.randf() - 0.5) * 46
	for b in butterflies:
		b.position.x = b.get_meta("cx") + sin(t * 0.7 + b.get_meta("phase")) * 1.2
		b.position.y = 5 + sin(t * 1.4 + b.get_meta("phase") * 2) * 0.6
		b.position.z = b.get_meta("cz") + cos(t * 0.7 + b.get_meta("phase")) * 1.2
		b.get_child(0).rotation.z = sin(t * 12 + b.get_meta("phase")) * 0.6
		b.get_child(1).rotation.z = -sin(t * 12 + b.get_meta("phase")) * 0.6
	for b in birds:
		var ang = b.get_meta("angle") + b.get_meta("speed") * dt
		b.set_meta("angle", ang)
		b.position.x = cos(ang) * b.get_meta("radius")
		b.position.z = sin(ang) * b.get_meta("radius")
		b.position.y = b.get_meta("yBase") + sin(t * 2) * 1.2

func set_fog_lite(lite: bool):
	if environment == null:
		return
	environment.fog_density = 0.018 if lite else 0.03
