extends BuildOrder
class_name BuildTrenchOrder

@export var trench_direction: Vector2i
var opposite_order = null

func _ready():
	super._ready()
	#Check if opposite order exists,
	opposite_order = OrderManager.get_build_trench_order_by_location(hex_position+trench_direction, -trench_direction)
	#if so set opposite_order for both accordingly, and synchronize build_times
	if opposite_order != null:
		opposite_order.opposite_order = self
		build_time = opposite_order.build_time

func progress_build(progress:float):
	var orders_to_remove = []
	#If opposite order exists, progress the build on that as well
	if opposite_order != null:
		orders_to_remove.append_array(opposite_order._progess_build_one_side(progress))
	orders_to_remove.append_array(_progess_build_one_side(progress))
	if orders_to_remove.size() > 0:
		#Call subclass' implementation of build
		_build()
	OrderManager.remove_build_orders(orders_to_remove)

# Same as progess_build but the opposite order is not updated as well
func _progess_build_one_side(progress:float):
	build_time -= progress
	if build_time <= 0:
		#Give progress_build self to remove
		return [self]
	#Give progress_build no order to remove
	return []

func _build():
	#Check construction layer to see if new contruct_trench orders should be instantiated
	if opposite_order == null:
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
