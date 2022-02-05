extends Camera2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

export var world_center = Vector2(0, 0)

var grid_q1: Sprite
var grid_q2: Sprite
var grid_q3: Sprite
var grid_q4: Sprite

var boid_controller: Node

# Called when the node enters the scene tree for the first time.
func _ready():
	grid_q1 = get_node("../bg/grid-q1")
	grid_q2 = get_node("../bg/grid-q2")
	grid_q3 = get_node("../bg/grid-q3")
	grid_q4 = get_node("../bg/grid-q4")
	
	grid_q1.visible = true
	grid_q2.visible = true
	grid_q3.visible = true
	grid_q4.visible = true
	
	boid_controller = get_node("../boidcontrol-player")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# self.position = boid_controller.get_boid_center()
	var boid_bounds = boid_controller.bound_boids()
	var boid_mi = boid_bounds[0]
	var boid_ma = boid_bounds[1]
	# self.zoom = (boid_ma - boid_mi) / 500
	
	var cam_pos = position
	var world_delta = cam_pos - world_center

	var grid_size = grid_q1.get_rect().size
	var dx = round(world_delta.x / grid_size.x) * grid_size.x
	var dy = round(world_delta.y / grid_size.y) * grid_size.y
	
	grid_q1.position = Vector2(dx+grid_size.x/2, dy+grid_size.y/2)
	grid_q2.position = Vector2(dx-grid_size.x/2, dy+grid_size.y/2)
	grid_q3.position = Vector2(dx-grid_size.x/2, dy-grid_size.y/2)
	grid_q4.position = Vector2(dx+grid_size.x/2, dy-grid_size.y/2)


var mouse_start_pos
var screen_start_position

var dragging = false

func _input(event):
	if event.is_action("drag"):
		if event.is_pressed():
			mouse_start_pos = event.position
			screen_start_position = position
			dragging = true
		else:
			dragging = false
	elif event is InputEventMouseMotion and dragging:
		position = zoom * (mouse_start_pos - event.position) + screen_start_position
