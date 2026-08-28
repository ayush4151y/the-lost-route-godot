extends Node3D
# CameraRig - static orbiting camera that frames the current path segment.
# Pitch fixed at 45 degrees; yaw rotates in 90-degree steps on command.
# Distance computed to fit the path AABB into view, clamped to [7, 120].

signal view_rotated

const PITCH_DEG := 45.0
const MIN_DIST := 7.0
const MAX_DIST := 120.0
const FILL := 0.90

var _cam: Camera3D
var _target := Vector3.ZERO
var _dist := 25.0
var _yaw := 0.0

func _ready() -> void:
	_cam = Camera3D.new()
	_cam.fov = 45.0
	_cam.near = 0.1
	_cam.far = 400.0
	_cam.current = true
	add_child(_cam)
	_update_position_instant()

func frame_path(cells: Array) -> void:
	# compute AABB over cell positions (Vector2i) with padding
	if cells.is_empty():
		return
	var min_x := 1e9
	var max_x := -1e9
	var min_z := 1e9
	var max_z := -1e9
	for c in cells:
		var cx: int = c.x if c is Vector2i else 0
		var cz: int = c.y if c is Vector2i else 0
		min_x = mini(min_x, cx)
		max_x = maxi(max_x, cx)
		min_z = mini(min_z, cz)
		max_z = maxi(max_z, cz)
	var w := float(max_x - min_x) + 2.0
	var h := float(max_z - min_z) + 2.0
	var half := maxf(w, h) / 2.0 + 1.0
	_target = Vector3((min_x + max_x) / 2.0, 0, (min_z + max_z) / 2.0)
	# distance so the half-size fits at pitch 45 with the given fill
	_displace(half)

func _displace(half_size: float) -> void:
	_dist = clampf(half_size / tan(deg_to_rad(_cam.fov / 2.0)), MIN_DIST, MAX_DIST) * 1.6
	_animate_to()

func rotate_view(degrees: int) -> void:
	_yaw += degrees
	_animate_to()

func _update_position_instant() -> void:
	var offset := _camera_offset()
	_cam.position = _target + offset
	_cam.look_at(_target, Vector3.UP)

func _camera_offset() -> Vector3:
	var yaw_rad := deg_to_rad(_yaw)
	var pitch := deg_to_rad(PITCH_DEG)
	return Vector3(
		sin(yaw_rad) * cos(pitch) * _dist,
		sin(pitch) * _dist,
		cos(yaw_rad) * cos(pitch) * _dist
	)

func _animate_to() -> void:
	var tween := create_tween()
	var target := _target + _camera_offset()
	tween.tween_property(_cam, "position", target, 0.6)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		_cam.look_at(_target, Vector3.UP)
		view_rotated.emit()
	)
