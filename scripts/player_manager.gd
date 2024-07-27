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
var soldier_lookup:Dictionary = {}
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

func _on_soldier_enter_hex(soldier:Soldier, hex_position:Vector2i):
	var new_list = []
	if soldier_lookup.has(hex_position):
		new_list = soldier_lookup[hex_position]
	new_list.append(soldier)
	soldier_lookup[hex_position] = new_list

func _on_soldier_leave_hex(soldier:Soldier, hex_position:Vector2i):
	if not soldier_lookup.has(hex_position):
		return
	var new_list = soldier_lookup[hex_position]
	new_list.erase(soldier)
	soldier_lookup[hex_position] = new_list

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
		if given_side != side and building_grid.trench_pathfinding.get_vision_count(hex_position, given_side) != 0:
			return false
	return true

func _valid_clearing_target_hex(target_hex:Vector2i):
	for given_side in Side.values():
		if given_side != side and building_grid.trench_pathfinding.get_vision_count(target_hex, given_side) != 0:
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
# TODO: All soldiers on a clearing order should have their order assignment cleared when order assignments are changed
func update_order_assignments():
	# Assign minimum soldiers to trench clearing orders
	for i in range(0,1):
		for rally_point in clearing_order_rally_points[i].keys():
			var soldier_hex = building_grid.trench_pathfinding.get_closest_hex_by_trench( \
				building_grid.local_to_map(rally_point.position), \
				func lambda(hex):
					if soldier_lookup.has(hex):
						for soldier in soldier_lookup[hex]:
							if _clearing_soldier_selection_condition(soldier):
								return true
					return false,
				func lambda(hex):
					for given_side in Side.values():
						if given_side != side and building_grid.trench_pathfinding.get_vision_count(hex, given_side) != 0:
							return hex != building_grid.local_to_map(rally_point.position)
					return false
			)
			var soldier = null
			if soldier_hex != null:
				for potential_soldier in soldier_lookup[soldier_hex]:
					if _clearing_soldier_selection_condition(potential_soldier):
						soldier = potential_soldier
						break
				# Update prior rally point data if applicable
				var prior_rally_point = soldier.current_rally_point
				if prior_rally_point != null and prior_rally_point.get_parent() is BuildOrder:
					var assigned_soldier_count = prior_rally_point.assigned_soldiers.size()
					build_order_rally_points[assigned_soldier_count].erase(prior_rally_point)
					build_order_rally_points[assigned_soldier_count-1][prior_rally_point] = null
				# Assign soldier to new rally point
				soldier.set_rally_point(rally_point)
				clearing_order_rally_points[i].erase(rally_point)
				clearing_order_rally_points[i+1][rally_point] = null
	# Assign remaining idle soldiers to build orders
	for i in range(0,2):
		for rally_point in build_order_rally_points[i].keys():
			var soldier_hex = building_grid.trench_pathfinding.get_closest_hex_by_trench( \
				building_grid.local_to_map(rally_point.position), \
				func lambda(hex):
					if soldier_lookup.has(hex):
						for soldier in soldier_lookup[hex]:
							if _building_soldier_selection_condition(soldier):
								return true
					return false,
				func lambda(hex):
					for given_side in Side.values():
						if given_side != side and building_grid.trench_pathfinding.get_vision_count(hex, given_side) != 0:
							return true
					return false
			)
			var soldier = null
			if soldier_hex != null:
				for potential_soldier in soldier_lookup[soldier_hex]:
					if _building_soldier_selection_condition(potential_soldier):
						soldier = potential_soldier
						break
				# Assign soldier to new rally point
				soldier.set_rally_point(rally_point)
				build_order_rally_points[i].erase(rally_point)
				build_order_rally_points[i+1][rally_point] = null

func _clearing_soldier_selection_condition(soldier):
	return (soldier.current_rally_point == null or soldier.current_rally_point is BuildOrder)

func _building_soldier_selection_condition(soldier):
	return soldier.current_rally_point == null
