extends Node

const enums = preload("res://scripts/enums.gd")

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

export var n_boids = 5
export var boid_scattering_range = 500
export var vel_r = 50

var boid = preload("res://prefabs/boid.tscn")
var cam: Node
var boid_drag_poly: Node

export var faction = enums.FACTION_PLAYER

# Called when the node enters the scene tree for the first time.
func _ready():
	for i in range(n_boids):
		var b = boid.instance()
		b.position = Vector2(rand_range(-boid_scattering_range, boid_scattering_range), rand_range(-boid_scattering_range, boid_scattering_range))
		b.velocity = Vector2(rand_range(-vel_r, vel_r), rand_range(-vel_r, vel_r))
		add_child(b)
	cam = get_node("../camera")
	boid_drag_poly = get_node("../boidpolydragsquare")

func get_boid_center() -> Vector2:
	var boids = get_children()
	if len(boids) == 0:
		return Vector2(0, 0)
	var center = Vector2(0, 0)
	for boid in boids:
		center += boid.position
	center /= len(boids)
	return center

func bound_boids():
	var boids = get_children()
	var mi = get_boid_center()
	var ma = get_boid_center()
	for boid in boids:
		mi.x = min(mi.x, boid.position.x)
		mi.y = min(mi.y, boid.position.y)
		ma.x = max(ma.x, boid.position.x)
		ma.y = max(ma.y, boid.position.y)
	return [mi, ma]
	
func get_boids_bounded(a: Vector2, b: Vector2):
	var left_x = min(a.x, b.x)
	var right_x = max(a.x, b.x)
	
	var bottom_y = min(a.y, b.y)
	var top_y = max(a.y, b.y)
	
	var bs = []
	for boid in get_children():
		if (left_x <= boid.position.x) and (boid.position.x <= right_x) and (bottom_y <= boid.position.y) and (boid.position.y <= top_y):
			bs.append(boid)
	return bs

func set_boid_target(boids, target: Vector2):
	for boid in boids:
		boid.target = target

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	match mouse_input_state:
		MOUSE_IDLE:
			boid_drag_poly.visible = false
		MOUSE_DRAGGING:
			var poly_pieces = PoolVector2Array()
			var mouse_pos = world_mouse_pos()
			var a = mouse_pos
			var b = Vector2(mouse_pos.x, mouse_square_p1.y)
			var c = mouse_square_p1
			var d = Vector2(mouse_square_p1.x, mouse_pos.y)
			boid_drag_poly.get_child(0).points = PoolVector2Array([a, b])
			boid_drag_poly.get_child(1).points = PoolVector2Array([b, c])
			boid_drag_poly.get_child(2).points = PoolVector2Array([c, d])
			boid_drag_poly.get_child(3).points = PoolVector2Array([d, a])
			boid_drag_poly.visible = true
		MOUSE_SELECTING:
			boid_drag_poly.visible = false
			
enum {MOUSE_IDLE, MOUSE_DRAGGING, MOUSE_SELECTING}
var mouse_input_state = MOUSE_IDLE
var mouse_square_p1 = Vector2(0, 0)
var mouse_selected_boids = []

func world_mouse_pos():
	return cam.position + get_viewport().get_mouse_position() - get_viewport().size/2

func _input(event):
	# Mouse in viewport coordinates.
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			match mouse_input_state:
				MOUSE_IDLE:
					if event.pressed:
						mouse_input_state = MOUSE_DRAGGING
						mouse_square_p1 = world_mouse_pos()
				MOUSE_DRAGGING:
					if not event.pressed:
						mouse_selected_boids = get_boids_bounded(mouse_square_p1, world_mouse_pos())
						if len(mouse_selected_boids) == 0:
							mouse_input_state = MOUSE_IDLE
						else:
							mouse_input_state = MOUSE_SELECTING
				MOUSE_SELECTING:
					if event.pressed:
						mouse_input_state = MOUSE_IDLE
						set_boid_target(mouse_selected_boids, world_mouse_pos())
