extends Node

var build_trench_order_scene = preload("res://scenes/build_trench_order.tscn")

# Each dictionary is a set for which build orders have which numbers of soldiers assigned to them
var build_order_rally_points:Array[Dictionary] = [{},{},{}]
var build_trench_order_location_lookup:Dictionary = {}
var idle_soldiers:Dictionary = {}

func create_build_trench_orders(trench_positions:Array):
	for trench_position in trench_positions:
		if build_trench_order_location_lookup.has(trench_position):
			continue
		var build_trench_order = build_trench_order_scene.instantiate()
		build_trench_order.hex_positions = [trench_position[0], trench_position[1]]
		InputManager.get_battle().add_child(build_trench_order)
		for rally_point in build_trench_order.rally_points:
			build_order_rally_points[0][rally_point] = null
		build_trench_order_location_lookup[[trench_position[0], trench_position[1]]] = build_trench_order
		build_trench_order_location_lookup[[trench_position[1], trench_position[0]]] = build_trench_order
	update_build_order_assignments()

func remove_build_orders(build_orders_to_remove:Array):
	for build_order in build_orders_to_remove:
		#Remove rally point from build_order_rally_points
		#and clear rally point for all assigned soldiers
		for rally_point in build_order.rally_points:
			build_order_rally_points[rally_point.assigned_soldiers.size()].erase(rally_point)
			for soldier in rally_point.assigned_soldiers:
				soldier.set_rally_point(null)
				idle_soldiers[soldier] = null
		build_order.queue_free()
		#Clear order from trench order location lookup table if applicable
		if build_order is BuildTrenchOrder:
			build_trench_order_location_lookup.erase(build_order.hex_positions)
			build_trench_order_location_lookup.erase([build_order.hex_positions[1], build_order.hex_positions[0]])
	update_build_order_assignments()

func get_build_trench_order_by_location(hex_position_a:Vector2i, hex_position_b:Vector2i):
	if build_trench_order_location_lookup.has([hex_position_a, hex_position_b]):
		return build_trench_order_location_lookup[[hex_position_a, hex_position_b]]

func update_build_order_assignments():
	var remaining_soldiers = idle_soldiers.keys().size()
	for i in range(0,2):
		for rally_point in build_order_rally_points[i].keys():
			if idle_soldiers.keys().size() <= 0:
				return
			var chosen_soldier = idle_soldiers.keys()[0]
			rally_point.assign_soldier(chosen_soldier)
			idle_soldiers.erase(chosen_soldier)
			build_order_rally_points[i].erase(rally_point)
			build_order_rally_points[i+1][rally_point] = null
