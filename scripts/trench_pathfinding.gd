extends AStar2D
class_name TrenchPathfinding

var _building_grid:BuildingGrid
var _vision_counts = [[], []]

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
		for side in PlayerManager.Side.values():
			if _vision_counts[side].size() < new_point+1:
				_vision_counts[side].resize(new_point+1)
			_vision_counts[side][new_point] = 0
		return new_point
	return point

func _get_point(hex_position:Vector2i):
	var cartesian_position = _building_grid.map_to_local(hex_position)
	var closest_point = get_closest_point(cartesian_position, true)
	if closest_point != -1 and get_point_position(closest_point) != cartesian_position:
		return -1
	return closest_point

func _change_vision_count(hex_position:Vector2i, side:PlayerManager.Side, change:int):
	var point = _get_point(hex_position)
	if point != -1:
		_vision_counts[side][point] += change

func _set_vision_count(hex_position:Vector2i, side:PlayerManager.Side, new_value:int):
	var point = _get_point(hex_position)
	if point != -1:
		_vision_counts[side][point] = new_value

func get_vision_count(hex_position:Vector2i, side:PlayerManager.Side):
	var point = _get_point(hex_position)
	if point != -1:
		return _vision_counts[side][point]
	return -1

func _update_vision_for_tile(hex_position:Vector2i):
	for side in PlayerManager.Side.values():
		var running_vision_count = 0
		for visible_hex in _building_grid.get_trench_hexes_in_line_of_sight(hex_position):
			if _building_grid.soldier_counts[0].has(visible_hex):
				running_vision_count += _building_grid.soldier_counts[side][visible_hex]
		_set_vision_count(hex_position, side, running_vision_count)

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

# Returns closest hex to given position that satisfies the given conditional function
# following only trench connections
# Uses a basic depth-first search to achieve this
func get_closest_hex_by_trench(hex_position:Vector2i, target_conditional:Callable, disabled_hex_conditional:Callable):
	var next_hexes = [hex_position]
	var searched_hexes = []
	while not next_hexes.is_empty():
		var current_hex = next_hexes.pop_front()
		if disabled_hex_conditional.call(current_hex):
			continue
		if target_conditional.call(current_hex):
			return current_hex
		searched_hexes.append(current_hex)
		for adjacent_position in _building_grid.get_adjacent_trench_hex_positions(current_hex):
			if not next_hexes.has(adjacent_position) and not searched_hexes.has(adjacent_position):
				next_hexes.append(adjacent_position)
	# If this point is reached the trench system has been searched exhaustively
	# without finding a hex that satisfies the given condition, so return null
	# to signify that
	return null
