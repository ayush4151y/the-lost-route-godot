extends Node3D
class_name Player

const BODY_COLOR := 0x9be3ef
const BODY_EMISSIVE := 0x2fb6cf

var body: MeshInstance3D
var body_mat: StandardMaterial3D
var is_moving := false
var current_index := 0
var on_fire := false
var _pulse_id := 0

func _ready():
	_build()

func _build():
	if body != null:
		return
	body = MeshInstance3D.new()
	var geo = BoxMesh.new()
	geo.size = Vector3(0.56, 0.56, 0.56)
	body.mesh = geo
	body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = _hex(BODY_COLOR)
	body_mat.emissive_color = _hex(BODY_EMISSIVE)
	body_mat.emissive_intensity = 0.22
	body_mat.roughness = 0.5
	body_mat.metallic = 0.0
	body_mat.specular_mode = StandardMaterial3D.SPECULAR_DISABLED
	body.material_override = body_mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(body)

	var face = Node3D.new()
	face.position = Vector3(0, 0, 0.32)
	add_child(face)

	_mk_sphere(face, Vector3(-0.105, 0.14, 0), 0.085, 0x1b2b36, 0.3)
	_mk_sphere(face, Vector3(0.105, 0.14, 0), 0.085, 0x1b2b36, 0.3)
	_mk_sphere(face, Vector3(-0.115, 0.165, 0.065), 0.028, 0xffffff, 0.8)
	_mk_sphere(face, Vector3(0.095, 0.165, 0.065), 0.028, 0xffffff, 0.8)
	_mk_sphere(face, Vector3(-0.2, 0.04, 0.02), 0.045, 0xff8fa5, 0.35)
	_mk_sphere(face, Vector3(0.2, 0.04, 0.02), 0.045, 0xff8fa5, 0.35)
	_mk_sphere(face, Vector3(-0.13, 0.1, 0.06), 0.02, 0xffd2dc, 0.3)
	_mk_sphere(face, Vector3(0.13, 0.1, 0.06), 0.02, 0xffd2dc, 0.3)

func _mk_sphere(parent: Node3D, pos: Vector3, r: float, color: int, em: float):
	var s = MeshInstance3D.new()
	var geo = SphereMesh.new()
	geo.radius = r
	geo.height = r * 2.0
	s.mesh = geo
	var m = StandardMaterial3D.new()
	m.albedo_color = _hex(color)
	m.emissive_color = _hex(color)
	m.emissive_intensity = em
	m.roughness = 0.4
	m.specular_mode = StandardMaterial3D.SPECULAR_DISABLED
	s.material_override = m
	s.position = pos
	parent.add_child(s)

func _hex(h: int) -> Color:
	return Color(float((h >> 16) & 0xff) / 255.0, float((h >> 8) & 0xff) / 255.0, float(h & 0xff) / 255.0, 1.0)

func create(path_start: Vector2i, scale_v: float = 1.0):
	_build()
	is_moving = false
	current_index = 0
	position = Vector3(float(path_start.x), 1.2, float(path_start.y))
	scale = Vector3(scale_v, scale_v, scale_v)
	visible = true
	_start_pulse()

func set_face_direction(dx: int, dz: int):
	rotation.y = atan2(float(dx), float(dz))

func move_to(pos: Vector2i, path_index: int, callback: Callable):
	if is_moving:
		return
	is_moving = true
	var start = position
	var end = Vector3(float(pos.x), 1.2, float(pos.y))
	set_face_direction(pos.x - int(start.x), pos.y - int(start.y))
	var tw = create_tween()
	tw.tween_method(func(t):
		if not is_instance_valid(self):
			return
		position = start.lerp(end, t)
		position.y = 1.2 + sin(t * PI) * 0.15
	, 0.0, 1.0, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(func():
		if not is_instance_valid(self):
			return
		is_moving = false
		current_index = path_index
		if callback != null:
			callback.call()
	)

func _start_pulse():
	_pulse_id += 1
	var pid = _pulse_id
	var base = scale.x
	var tw = create_tween()
	tw.set_loops()
	tw.tween_method(func(v):
		if pid != _pulse_id:
			return
		if not is_instance_valid(self):
			return
		var s = base + 0.08 * sin(v * TAU)
		scale = Vector3(s, s, s)
	, 0.0, 1.0, 0.8)

func set_fire(on: bool):
	if on == on_fire:
		return
	on_fire = on
	if on:
		var tw = create_tween()
		tw.set_loops()
		tw.tween_method(func(tick):
			if not on_fire or body_mat == null:
				return
			if tick < 0.5:
				body_mat.albedo_color = _hex(0xff4444)
				body_mat.emissive_color = _hex(0xff2222)
				body_mat.emissive_intensity = 0.8
			else:
				body_mat.albedo_color = _hex(BODY_COLOR)
				body_mat.emissive_color = _hex(BODY_EMISSIVE)
				body_mat.emissive_intensity = 0.22
		, 0.0, 1.0, 0.28)
	else:
		body_mat.albedo_color = _hex(BODY_COLOR)
		body_mat.emissive_color = _hex(BODY_EMISSIVE)
		body_mat.emissive_intensity = 0.22

func destroy():
	_pulse_id += 1
	on_fire = false
	visible = false
