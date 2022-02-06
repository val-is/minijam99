extends Node2D

const enums = preload("res://scripts/enums.gd")

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

export var boid_radius = 200

export var boid_r1_separation = 50

export var boid_r2_cohesion = 1
export var boid_r2_target_dist = 0.001

export var boid_r3_alignment = 0.05

export var boid_target_bias = 20
export var boid_target_r2_dist_bias = 0.1

export var boid_max_vel = 100

var target = Vector2(0, 0)

var boid_root: Node
var velocity = Vector2(0, 0)

export var view_angle = 50
export var view_dist = 100

export var personality_range: Vector2 = Vector2(0.7, 1.2)
var personality = 1

export var max_dtheta = 3.141 / 60

export var faction = enums.FACTION_NEUTRAL

# Called when the node enters the scene tree for the first time.
func _ready():
	boid_root = get_node("..")
	target = position + Vector2(0.01, 0.01)
	personality = rand_range(personality_range.x, personality_range.y)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if target == position:
		target += Vector2(0.1, 0.1)
	var old_vel = velocity
	
	var boids_raw = boid_root.get_children()
	var boids = []
	for boid in boids_raw:
		if boid == self:
			continue
		if boid.faction != faction:
			continue
		
		if position.distance_to(boid.position) <= boid_radius:
			boids.append(boid)
	
	# rule 1
	var centroid = Vector2(0, 0)
	for buddy in boids:
		centroid += buddy.position
	if len(boids) == 0:
		centroid = position
	else:
		centroid /= len(boids)
	var delta_centroid = centroid - position
	velocity += delta_centroid * delta * boid_r1_separation
	
	# rule 2
	var delta_v = Vector2(0, 0)
	for buddy in boids:
		var dist = position.distance_to(buddy.position)
		delta_v -= (buddy.position - position) * boid_r2_cohesion / (dist / boid_r2_target_dist)
	velocity += delta_v
	
	# rule 3
	delta_v = Vector2(0, 0)
	for buddy in boids:
		delta_v += buddy.velocity
	if len(boids) > 0:
		delta_v /= len(boids)
		delta_v -= velocity
		velocity += delta_v * boid_r3_alignment
		
	# rule 1 w/ target
	velocity += (target - position) * delta * boid_r1_separation * boid_target_bias
	# rule 2 w/ target
	velocity += -((target-position) * boid_r2_cohesion / ((target-position).length() / boid_target_r2_dist_bias)) * boid_target_bias
	
	if velocity.length() > boid_max_vel:
		velocity = velocity.normalized() * boid_max_vel
	
	# rotate towards target velocity
	var new_speed = velocity.length()
	new_speed = clamp(new_speed, 0.1*boid_max_vel, boid_max_vel)
	
	var new_orientation = velocity.normalized().angle()
	var old_orientation = old_vel.normalized().angle()
	
	var d_theta = new_orientation - old_orientation
	d_theta = clamp(d_theta, -max_dtheta, max_dtheta)
	velocity = Vector2(1, 0).rotated(old_orientation + d_theta) * new_speed
	
	# apply velocity
	position += velocity * delta * personality
	
	# rotate towards front
	var orientation = velocity.normalized().angle()
	rotation = orientation + 3.141 / 2
	
	update()

func draw_circle_arc(center, radius, angle_from, angle_to, color):
	var nb_points = 15
	var points_arc = PoolVector2Array()

	for i in range(nb_points + 1):
		var angle_point = deg2rad(angle_from + i * (angle_to-angle_from) / nb_points - 90)
		points_arc.push_back(center + Vector2(cos(angle_point), sin(angle_point)) * radius)

	for index_point in range(nb_points):
		draw_line(points_arc[index_point], points_arc[index_point + 1], color)

func _draw():
	draw_circle_arc(Vector2(0, 0), view_dist+50, -view_angle/2, view_angle/2, Color.red)
