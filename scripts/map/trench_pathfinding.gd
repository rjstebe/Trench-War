extends AStar2D
class_name TrenchPathfinding

var _building_grid:BuildingGrid

func _init(building_grid:BuildingGrid):
	_building_grid = building_grid

func add_trench(hex_position_a:Vector2i, hex_position_b:Vector2i):
	var point_a = _get_or_init_point(hex_position_a)
	var point_b = _get_or_init_point(hex_position_b)
	if not are_points_connected(point_a, point_b):
		connect_points(point_a, point_b)

# Return point id of given hex position and add a new one if it does not exist already
func _get_or_init_point(hex_position:Vector2i):
	var point = _get_point(hex_position)
	if point == -1:
		var new_point = get_available_point_id()
		add_point(new_point, _building_grid.map_to_local(hex_position))
		return new_point
	return point

func _get_point(hex_position:Vector2i):
	var cartesian_position = _building_grid.map_to_local(hex_position)
	var closest_point = get_closest_point(cartesian_position, true)
	if closest_point != -1 and get_point_position(closest_point) != cartesian_position:
		return -1
	return closest_point

func get_hex_position_path(origin_hex:Vector2i, target_hex:Vector2i, disable_hex_conditional:Callable):
	var disabled_point_list = []
	var origin_id
	var target_id
	for id in get_point_ids():
		var hex_position = _building_grid.local_to_map(get_point_position(id))
		if disable_hex_conditional.call(hex_position):
			set_point_disabled(id)
			disabled_point_list.append(id)
		if hex_position == origin_hex:
			origin_id = _get_point(hex_position)
		if hex_position == target_hex:
			target_id = _get_point(hex_position)
	var point_path = get_point_path(origin_id, target_id)
	var hex_path = []
	for position in point_path:
		hex_path.append(_building_grid.local_to_map(position))
	for id in disabled_point_list:
		set_point_disabled(id, false)
	return hex_path

func get_position_path(origin_position:Vector2, target_position:Vector2, disable_hex_conditional:Callable):
	var position_path = get_hex_position_path(_building_grid.local_to_map(origin_position), _building_grid.local_to_map(target_position), disable_hex_conditional)
	for i in range(1, position_path.size()-1):
		position_path[i] = _building_grid.map_to_local(position_path[i])
	if position_path.size() > 0:
		position_path[0] = origin_position
		position_path[position_path.size()-1] = target_position
	return position_path

# Returns array with the following results:
# index 0: the closest hex to given position that satisfies the given conditional function
# following only trench connections
# index 1: the final distance it took to arrive at the located hex
# Uses a basic depth-first search to achieve this
func get_closest_hex_by_trench(hex_position:Vector2i, target_conditional:Callable, disabled_hex_conditional:Callable):
	var current_distance = 0
	var next_hexes = [hex_position]
	var next_layer = []
	var searched_hexes = []
	while not next_hexes.is_empty():
		var current_hex = next_hexes.pop_front()
		if not disabled_hex_conditional.call(current_hex):
			if target_conditional.call(current_hex, current_distance):
				return [current_hex, current_distance]
			searched_hexes.append(current_hex)
			for adjacent_position in _building_grid.get_adjacent_trench_hex_positions(_building_grid, current_hex):
				if not next_hexes.has(adjacent_position) and not searched_hexes.has(adjacent_position) and not next_layer.has(adjacent_position):
					next_layer.append(adjacent_position)
		if next_hexes.is_empty():
			next_hexes = next_layer
			next_layer = []
			current_distance += 1
	# If this point is reached the trench system has been searched exhaustively
	# without finding a hex that satisfies the given condition, so return null
	# to signify that
	return null

# Checks to see if given path is still valid according to the given disabled hex conditional
func check_path(path, disabled_hex_conditional:Callable):
	for i in range(0, path.size()):
		var position = path[i]
		var hex = _building_grid.local_to_map(position)
		var tile_data = _building_grid.get_cell_tile_data(hex)
		var neighbor
		if i != 0:
			var prev_hex = _building_grid.local_to_map(path[i-1])
			neighbor = _building_grid.get_neighbor_from_direction(prev_hex-hex)
		if disabled_hex_conditional.call(hex) and \
		(i == 0 or tile_data.get_terrain_peering_bit(neighbor) == _building_grid.TRENCH_TERRAIN_INDEX):
			return false
	return true
