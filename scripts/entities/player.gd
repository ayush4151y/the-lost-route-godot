extends Node3D
# Player - grid-locked hop movement, facing, hearts, ice-slide and fire-burn state.
# No physics/jump: movement is tweened cell hops exactly like the original.

signal hop_finished
signal moved_off(off_cell: Vector2i)

const CubeFactory = preload("res://scripts/world/cube_factory.gd")

var max_health := 3
var health := 3
var holding_cell := Vector2i.ZERO
var is_moving := false
var dead := false

# ice slide
var slide_timer := 0.0
var slide_dir := Vector2i.ZERO
var sliding := false
const SLIDE_TIME := 2.0

# fire
var standing_on_fire := false
var fire_budget := 3.0
const FIRE_BUDGET := 3.0

var _body: MeshInstance3D
var _parent: Node3D

func setup(parent: Node3D, start_cell: Vector2i) -> void:
	_parent = parent
	holding_cell = start_cell
	position = _cell_to_vec(start_cell) + Vector3(0, 1.0, 0)
	health = 3
	_build_body()

func _build_body() -> void:
	_body = CubeFactory.new().build_player_body()
	add_child(_body)

func _cell_to_vec(c: Vector2i) -> Vector3:
	return Vector3(c.x, 0, c.y)

func get_holding_cell() -> Vector2i:
	return holding_cell

func set_cell(c: Vector2i) -> void:
	holding_cell = c
	position = _cell_to_vec(c) + Vector3(0, 1.0, 0)

# Face the travel direction (yaw) and hop to an absolute cell.
func hop_to(cell: Vector2i) -> void:
	if is_moving or dead:
		return
	is_moving = true
	facing(cell)
	var from := _cell_to_vec(holding_cell) + Vector3(0, 1.0, 0)
	var target := _cell_to_vec(cell) + Vector3(0, 1.0, 0)
	holding_cell = cell
	var tween := create_tween()
	tween.tween_method(_hop_step.bind(from, target), 0.0, 1.0, 0.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		is_moving = false
		hop_finished.emit()
	)


func _hop_step(p: float, from: Vector3, target: Vector3) -> void:
	var arc_h := 0.3 * sin(p * PI)
	position = from.lerp(target, p) + Vector3(0, arc_h, 0)

func facing(cell: Vector2i) -> void:
	var delta := cell - holding_cell
	if delta.x != 0 or delta.y != 0:
		rotation_degrees.y = rad_to_deg(atan2(delta.x, delta.y))

func set_fire(active: bool) -> void:
	standing_on_fire = active

func set_slide(active: bool, dir: Vector2i) -> void:
	sliding = active
	slide_dir = dir
	slide_timer = SLIDE_TIME
	if not active:
		slide_timer = 0.0

# returns true if slide timer expired (game over condition)
func update_fire_slide(delta: float) -> void:
	if sliding and not is_moving and not dead:
		slide_timer -= delta
	if standing_on_fire and not dead:
		fire_budget -= delta
		if fire_budget <= 0.0:
			fire_budget = FIRE_BUDGET
			lose_health(1)

func lose_health(n: int) -> void:
	health -= n
	if health <= 0:
		health = 0
		dead = true

func gain_health() -> void:
	health = min(health + 1, max_health)

func reset_burn_on_move() -> void:
	standing_on_fire = false

func reset() -> void:
	dead = false
	is_moving = false
	sliding = false
	slide_timer = 0.0
	standing_on_fire = false
	fire_budget = FIRE_BUDGET
	health = max_health
