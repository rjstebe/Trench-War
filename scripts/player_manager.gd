extends Node
class_name PlayerManager

var build_trench_order_scene = preload("res://scenes/build_trench_order.tscn")
var clearing_order_scene = preload("res://scenes/clearing_order.tscn")

@export var building_grid:BuildingGrid
@export var soldier_map:SoldierMap

enum Side {PLAYER, ENEMY}
@export var side = Side.PLAYER

# Priority of orders:
# Manual orders (soldiers are never taken automatically)
# Minimum clearing and supporting logistics (up to 1 soldier per path)
# Expected required clearing and supporting logistics (1.5x equal soldiers to enemy rounded up to a maximum of 3? soldiers per path)
# Man defensive emplacements and supporting logistics (Machine gun, AA gun, etc)
# Defend trench and supporting logisitics (up to 2 soldiers per trench that can "see" enemy trenches or the back edge)
# Man other emplacements and supporting logistics
# Fill supply buffers (sorted by priority then distance)
# Line up/charge orders and logistics
# Construction orders and logistics
# Recover morale
# Idle

var rally_points_by_assignment_priority = []
var rally_point_priority_comparator = func(a,b): return _get_rally_point_assignment_priority(a) > _get_rally_point_assignment_priority(b)

var build_trench_order_location_lookup:Dictionary = {}
var clearing_order_location_lookup:Dictionary = {}

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
	rally_points_by_assignment_priority.erase(rally_point)
	_update_assignments_this_frame = true

func _on_trench_vision_updated():
	for hex_position in building_grid.get_used_cells(building_grid.REAL_LAYER_INDEX):
		if _valid_clearing_origin_hex(hex_position):
			for neighbor_position in building_grid.get_adjacent_trench_hex_positions(hex_position):
				if _valid_clearing_target_hex(neighbor_position):
					create_clearing_trench_order([hex_position, neighbor_position-hex_position])
	for location in clearing_order_location_lookup.keys():
		if not _valid_clearing_origin_hex(location[0]) or not _valid_clearing_target_hex(location[0]+location[1]):
			clearing_order_location_lookup[location]._remove_order()
	_update_assignments_this_frame = true

func _valid_clearing_origin_hex(hex_position:Vector2i):
	for given_side in Side.values():
		if given_side != side and soldier_map.soldier_vision_counts[given_side][hex_position] != 0:
			return false
	return true

func _valid_clearing_target_hex(target_hex:Vector2i):
	for given_side in Side.values():
		if given_side != side and soldier_map.soldier_vision_counts[given_side][target_hex] != 0:
			return true
	return false

func create_build_trench_order(trench_position:Array):
	if build_trench_order_location_lookup.has(trench_position):
		return
	var build_trench_order = build_trench_order_scene.instantiate()
	build_trench_order.hex_positions = [trench_position[0], trench_position[1]]
	add_child(build_trench_order)
	build_trench_order.order_removed.connect(_on_build_order_removed)
	for rally_point in build_trench_order.rally_points:
		rally_point.rally_point_removed.connect(_on_rally_point_removed)
		_insert_rally_point_by_priority(rally_point)
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
	_insert_rally_point_by_priority(clearing_order.rally_points[0])
	clearing_order_location_lookup[trench_position] = clearing_order
	_update_assignments_this_frame = true

#func get_build_trench_order_by_location(hex_position_a:Vector2i, hex_position_b:Vector2i):
	#if build_trench_order_location_lookup.has([hex_position_a, hex_position_b]):
		#return build_trench_order_location_lookup[[hex_position_a, hex_position_b]]

func update_order_assignments():
	rally_points_by_assignment_priority.sort_custom(rally_point_priority_comparator)
	for i in range(0, rally_points_by_assignment_priority.size()):
		var rally_point = rally_points_by_assignment_priority[i]
		var rally_point_priority = _get_rally_point_assignment_priority(rally_point)
		if rally_point_priority <= 0:
			break
		var soldier_hex = building_grid.trench_pathfinding.get_closest_hex_by_trench( \
		building_grid.local_to_map(rally_point.position), \
		func lambda(hex):
			if soldier_map.hex_exists(hex):
				for potential_soldier in soldier_map.trench_occupation[side][hex]:
					if _get_soldier_persistance_priority(potential_soldier) < rally_point_priority:
						return true
			return false,
		func lambda(hex):
			for given_side in Side.values():
				if given_side != side and soldier_map.soldier_vision_counts[given_side][hex] != 0:
					return hex != building_grid.local_to_map(rally_point.position)
			return false
		)
		if soldier_hex != null:
			var soldier = null
			for potential_soldier in soldier_map.trench_occupation[side][soldier_hex]:
				if _get_soldier_persistance_priority(potential_soldier) < rally_point_priority:
					soldier = potential_soldier
			var prior_rally_point = soldier.current_rally_point
			soldier.set_rally_point(rally_points_by_assignment_priority[i])
			if prior_rally_point != null:
				_update_rally_point_priority(prior_rally_point)
			_update_rally_point_priority(rally_point)

# update's rally point's priority and moves it's position in list accordingly
func _update_rally_point_priority(rally_point:RallyPoint):
	var i = rally_points_by_assignment_priority.find(rally_point)
	var done = false
	while i - 1 >= 0 and \
	_get_rally_point_assignment_priority(rally_points_by_assignment_priority[i-1]) < _get_rally_point_assignment_priority(rally_point):
		rally_points_by_assignment_priority[i] = rally_points_by_assignment_priority[i - 1]
		rally_points_by_assignment_priority[i - 1] = rally_point
		i -= 1
		done = true
	if not done:
		while i + 1 <= rally_points_by_assignment_priority.size() - 1 and \
		_get_rally_point_assignment_priority(rally_points_by_assignment_priority[i+1]) > _get_rally_point_assignment_priority(rally_point):
			rally_points_by_assignment_priority[i] = rally_points_by_assignment_priority[i + 1]
			rally_points_by_assignment_priority[i + 1] = rally_point
			i += 1

func _insert_rally_point_by_priority(rally_point:RallyPoint):
	var i = rally_points_by_assignment_priority.bsearch_custom(rally_point, rally_point_priority_comparator, false)
	rally_points_by_assignment_priority.insert(i, rally_point)

func _get_rally_point_assignment_priority(rally_point):
	return _get_rally_point_assignment_priority_with_count(rally_point, rally_point.assigned_soldiers.size())

func _get_rally_point_assignment_priority_with_count(rally_point, assigned_soldier_count):
	if rally_point.get_parent() is ClearingOrder:
		if assigned_soldier_count >= 1:
			return 0
		return 10 - 0.1*assigned_soldier_count
	if rally_point.get_parent() is BuildOrder:
		if assigned_soldier_count >= 2:
			return 0
		return 1 - 0.1*assigned_soldier_count
	return 0

# Should always be equal to or higher than assignment priority for the same scenario
func _get_soldier_persistance_priority(soldier:Soldier):
	var rally_point = soldier.current_rally_point
	if rally_point == null:
		return 0
	return _get_rally_point_assignment_priority_with_count(rally_point, rally_point.assigned_soldiers.size()-1)
