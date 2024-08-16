extends BuildOrder
class_name BuildTrenchOrder

func _build():
	#Check construction layer to see if new contruct_trench orders should be instantiated
	var new_trench_positions = building_grid.get_trench_positions_adjacent_to_trench(building_grid.construction_grid, hex_positions[0], hex_positions[1])
	for trench_position in new_trench_positions:
		InputManager.player_manager.create_build_trench_order(trench_position)
	#Construct trench segment
	building_grid.build_trench(hex_positions[0], hex_positions[1])
