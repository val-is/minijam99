extends Node

const enums = preload("res://scripts/enums.gd")

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

export var spawn_point = Vector2(400, 0)
export var n_boids = 5
export var boid_scattering_range = 50
export var vel_r = 50

export var AI_resupply_distance = 500 # join resupplying groups w/in this range

var boid = preload("res://prefabs/boid.tscn")

export var faction = enums.FACTION_ENEMY

var ai_timer = null

# Called when the node enters the scene tree for the first time.
func _ready():
	for i in range(n_boids):
		var b = boid.instance()
		b.position = spawn_point + Vector2(rand_range(-boid_scattering_range, boid_scattering_range), rand_range(-boid_scattering_range, boid_scattering_range))
		b.velocity = Vector2(rand_range(-vel_r, vel_r), rand_range(-vel_r, vel_r))
		b.faction = faction
		add_child(b)
	
	ai_timer = Timer.new()
	get_node("../boidcontrol-enemy-extra").add_child(ai_timer)
	ai_timer.connect("timeout", self, "process_ai")
	ai_timer.set_wait_time(1.0)
	ai_timer.set_one_shot(false) # Make sure it loops
	ai_timer.start()

# shitty ai time :)
# overall, this should operate using "strike groups"
# field a group of nearby boids and send them on missions
# if there aren't enough boids for a mission, expand the group

export var boid_grouping_distance = 100

export var ai_resupply_target_capacity = 3
export var ai_group_dist = 50 # make sure units stay in this radius if in a strike group when resupplying

export var ai_defend_range = 100 # radius around a captured point to keep clear

export var ai_intercept_grouping_range = 200 # use this radius to create groups of player troops to intercept

enum {
	MISSION_RESUPPLY,	# heal up to a target # of troops and make sure they're close together
	MISSION_DEFEND,		# go to a specific capture point and park there until no more enemies are targeting nearby
	MISSION_INTERCEPT,	# chase/engage with a group of enemy boids (follow their center)
	MISSION_CAPTURE		# capture an arbitrary point (at a target), prioritize neutral
}

var strike_groups = [] # strike group schema: {boids: [], mission: enum, target: Vec2 or []}

# Called every frame. 'delta' is the elapsed time since the previous frame.
# func _process(delta):
	# pass

class AIGroupSorter:
	static func sort_by_distance(a, b):
		# if a < b: return true
		if a[0] < b[0]:
			return true
		return false

func reassign_group(idx):
	var group = strike_groups[idx]
	var friendly_cap_points = []
	for point in get_node("../capturepoints").get_children():
		if point.controller == enums.FACTION_ENEMY:
			friendly_cap_points.append(point)
	
	# resupply if needed
	if len(group["boids"]) < ai_resupply_target_capacity:
		var friendly_dist_points = []
		for point in friendly_cap_points:
			friendly_dist_points.append([group["center"].distance_to(point.position), point])
		friendly_dist_points.sort_custom(AIGroupSorter, "sort_by_distance")
		strike_groups[idx]["mission"] = MISSION_RESUPPLY
		if len(friendly_dist_points) != 0:
			strike_groups[idx]["target"] = friendly_dist_points[0][1].position
			return
		else:
			strike_groups[idx]["target"] = group["center"]
			return
		
	# see if we need to defend any of our stuff
	var threatened_points = []
	for cap_point in friendly_cap_points:
		var threat_level = 0
		for player_boid in get_node("../boidcontrol-player").get_children():
			if player_boid.position.distance_to(cap_point.position) < ai_defend_range:
				threat_level += 1
		for group_other in strike_groups:
			if group_other != group and group_other["mission"] == MISSION_DEFEND and group_other["defend_target"] == cap_point:
				threat_level -= len(group_other["boids"])
		if threat_level > 0:
			threatened_points.append([threat_level, cap_point])
	threatened_points.sort_custom(AIGroupSorter, "sort_by_distance")
	threatened_points.invert() # go to most aggressed point
	if len(threatened_points) != 0:
		print("defending!")
		strike_groups[idx]["mission"] = MISSION_DEFEND
		strike_groups[idx]["target"] = threatened_points[0][1].position
		strike_groups[idx]["defend_target"] = threatened_points[0][1]
		return
				
	# find neutral cap points, try to grab
	var neutral_cap_points = []
	for point in get_node("../capturepoints").get_children():
		if point.controller == enums.FACTION_NEUTRAL:
			neutral_cap_points.append([group["center"].distance_to(point.position), point])
	neutral_cap_points.sort_custom(AIGroupSorter, "sort_by_distance")
	if len(neutral_cap_points) != 0:
		strike_groups[idx]["mission"] = MISSION_CAPTURE
		strike_groups[idx]["target"] = neutral_cap_points[0][1].position
		strike_groups[idx]["capture_target"] = neutral_cap_points[0][1]
		return
	
	# try to harass player groups
	var unassigned_player_boids = get_node("../boidcontrol-player").get_children()
	var player_groups = []
	# get 1st attempt at groups
	for player_boid in unassigned_player_boids:
		var added = false
		for player_group in player_groups:
			if added:
				break
			for other_boid in player_group:
				if other_boid.position.distance_to(player_boid.position) < ai_intercept_grouping_range:
					player_group.append(other_boid)
					added = true
					break
		if not added:
			player_groups.append([player_boid])
	# combine groups that are close enough to each other, as long as it's possible
	var updated_groups = true
	while updated_groups:
		updated_groups = false
		for group_a in player_groups:
			for group_b in player_groups:
				if group_a == group_b:
					continue
				for boid_a in group_a:
					for boid_b in group_b:
						if boid_a.position.distance_to(boid_b.position) < ai_intercept_grouping_range:
							# combine groups
							while len(group_b) > 0:
								group_a.append(group_b[0])
								group_b.remove(0)
								updated_groups = true
								continue
	# remove empty groups
	var empty_groups = []
	for i in range(len(player_groups)):
		if len(player_groups[i]) == 0:
			empty_groups.append(i)
	empty_groups.sort()
	empty_groups.invert()
	for i in empty_groups:
		player_groups.remove(i)
	# find closest group in strength that weaker than us to attack
	var player_group_strengths = []
	for pl_group in player_groups:
		if len(pl_group) > len(group["boids"]):
			continue
		player_group_strengths.append([len(pl_group), pl_group])
	player_group_strengths.sort_custom(AIGroupSorter, "sort_by_distance")
	player_group_strengths.invert()
	if len(player_group_strengths) != 0:
		# attack the first group here
		strike_groups[idx]["mission"] = MISSION_INTERCEPT
		strike_groups[idx]["target"] = player_group_strengths[0][1][0].position
		return
	
	# see if we can attack any player nodes
	# TODO
	
	# group up with a resupply to bolster strength
	var closest_groups = []
	for group_other in strike_groups:
		if group_other["mission"] == MISSION_RESUPPLY:
			if group == group_other:
				continue
			closest_groups.append([group["target"].distance_to(group_other["target"]), group_other])
	closest_groups.sort_custom(AIGroupSorter, "sort_by_distance")
	if len(closest_groups) != 0:
		while len(group["boids"]) > 0:
			closest_groups[0][1]["boids"].append(group["boids"][0])
			group["boids"].remove(0)
		return
	
	# otherwise just return to the closest capture point and resupply
	strike_groups[idx]["mission"] = MISSION_RESUPPLY
	if len(friendly_cap_points) != 0:
		var closest_bases = []
		for cap in friendly_cap_points:
			closest_bases.append([group["center"].distance_to(cap.position), cap])
		closest_bases.sort_custom(AIGroupSorter, "sort_by_distance")
		strike_groups[idx]["center"] = closest_bases[0][1].position
	else:
		strike_groups[idx]["center"] = group["center"]
	
		
func process_ai():
	var captured_points = []
	for point in get_node("../capturepoints").get_children():
		if point.controller != enums.FACTION_ENEMY:
			continue
		captured_points.append(point)
	
	var dead_groups = []
	for i in range(len(strike_groups)):
		var group = strike_groups[i]
		if len(group["boids"]) == 0:
			# dead group. disband
			dead_groups.append(i)
	dead_groups.sort()
	dead_groups.invert()
	for i in dead_groups:
		strike_groups.remove(i)
	
	var grouped_boids = []
	for group_idx in range(len(strike_groups)):
		var group = strike_groups[group_idx]
		var group_center = Vector2(0, 0)
		for boid in group["boids"]:
			grouped_boids.append(boid)
			group_center += boid.position
		group_center /= len(group["boids"])
		strike_groups[group_idx]["center"] = group_center
	
	var all_boids = get_children()
	var ungrouped_boids = []
	for boid in all_boids:
		if not (boid in grouped_boids):
			ungrouped_boids.append(boid)
	
	# if we're completely dead, give up
	if len(ungrouped_boids) + len(grouped_boids) == 0:
		return
	
	# every boid gets a group
	for boid in ungrouped_boids:
		# first see if there are any nearby resupplying groups to join
		var resupply_groups_distanced = []
		for group_idx in range(len(strike_groups)):
			var group = strike_groups[group_idx]
			if group["mission"] == MISSION_RESUPPLY:
				var dist = boid.position.distance_to(group["center"])
				if dist > AI_resupply_distance:
					continue
				resupply_groups_distanced.append([dist, group_idx])
		resupply_groups_distanced.sort_custom(AIGroupSorter, "sort_by_distance")
		if len(resupply_groups_distanced) != 0:
			# join the nearest resupplying group
			strike_groups[resupply_groups_distanced[0][1]]["boids"].append(boid)
			continue
		
		# if there are no nearby groups resupplying, form a new group
		# this new group will then go to a nearby captured point to recruit
		var new_group = {
			"boids": [boid],
			"mission": MISSION_RESUPPLY,
			"target": Vector2(boid.position),
			"center": Vector2(boid.position)
		}
		
		var nearest_cap_points = []
		for cap_point in captured_points:
			var dist = new_group["target"].distance_to(cap_point.position)
			nearest_cap_points.append([dist, cap_point])
		nearest_cap_points.sort_custom(AIGroupSorter, "sort_by_distance")
		if len(nearest_cap_points) != 0:
			# send the new group to the closest cap point
			new_group["target"] = nearest_cap_points[0][1].position	
			strike_groups.append(new_group)
			continue
		
		# if we get here, we're kind of screwed and need this new group to capture a point to keep playing
		# we'll just resupply at the current boid for now in this case. make sure to add all boids to the group
		for other_boid in ungrouped_boids:
			if boid == other_boid:
				continue
			new_group["boids"].append(other_boid)
		strike_groups.append(new_group)
		break
		
	# find player troops to evaluate things
	var player_boids = []
	for boid in get_node("../boidcontrol-player").get_children():
		player_boids.append(boid)
	
	# now that we have all groups existing, do operations on them
	# figure out what groups have finished their previous operation
	var groups_needing_assignment = []
	for group_idx in range(len(strike_groups)):
		var group = strike_groups[group_idx]
		match group["mission"]:
			MISSION_DEFEND:
				# done defending if no player troops w/in range
				var attacking_boids = 0
				for player_boid in get_node("../boidcontrol-player").get_children():
					if player_boid.position.distance_to(group["defend_target"].position) < ai_defend_range:
						attacking_boids += 1
				if attacking_boids >= 1:
					continue
			MISSION_CAPTURE:
				# done capturing if we control the capture point
				if group["capture_target"].controller != enums.FACTION_ENEMY:
					continue
			MISSION_INTERCEPT:
				# done intercepting if no player boids in area
				var attacking_boids = 0
				for player_boid in get_node("../boidcontrol-player").get_children():
					if player_boid.position.distance_to(group["center"]) < ai_defend_range:
						attacking_boids += 1
				if attacking_boids >= 1:
					continue
			MISSION_RESUPPLY:
				# done resupplying when we get to cap. find/apply new mission
				if len(group["boids"]) < ai_resupply_target_capacity:
					continue
		reassign_group(group_idx)
	
	# TODO more ai code
	
	# special case where we have no captured points. pick one nearest to center of all groups and attack with everything
	if len(captured_points) == 0:
		var all_capture_points = []
		for point in get_node("../capturepoints").get_children():
			all_capture_points.append(point)
		
		var boid_center = Vector2(0, 0)
		all_boids = get_children()
		for boid in all_boids:
			boid_center += boid.position
		boid_center /= len(all_boids)
		
		var capture_distances = []
		for idx in range(len(all_capture_points)):
			capture_distances.append([boid_center.distance_to(all_capture_points[idx].position), idx])
		capture_distances.sort_custom(AIGroupSorter, "sort_by_distance")
		for group_idx in range(len(strike_groups)):
			strike_groups[group_idx]["mission"] = MISSION_CAPTURE
			strike_groups[group_idx]["target"] = all_capture_points[capture_distances[0][1]].position
			strike_groups[group_idx]["capture_target"] = all_capture_points[capture_distances[0][1]]
		
	# apply logic to boid underlings
	for group in strike_groups:
		print(len(group["boids"]))
		for boid in group["boids"]:
			boid.target = group["target"]
