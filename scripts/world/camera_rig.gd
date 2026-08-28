extends Node3D
class_name CameraRig

const MIN_DISTANCE := 7.0
const MAX_DISTANCE := 120.0
const PITCH := 45.0
const SCREEN_FILL := 0.9
const ANIM_MS := 600.0

var camera: Camera3D
var gm = null
var cam_yaw := 0.0
var cam_distance := 20.0
var cam_frame := {}
var cam_segment_start := 0
var cam_segment_end := 0
var center := Vector3.ZERO

func setup(cam: Camera3D, game_manager):
	camera = cam
	gm = game_manager
	camera.fov = 45.0

func set_yaw(y: float):
	cam_yaw = y

func adjust_camera_to_path(range_start: int = 0, range_end: int = -1):
	if camera == null or gm == null:
		return
	var path = gm.path
	if path == null or path.is_empty():
		return
	var end = range_end if range_end >= 0 else path.size() - 1
	var min_x = INF; var min_z = INF; var max_x = -INF; var max_z = -INF
	for i in range(range_start, end + 1):
		var p = path[i]
		min_x = min(min_x, p.x); max_x = max(max_x, p.x)
		min_z = min(min_z, p.y); max_z = max(max_z, p.y)
	var cx = (min_x + max_x) / 2.0
	var cz = (min_z + max_z) / 2.0
	center = Vector3(cx, 0, cz)
	var vfov = deg_to_rad(camera.fov)
	var aspect = float(get_viewport().size.x) / max(1.0, float(get_viewport().size.y))
	var hfov = 2.0 * atan(tan(vfov / 2.0) * max(aspect, 0.3))
	var theta = deg_to_rad(PITCH)
	var yaw = deg_to_rad(cam_yaw)
	var s = sin(theta); var c = cos(theta)
	var sinY = sin(yaw); var cosY = cos(yaw)
	var tanV = tan(vfov / 2.0)
	var tanH = tan(hfov / 2.0)
	var target = SCREEN_FILL * 0.98
	var topY = 2.4
	var EXT = 2.0
	var xs = [min_x - EXT, max_x + EXT]
	var zs = [min_z - EXT, max_z + EXT]

	var fitNdc = func(D):
		var G = D * c
		var Hgt = D * s
		var cam = Vector3(cx + sinY * G, Hgt, cz + cosY * G)
		var fx = -sinY * c; var fy = -s; var fz = -cosY * c
		var rx = cosY; var rz = -sinY
		var ux = -s * sinY; var uy = c; var uz = -s * cosY
		var maxN = 0.0
		for xi in [0, 1]:
			for zi in [0, 1]:
				for yi in [0, 1]:
					var wx = xs[xi]; var wz = zs[zi]; var wy = 0.0 if yi == 0 else topY
					var vx = wx - cam.x; var vy = wy - cam.y; var vz = wz - cam.z
					var depth = vx * fx + vy * fy + vz * fz
					if depth <= 0.001:
						return 1e9
					var unx = abs((vx * rx + vz * rz) / (depth * tanH))
					var uny = abs((vx * ux + vy * uy + vz * uz) / (depth * tanV))
					maxN = max(maxN, max(unx, uny))
		return maxN

	var lo = MIN_DISTANCE
	var hi = max(MAX_DISTANCE * 1.8, 80.0)
	for i in range(40):
		var mid = (lo + hi) / 2.0
		if fitNdc.call(mid) <= target:
			hi = mid
		else:
			lo = mid
	var vd = hi
	if fitNdc.call(MIN_DISTANCE) <= target:
		vd = MIN_DISTANCE
	vd = clamp(vd, MIN_DISTANCE, MAX_DISTANCE)
	cam_distance = vd
	cam_frame = {"min_x": min_x, "max_x": max_x, "min_z": min_z, "max_z": max_z}
	cam_segment_start = range_start
	cam_segment_end = end
	frame_camera_at(vd, cx, cz, range_start, end)

func frame_camera_at(vd: float, cx: float, cz: float, range_start: int, end: int):
	var theta = deg_to_rad(PITCH)
	var yaw = deg_to_rad(cam_yaw)
	var s = sin(theta); var c = cos(theta)
	var sinY = sin(yaw); var cosY = cos(yaw)
	var G = vd * c
	var H = vd * s
	var tx = cx + sinY * G
	var tz = cz + cosY * G
	cam_segment_start = range_start
	cam_segment_end = end
	var from = camera.position
	var to = Vector3(tx, H, tz)
	var tw = create_tween()
	tw.tween_method(func(t):
		camera.position = from.lerp(to, t)
		camera.look_at(center, Vector3.UP)
	, 0.0, 1.0, ANIM_MS / 1000.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

func rotate_view(delta: float = 90.0):
	if camera == null or cam_frame.is_empty() or gm == null:
		return
	gm.play_sfx("camera-rotate", 0.8)
	cam_yaw = fmod(cam_yaw + delta, 360.0)
	if cam_yaw < 0:
		cam_yaw += 360.0
	var cx = (cam_frame["min_x"] + cam_frame["max_x"]) / 2.0
	var cz = (cam_frame["min_z"] + cam_frame["max_z"]) / 2.0
	frame_camera_at(cam_distance, cx, cz, cam_segment_start, cam_segment_end)

func screen_to_world(direction: String) -> String:
	var r = Vector2(cos(deg_to_rad(cam_yaw)), -sin(deg_to_rad(cam_yaw)))
	var u = Vector2(-sin(deg_to_rad(cam_yaw)), -cos(deg_to_rad(cam_yaw)))
	var v: Vector2
	if direction == "up":
		v = u
	elif direction == "down":
		v = -u
	elif direction == "right":
		v = r
	elif direction == "left":
		v = -r
	else:
		return direction
	if v.y == -1:
		return "up"
	if v.y == 1:
		return "down"
	if v.x == 1:
		return "right"
	return "left"
