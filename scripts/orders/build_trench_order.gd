extends BuildOrder
class_name BuildTrenchOrder

func _build():
	#Check construction layer to see if new contruct_trench orders should be instantiated
	var new_trench_positions = building_grid.get_adjacent_trench_positions(hex_positions[0], hex_positions[1])
	for trench_position in new_trench_positions:
		InputManager.player_manager.create_build_trench_order(trench_position)
	#Construct trench segment
	building_grid.set_cells_terrain_path(building_grid.REAL_LAYER_INDEX, hex_positions, 0, building_grid.TRENCH_TERRAIN_INDEX)
	#Remove segment in construction layer
	building_grid.erase_trench_segment(building_grid.CONSTRUCTION_LAYER_INDEX, hex_positions[0], hex_positions[1])
