extends Node2D

const enums = preload("res://scripts/enums.gd")

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

export var capture_radius = 50

export var healthbar_len = 75
export var healthbar_height = 5


var controller = enums.FACTION_NEUTRAL
export var max_health = 20
var health = max_health
export var heal_rate = 1

export var boid_spawn_delay = 10

var boid = preload("res://prefabs/boid.tscn")

var faction_colors = {
	enums.FACTION_NEUTRAL: Color(1,1,1,0.1),
	enums.FACTION_PLAYER: Color(0,1,0,0.1),
	enums.FACTION_ENEMY: Color(1,0,0,0.1)
}

var _timer = null
var _spawn_timer = null
var boid_control_player: Node
var boid_control_enemy: Node

var cam: Camera2D

func _ready():
	_timer = Timer.new()
	add_child(_timer)
	_timer.connect("timeout", self, "update_cap_point")
	_timer.set_wait_time(1.0)
	_timer.set_one_shot(false) # Make sure it loops
	_timer.start()
	
	_spawn_timer = Timer.new()
	add_child(_spawn_timer)
	_spawn_timer.connect("timeout", self, "attempt_spawn")
	_spawn_timer.set_wait_time(boid_spawn_delay)
	_spawn_timer.set_one_shot(false) # Make sure it loops
	
	boid_control_player = get_node("../../boidcontrol-player")
	boid_control_enemy = get_node("../../boidcontrol-enemy")
	cam = get_node("../../camera")

func update_cap_point():
	var p_boid_count = 0
	var e_boid_count = 0
	
	for p_boid in boid_control_player.get_children():
		if position.distance_to(p_boid.position) < capture_radius:
			p_boid_count += 1
	
	for e_boid in boid_control_enemy.get_children():
		if position.distance_to(e_boid.position) < capture_radius:
			e_boid_count += 1
	
	var contested = ((controller != enums.FACTION_PLAYER and p_boid_count != 0) or
					(controller != enums.FACTION_ENEMY and e_boid_count != 0))
	var active_fighting = (p_boid_count != 0) and (e_boid_count != 0)
	
	if not contested and health != max_health:
		health += heal_rate
	elif contested and not active_fighting:
		health -= e_boid_count + p_boid_count
		if health <= 0:
			_spawn_timer.stop()
			if e_boid_count > 0:
				controller = enums.FACTION_ENEMY
				_spawn_timer.start()
			elif p_boid_count > 0:
				controller = enums.FACTION_PLAYER
				_spawn_timer.start()
	health = clamp(health, 0, max_health)
	update()
	
func attempt_spawn():
	var b = boid.instance()
	b.position = position
	b.faction = controller
	# b.target = position
	match controller:
		enums.FACTION_ENEMY:
			boid_control_enemy.add_child(b)
		enums.FACTION_PLAYER:
			boid_control_player.add_child(b)

func _draw():
	draw_circle(Vector2(0, 0), capture_radius, faction_colors[controller])
	draw_circle(Vector2(0, 0), 3, Color.red)
	var health_pct = float(health) / float(max_health)
	var bar_len = health_pct * float(healthbar_len)
	draw_rect(Rect2(Vector2(-healthbar_len/2, capture_radius+healthbar_height*0.1),
					Vector2(healthbar_len, healthbar_height)), Color.white, false)
	
	draw_rect(Rect2(Vector2(-healthbar_len/2, capture_radius+healthbar_height*0.1),
					Vector2(bar_len, healthbar_height)), Color.white, true)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
