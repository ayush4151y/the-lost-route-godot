extends Node3D

func _ready():
	var cam = Camera3D.new()
	cam.name = "Camera"
	cam.fov = 45.0
	cam.position = Vector3(10, 12, 14)
	cam.near = 0.1
	cam.far = 500.0
	add_child(cam)

	var world = Node3D.new()
	world.name = "World"
	add_child(world)

	var ui = Control.new()
	ui.name = "UI"
	ui.set_script(load("res://scripts/ui/ui.gd"))
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ui)

	var game = Node.new()
	game.name = "Game"
	game.set_script(load("res://scripts/game/game_manager.gd"))
	add_child(game)
