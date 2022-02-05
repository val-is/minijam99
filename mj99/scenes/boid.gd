extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

export var boid_radius = 1000

export var boid_r1_separation = 0.5

export var boid_r2_cohesion = 0.05
export var boid_r2_target_dist = 15

export var boid_r3_alignment = 0.001

export var boid_target_bias = 10

export var boid_max_vel = 350

var target = Vector2(0, 0)

var boid_root: Node
var velocity = Vector2(0, 0)

# Called when the node enters the scene tree for the first time.
func _ready():
	boid_root = get_node("..")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var boids_raw = boid_root.get_children()
	var boids = []
	for boid in boids_raw:
		if boid == self:
			continue
		
		if self.position.distance_to(boid.position) <= boid_radius:
			boids.append(boid)
	
	# rule 1
	var centroid = Vector2(0, 0)
	for buddy in boids:
		centroid += buddy.position
	if len(boids) == 0:
		centroid = self.position
	else:
		centroid /= len(boids)
	var delta_centroid = centroid - self.position
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
	velocity += (target - self.position) * delta * boid_r1_separation * boid_target_bias
	# rule 2 w/ target
	velocity += -((target-position) * boid_r2_cohesion / ((target-position).length() / boid_r2_target_dist)) * boid_target_bias
	
	if velocity.length() > boid_max_vel:
		velocity = velocity.normalized() * boid_max_vel
	
	# apply velocity
	self.position += velocity * delta
