extends Node
class_name PlayerManager

var build_trench_order_scene = preload("res://scenes/build_trench_order.tscn")
var clearing_order_scene = preload("res://scenes/clearing_order.tscn")

@onready var building_grid = InputManager.building_grid

enum Side {PLAYER, ENEMY}
@export var side = Side.PLAYER

# Each dictionary is a set for which build orders have which numbers of soldiers assigned to them
var build_order_rally_points:Array[Dictionary] = [{},{},{}]
var build_trench_order_location_lookup:Dictionary = {}
var clearing_order_rally_points:Array[Dictionary] = [{},{},{}]
var clearing_order_location_lookup:Dictionary = {}
var idle_soldiers_lookup:Dictionary = {}
var _update_assignments_this_frame:bool = true

func _physics_process(_delta):
	if _update_assignments_this_frame:
		update_order_assignments()
		_update_assignments_this_frame = false

func _on_build_order_removed(build_order:BuildOrder):
	#Remove order from trench order location lookup table if applicable
	if build_order is BuildTrenchOrder:
		build_trench_order_location_lookup.erase(build_order.hex_positions)
		build_trench_order_location_lookup.erase([build_order.hex_positions[1], build_order.hex_positions[0]])

func _on_clearing_order_removed(clearing_order:ClearingOrder):
	#Remove order from clearing order location lookup table
	clearing_order_location_lookup.erase([clearing_order.hex_position, clearing_order.target_direction])

func _on_rally_point_removed(rally_point:RallyPoint):
	#Remove rally point from build order rally points if applicable
	if rally_point.get_parent() is BuildOrder:
		for i in range(0,2):
			build_order_rally_points[i].erase(rally_point)
	#Clear rally point from clearing order rally points if applicable
	if rally_point.get_parent() is ClearingOrder:
		for i in range(0,2):
			clearing_order_rally_points[i].erase(rally_point)
	_update_assignments_this_frame = true

func _on_idle_soldier_enter_hex(soldier:Soldier, hex_position:Vector2i):
	var new_list = []
	if idle_soldiers_lookup.has(hex_position):
		new_list = idle_soldiers_lookup[hex_position]
	new_list.append(soldier)
	idle_soldiers_lookup[hex_position] = new_list
	_update_assignments_this_frame = true

func _on_idle_soldier_leave_hex(soldier:Soldier, hex_position:Vector2i):
	if not idle_soldiers_lookup.has(hex_position):
		return
	var new_list = idle_soldiers_lookup[hex_position]
	new_list.erase(soldier)
	_update_assignments_this_frame = true

func _on_trench_ownership_updated():
	for hex_position in building_grid.get_used_cells(building_grid.REAL_LAYER_INDEX):
		if _valid_clearing_origin_hex(hex_position):
			for neighbor_position in building_grid.get_adjacent_trench_hex_positions(hex_position):
				if _valid_clearing_target_hex(neighbor_position):
					create_clearing_trench_order([hex_position, neighbor_position-hex_position])
	for location in clearing_order_location_lookup:
		if not _valid_clearing_origin_hex(location[0]) or not _valid_clearing_target_hex(location[0]+location[1]):
			clearing_order_location_lookup[location]._remove_order()

func _valid_clearing_origin_hex(hex_position:Vector2i):
	return ( \
		( \
			side == Side.PLAYER and building_grid.enemy_vision_count[hex_position] == 0 and \
			( \
				building_grid.player_soldier_count[hex_position] != 0 or \
				building_grid.player_owned_hexes.has(hex_position) \
			) \
		) \
		or \
		( \
			side == Side.ENEMY and building_grid.player_vision_count[hex_position] == 0 and \
			( \
				building_grid.enemy_soldier_count[hex_position] != 0 or \
			 	building_grid.enemy_owned_hexes.has(hex_position) \
			) \
		) \
	)

func _valid_clearing_target_hex(target_hex:Vector2i):
	return ( \
		( \
			side == Side.PLAYER and \
			( \
				building_grid.enemy_vision_count[target_hex] != 0 or \
				( \
					building_grid.player_soldier_count[target_hex] == 0 and \
					not building_grid.player_owned_hexes.has(target_hex) \
				) \
			) \
		) \
		or 
		( \
			side == Side.ENEMY and \
			( \
				building_grid.player_vision_count[target_hex] != 0 or \
				( \
					building_grid.enemy_soldier_count[target_hex] == 0 and \
					not building_grid.enemy_owned_hexes.has(target_hex) \
				) \
			) \
		) \
	)

# Returns true if position has only a single soldier guarding multiple contested paths
func _guarding_chokepoint(hex_position:Vector2i):
	return ( \
		_contested_paths_from_hex(hex_position) >= 2 and \
		( \
			( \
				side == Side.PLAYER and \
				building_grid.player_soldier_count[hex_position] == 1 \
			) \
			or \
			( \
				side == Side.ENEMY and \
				building_grid.enemy_soldier_count[hex_position] == 1 \
			) \
		) \
	)

# Return number of contested paths leading away from hex that would spread to this hex if the last allied soldier were to leave in a different direction
func _contested_paths_from_hex(hex_position:Vector2i):
	var count = 0
	for neighbor_hex in building_grid.get_adjacent_trench_hex_positions(hex_position):
		if 	not building_grid.player_owned_hexes.has(neighbor_hex) and \
			not building_grid.enemy_owned_hexes.has(neighbor_hex) and \
			( \
				(side == Side.PLAYER and building_grid.player_soldier_count[neighbor_hex] == 0) or \
				(side == Side.ENEMY and building_grid.enemy_soldier_count[neighbor_hex] == 0)
			):
			count += 1
	return count

func create_build_trench_order(trench_position:Array):
	if build_trench_order_location_lookup.has(trench_position):
		return
	var build_trench_order = build_trench_order_scene.instantiate()
	build_trench_order.hex_positions = [trench_position[0], trench_position[1]]
	add_child(build_trench_order)
	build_trench_order.order_removed.connect(_on_build_order_removed)
	for rally_point in build_trench_order.rally_points:
		rally_point.rally_point_removed.connect(_on_rally_point_removed)
		build_order_rally_points[0][rally_point] = null
	build_trench_order_location_lookup[[trench_position[0], trench_position[1]]] = build_trench_order
	build_trench_order_location_lookup[[trench_position[1], trench_position[0]]] = build_trench_order
	_update_assignments_this_frame = true

func create_clearing_trench_order(trench_position:Array):
	if clearing_order_location_lookup.has(trench_position):
		return
	var clearing_order = clearing_order_scene.instantiate()
	clearing_order.hex_position = trench_position[0]
	clearing_order.target_direction = trench_position[1]
	add_child(clearing_order)
	clearing_order.order_removed.connect(_on_clearing_order_removed)
	clearing_order.rally_points[0].rally_point_removed.connect(_on_rally_point_removed)
	clearing_order_rally_points[0][clearing_order.rally_points[0]] = null
	clearing_order_location_lookup[trench_position] = clearing_order
	_update_assignments_this_frame = true

func get_build_trench_order_by_location(hex_position_a:Vector2i, hex_position_b:Vector2i):
	if build_trench_order_location_lookup.has([hex_position_a, hex_position_b]):
		return build_trench_order_location_lookup[[hex_position_a, hex_position_b]]

#TODO: order priority system based on type of order, and how many soldiers are assigned
# e.g. the second soldier of an order is lower priority than the first,
# clearing orders are higher than most other orders but prioritizes pulling soldiers
# from lower priority orders/soldiers
func update_order_assignments():
	# Trench clearing orders
	var available_soldiers = []
	for hex_position in idle_soldiers_lookup.keys():
		if _contested_paths_from_hex(hex_position) <= 1:
			available_soldiers.append_array(idle_soldiers_lookup[hex_position])
		else:
			var new_list = idle_soldiers_lookup[hex_position].duplicate()
			new_list.pop_back()
			available_soldiers.append_array(new_list)
	# Use soldiers from build orders if necessary
	for j in range(0,2):
		for rally_point in build_order_rally_points[j]:
			available_soldiers.append_array(rally_point.assigned_soldiers)
	# Assign minimum soldiers to trench clearing orders
	for i in range(0,1):
		while not available_soldiers.is_empty():
			var soldier = available_soldiers.pop_back()
			#Naive algorithm, perhaps better if custom dijkstra algorithm stops at first rally point it finds with proper number of unassigned slots remaining
			var shortest_distance = INF
			var closest_rally_point = null
			for rally_point in clearing_order_rally_points[i].keys():
				var path = NavigationServer2D.map_get_path(InputManager.building_grid.get_world_2d().get_navigation_map(), soldier.position, rally_point.position, false)
				if path.size() < 1 or path[path.size()-1] != rally_point.position:
					continue
				var previous = path[0]
				var distance_so_far = 0
				for j in range(1, path.size()):
					distance_so_far += previous.distance_to(path[j])
					previous = path[j]
					if distance_so_far > shortest_distance:
						break
				if distance_so_far < shortest_distance:
					shortest_distance = distance_so_far
					closest_rally_point = rally_point
			if closest_rally_point == null:
				continue
			# Update prior rally point data if applicable
			var prior_rally_point = soldier.current_rally_point
			if prior_rally_point != null and prior_rally_point.get_parent() is BuildOrder:
				var assigned_soldier_count = prior_rally_point.assigned_soldiers.size()
				build_order_rally_points[assigned_soldier_count].erase(prior_rally_point)
				build_order_rally_points[assigned_soldier_count-1][prior_rally_point] = null
			# Assign soldier to new rally point
			soldier.set_rally_point(closest_rally_point)
			clearing_order_rally_points[i].erase(closest_rally_point)
			clearing_order_rally_points[i+1][closest_rally_point] = null
	# Build orders
	available_soldiers = []
	for hex_position in idle_soldiers_lookup.keys():
		if _contested_paths_from_hex(hex_position) <= 1:
			available_soldiers.append_array(idle_soldiers_lookup[hex_position])
		else:
			var new_list = idle_soldiers_lookup[hex_position].duplicate()
			new_list.pop_back()
			available_soldiers.append_array(new_list)
	# Assign remaining idle soldiers to build orders
	for i in range(0,2):
		while not available_soldiers.is_empty():
			var soldier = available_soldiers.pop_back()
			if _guarding_chokepoint(building_grid.local_to_map(soldier.position)):
				continue
			#Naive algorithm, perhaps better if custom dijkstra algorithm stops at first rally point it finds with proper number of unassigned slots remaining
			var shortest_distance = INF
			var closest_rally_point = null
			for rally_point in build_order_rally_points[i].keys():
				var path = NavigationServer2D.map_get_path(InputManager.building_grid.get_world_2d().get_navigation_map(), soldier.position, rally_point.position, false)
				if path.size() < 1 or path[path.size()-1] != rally_point.position:
					continue
				var previous = path[0]
				var distance_so_far = 0
				for j in range(1, path.size()):
					distance_so_far += previous.distance_to(path[j])
					previous = path[j]
					if distance_so_far > shortest_distance:
						break
				if distance_so_far < shortest_distance:
					shortest_distance = distance_so_far
					closest_rally_point = rally_point
			if closest_rally_point == null:
				continue
			soldier.set_rally_point(closest_rally_point)
			build_order_rally_points[i].erase(closest_rally_point)
			build_order_rally_points[i+1][closest_rally_point] = null
