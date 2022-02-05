extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

export var capture_radius = 20

export var healthbar_len = 100
export var healthbar_height = 20

enum {FACTION_NEUTRAL, FACTION_PLAYER, FACTION_ENEMY}
var controller = FACTION_NEUTRAL
export var max_health = 20
var health = max_health
export var heal_rate = 1

var faction_colors = {
	FACTION_NEUTRAL: Color(1,1,1,0.1),
	FACTION_PLAYER: Color(0,1,0,0.1),
	FACTION_ENEMY: Color(1,0,0,0.1)
}

var _timer = null
var boid_control_player: Node

var cam: Camera2D

func _ready():
	_timer = Timer.new()
	add_child(_timer)

	_timer.connect("timeout", self, "update_cap_point")
	_timer.set_wait_time(1.0)
	_timer.set_one_shot(false) # Make sure it loops
	_timer.start()
	
	boid_control_player = get_node("../../boidcontrol-player")
	cam = get_node("../../camera")

func update_cap_point():
	var p_boid_count = 0
	var e_boid_count = 0
	
	for p_boid in boid_control_player.get_children():
		if position.distance_to(p_boid.position) < capture_radius:
			p_boid_count += 1
	
	var contested = ((controller != FACTION_PLAYER and p_boid_count != 0) or
					(controller != FACTION_ENEMY and e_boid_count != 0))
	var active_fighting = (p_boid_count != 0) and (e_boid_count != 0)
	
	if not contested and health != max_health:
		health += heal_rate
	elif contested and not active_fighting:
		health -= e_boid_count + p_boid_count
		if health <= 0:
			if e_boid_count > 0:
				controller = FACTION_ENEMY
			elif p_boid_count > 0:
				controller = FACTION_PLAYER
	health = clamp(health, 0, max_health)
	update()

func _draw():
	var c_pos = cam.position
	draw_circle(position, capture_radius, faction_colors[controller])
	var health_pct = float(health) / float(max_health)
	var bar_len = health_pct * float(healthbar_len)
	draw_rect(Rect2(Vector2(position.x-healthbar_len/2, position.y+capture_radius+healthbar_height*0.1),
					Vector2(healthbar_len, healthbar_height)), Color.white, false)
	
	draw_rect(Rect2(Vector2(position.x-healthbar_len/2, position.y+capture_radius+healthbar_height*0.1),
					Vector2(bar_len, healthbar_height)), Color.white, true)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
