extends Node2D

const enums = preload("res://scripts/enums.gd")

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

export var boid_radius = 50

export var boid_r1_separation = 20

export var boid_r2_cohesion = 1
export var boid_r2_target_dist = 0.001

export var boid_r3_alignment = 0.05

export var boid_target_bias = 20
export var boid_target_r2_dist_bias = 0.1

export var boid_max_vel = 100

var target = Vector2(0, 0)

var advanced_ai: bool = false

var boid_root: Node
var velocity = Vector2(0, 0)

export var view_angle = 45
export var view_dist = 70

export var personality_range: Vector2 = Vector2(0.7, 1.2)
var personality = 1

export var max_dtheta = 3.141 / 60

export var faction = enums.FACTION_NEUTRAL

# Called when the node enters the scene tree for the first time.
func _ready():
	boid_root = get_node("..")
	target = position + Vector2(0.01, 0.01)
	if faction == enums.FACTION_ENEMY:
		advanced_ai = true
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
	
	if advanced_ai:
		var enemy_boids
		var enemies_in_range = []
		var enemies_im_shooting = []
		var enemies_shooting_me = []
		match faction:
			enums.FACTION_PLAYER:
				enemy_boids = get_node("../../boidcontrol-enemy").get_children()
			enums.FACTION_ENEMY:
				enemy_boids = get_node("../../boidcontrol-player").get_children()
		for enemy in enemy_boids:
			if position.distance_to(enemy.position) < view_dist:
				enemies_in_range.append(enemy)
				
				var enemy_angle = position.angle_to_point(enemy.position)
				var rot_deg = int(rotation_degrees + 90) % 360
				if rot_deg > 180:
					rot_deg -= 360
				var d_theta_enemy = rot_deg - enemy_angle/3.141*180
				if -view_angle <= d_theta_enemy and d_theta_enemy <= view_angle:
					enemies_im_shooting.append(enemy)
				
				var anti_enemy_angle = enemy.position.angle_to_point(position)
				var anti_rot_deg = int(enemy.rotation_degrees + 90) % 360
				if anti_rot_deg > 180:
					anti_rot_deg -= 360
				var anti_d_theta_enemy = anti_rot_deg - anti_enemy_angle/3.141*180
				if -view_angle <= anti_d_theta_enemy and anti_d_theta_enemy <= view_angle:
					enemies_shooting_me.append(enemy)
		if len(enemies_in_range) > 0:
			if len(enemies_shooting_me) > len(enemies_im_shooting):
				# evade!
				velocity = Vector2(1, 0).rotated(old_orientation + max_dtheta) * boid_max_vel

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
	draw_line(Vector2(0, 0), (-position+target).rotated(-rotation), Color.white)
