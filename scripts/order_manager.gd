extends Node

var build_trench_order_scene = preload("res://scenes/trench_construction.tscn")

# Each dictionary is a set for which build orders have which numbers of soldiers assigned to them
var build_orders:Array[Dictionary] = [{},{},{}]
var build_trench_order_location_lookup:Dictionary = {}
var idle_soldiers:Dictionary = {}

func create_build_trench_orders(trench_positions:Array):
	for trench_position in trench_positions:
		if build_trench_order_location_lookup.has(trench_position):
			continue
		var hex_position = trench_position[0]
		var direction = trench_position[1]
		var build_trench_order = build_trench_order_scene.instantiate()
		build_trench_order.hex_position = hex_position
		build_trench_order.trench_direction = direction
		build_trench_order.set_rotation_degrees(InputManager.get_building_grid().get_rotation_from_direction(direction))
		InputManager.get_battle().add_child(build_trench_order)
		build_orders[0][build_trench_order] = null
		build_trench_order_location_lookup[[hex_position,direction]] = build_trench_order
	update_build_order_assignments()

func remove_build_orders(build_orders_to_remove:Array):
	for build_order in build_orders_to_remove:
		#Clear order for all assigned soldiers
		build_orders[build_order.assigned_soldiers.size()].erase(build_order)
		if build_order is BuildTrenchOrder:
			build_trench_order_location_lookup.erase([build_order.hex_position, build_order.trench_direction])
		for soldier in build_order.assigned_soldiers:
			soldier.current_order = null
			soldier.set_state(Soldier.State.IDLE)
		build_order.queue_free()
	update_build_order_assignments()

func get_build_trench_order_by_location(hex_position:Vector2i, trench_direction:Vector2i):
	if build_trench_order_location_lookup.has([hex_position, trench_direction]):
		return build_trench_order_location_lookup[[hex_position, trench_direction]]

func update_build_order_assignments():
	var remaining_soldiers = idle_soldiers.keys().size()
	for i in range(0,2):
		for build_order in build_orders[i].keys():
			if remaining_soldiers <= 0:
				return
			build_order.assign_soldier(idle_soldiers.keys()[0])
			build_orders[i].erase(build_order)
			build_orders[i+1][build_order] = null
			remaining_soldiers -= 1
