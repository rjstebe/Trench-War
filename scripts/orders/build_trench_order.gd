extends BuildOrder
class_name BuildTrenchOrder

@export var trench_direction: Vector2i

func _build():
	#Check construction layer to see if new contruct_trench orders should be instantiated
	var construction_end_hex = building_grid.get_cell_tile_data(building_grid.CONSTRUCTION_LAYER_INDEX, hex_position+trench_direction)
	var neighbor_from_end = building_grid.get_neighbor_from_direction(-trench_direction)
	var new_trench_positions = []
	for neighbor in building_grid.get_neighbor_list():
		if neighbor != neighbor_from_end and construction_end_hex.get_terrain_peering_bit(neighbor) == building_grid.TRENCH_TERRAIN_INDEX:
			new_trench_positions.append([hex_position+trench_direction, building_grid.get_direction_from_neighbor(neighbor)])
	OrderManager.create_build_trench_orders(new_trench_positions)
	#Construct trench segment
	building_grid.set_cells_terrain_path(building_grid.REAL_LAYER_INDEX, [hex_position, hex_position+trench_direction], 0, building_grid.TRENCH_TERRAIN_INDEX)
	#Remove segment in construction layer
	building_grid.erase_trench_segment(building_grid.CONSTRUCTION_LAYER_INDEX, hex_position, trench_direction)
	#Remove order from other side if applicable
	var opposite_build_order = OrderManager.get_build_trench_order_by_location(hex_position+trench_direction, -trench_direction)
	if opposite_build_order != null:
		OrderManager.remove_build_orders([opposite_build_order])
