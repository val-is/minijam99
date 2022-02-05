extends Node


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

export var n_boids = 5
export var boid_scattering_range = 500
export var vel_r = 50

var boid = preload("res://prefabs/boid.tscn")
var cam: Node

# Called when the node enters the scene tree for the first time.
func _ready():
	for i in range(n_boids):
		var b = boid.instance()
		b.position = Vector2(rand_range(-boid_scattering_range, boid_scattering_range), rand_range(-boid_scattering_range, boid_scattering_range))
		b.velocity = Vector2(rand_range(-vel_r, vel_r), rand_range(-vel_r, vel_r))
		add_child(b)
	cam = get_node("../camera")

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

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func _input(event):
	# Mouse in viewport coordinates.
	if event is InputEventMouseButton:
		for boid in get_children():
			boid.target = cam.position + get_viewport().get_mouse_position() - get_viewport().size/2


