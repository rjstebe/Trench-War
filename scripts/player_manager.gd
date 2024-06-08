extends Node
class_name PlayerManager

var build_trench_order_scene = preload("res://scenes/build_trench_order.tscn")

enum Side {PLAYER, ENEMY}
@export var side = Side.PLAYER

# Each dictionary is a set for which build orders have which numbers of soldiers assigned to them
var build_order_rally_points:Array[Dictionary] = [{},{},{}]
var build_trench_order_location_lookup:Dictionary = {}
var idle_soldiers:Dictionary = {}
var _update_assignments_this_frame:bool = true

func _physics_process(_delta):
	if _update_assignments_this_frame:
		update_build_order_assignments()
		_update_assignments_this_frame = false

func _on_build_order_removed(build_order:BuildOrder):
	#Clear order from trench order location lookup table if applicable
	if build_order is BuildTrenchOrder:
		build_trench_order_location_lookup.erase(build_order.hex_positions)
		build_trench_order_location_lookup.erase([build_order.hex_positions[1], build_order.hex_positions[0]])

func _on_rally_point_removed(rally_point:RallyPoint):
	#Clear rally point from build order rally points if applicable
	if rally_point.get_parent() is BuildOrder:
		for i in range(0,2):
			build_order_rally_points[i].erase(rally_point)
	_update_assignments_this_frame = true

func _on_soldier_unassigned(soldier):
	#Add soldier to idle soldiers set
	idle_soldiers[soldier] = null
	_update_assignments_this_frame = true

func _on_soldier_assigned(soldier):
	#Remove soldier from idle soldier set
	idle_soldiers.erase(soldier)
	_update_assignments_this_frame = true

func create_build_trench_order(trench_position:Array):
	if build_trench_order_location_lookup.has(trench_position):
		print("Cannot build trench order, trench order already exists at that location")
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

func get_build_trench_order_by_location(hex_position_a:Vector2i, hex_position_b:Vector2i):
	if build_trench_order_location_lookup.has([hex_position_a, hex_position_b]):
		return build_trench_order_location_lookup[[hex_position_a, hex_position_b]]

func update_build_order_assignments():
	for i in range(0,2):
		var available_soldiers = idle_soldiers.keys()
		while not available_soldiers.is_empty():
			var soldier = available_soldiers.pop_back()
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
