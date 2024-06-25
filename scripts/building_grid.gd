extends TileMap

var debug_label_scene = preload("res://scenes/debug/debug_label.tscn")

const PLANNING_LAYER_INDEX = 2
const CONSTRUCTION_LAYER_INDEX = 1
const REAL_LAYER_INDEX = 0

const NO_COLLIDE_LAYERS = [PLANNING_LAYER_INDEX, CONSTRUCTION_LAYER_INDEX]
var trench_neighbors_lookup_table = {}

const TRENCH_TERRAIN_INDEX = 0
const TRENCH_TILE_SOURCE_INDEX = 0

var player_soldier_count = {}
var enemy_soldier_count = {}
var player_count_debug_labels = {}
var enemy_count_debug_labels = {}

# Use _tile_data_runtime_update when updating tilemap layers that should have collisions disabled
func _use_tile_data_runtime_update(layer:int, _coords:Vector2i) -> bool:
	return layer in NO_COLLIDE_LAYERS

# Disable collisions for tiles on layers that shouldn't have collisions
func _tile_data_runtime_update(_layer:int, _coords:Vector2i, tile_data:TileData) -> void:
	tile_data.set_collision_polygons_count(0, 0)

func _ready():
	_set_up_trench_neighbors_lookup_table()

func _on_soldier_enter_hex(soldier:Soldier, hex_position:Vector2i):
	if not player_soldier_count.has(hex_position):
		player_soldier_count[hex_position] = 0
		enemy_soldier_count[hex_position] = 0
		var player_label = debug_label_scene.instantiate()
		var enemy_label = debug_label_scene.instantiate()
		add_child(player_label)
		add_child(enemy_label)
		player_label.position = map_to_local(hex_position)+Vector2(0, 10)
		enemy_label.position = map_to_local(hex_position)+Vector2(0, -10)
		player_label.get_child(0).set("theme_override_colors/font_color",Color.BLUE)
		player_label.get_child(0).text = "0"
		enemy_label.get_child(0).set("theme_override_colors/font_color",Color.RED)
		enemy_label.get_child(0).text = "0"
		player_count_debug_labels[hex_position] = player_label
		enemy_count_debug_labels[hex_position] = enemy_label
	if soldier.side == PlayerManager.Side.PLAYER:
		player_soldier_count[hex_position] += 1
		player_count_debug_labels[hex_position].get_child(0).text = str(player_soldier_count[hex_position])
	elif soldier.side == PlayerManager.Side.ENEMY:
		enemy_soldier_count[hex_position] += 1
		enemy_count_debug_labels[hex_position].get_child(0).text = str(enemy_soldier_count[hex_position])

func _on_soldier_leave_hex(soldier:Soldier, hex_position:Vector2i):
	if soldier.side == PlayerManager.Side.PLAYER:
		player_soldier_count[hex_position] -= 1
		player_count_debug_labels[hex_position].get_child(0).text = str(player_soldier_count[hex_position])
	elif soldier.side == PlayerManager.Side.ENEMY:
		enemy_soldier_count[hex_position] -= 1
		enemy_count_debug_labels[hex_position].get_child(0).text = str(enemy_soldier_count[hex_position])

func _set_up_trench_neighbors_lookup_table():
	for atlas_coord_and_alt_id in _get_all_trench_atlas_coords_and_alt_ids():
		var atlas_coord = atlas_coord_and_alt_id[0]
		var alt_id = atlas_coord_and_alt_id[1]
		var atlas_tile_data = tile_set.get_source(TRENCH_TILE_SOURCE_INDEX).get_tile_data(atlas_coord, alt_id)
		var neighbors = []
		for neighbor in get_neighbor_list():
			if atlas_tile_data.get_terrain_peering_bit(neighbor) == TRENCH_TERRAIN_INDEX:
				neighbors.append(neighbor)
		trench_neighbors_lookup_table[neighbors] = atlas_coord_and_alt_id

func _get_all_trench_atlas_coords_and_alt_ids():
	var coords_and_alt_ids = []
	var tile_source = tile_set.get_source(TRENCH_TILE_SOURCE_INDEX)
	for i in tile_source.get_tiles_count():
		var tile = tile_source.get_tile_id(i)
		for j in tile_source.get_alternative_tiles_count(tile):
			coords_and_alt_ids.append([tile, j])
	return coords_and_alt_ids

func erase_trench_segment(layer_index:int, start_position:Vector2i, end_position:Vector2i):
	_erase_half_trench_segment(layer_index, start_position, get_neighbor_from_direction(end_position-start_position))
	_erase_half_trench_segment(layer_index, end_position, get_neighbor_from_direction(start_position-end_position))

func _erase_half_trench_segment(layer_index:int, start_position:Vector2i, trench_neighbor:TileSet.CellNeighbor):
	var hex_data = get_cell_tile_data(layer_index, start_position)
	var neighbors_to_keep = []
	for neighbor in get_neighbor_list():
		if neighbor != trench_neighbor and hex_data.get_terrain_peering_bit(neighbor) == TRENCH_TERRAIN_INDEX:
			neighbors_to_keep.append(neighbor)
	erase_cell(layer_index, start_position)
	if not trench_neighbors_lookup_table.has(neighbors_to_keep):
		return
	var atlas_coord_and_alt_id = trench_neighbors_lookup_table[neighbors_to_keep]
	var atlas_coord = atlas_coord_and_alt_id[0]
	var alt_id = atlas_coord_and_alt_id[1]
	set_cell(layer_index, start_position, TRENCH_TILE_SOURCE_INDEX, atlas_coord, alt_id)

func place_trench_by_peering_bits(layer:int, coords:Vector2i, neighbors:Array[TileSet.CellNeighbor]):
	var atlas_coord_and_alt_id = trench_neighbors_lookup_table[neighbors]
	var atlas_coord = atlas_coord_and_alt_id[0]
	var alt_id = atlas_coord_and_alt_id[1]
	set_cell(layer, coords, TRENCH_TILE_SOURCE_INDEX, atlas_coord, alt_id)

func get_neighbor_list():
	return [
		TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,
		TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE,
		TileSet.CELL_NEIGHBOR_LEFT_SIDE,
		TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
		TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE,
		TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE
	]

func get_neighbor_from_direction(direction:Vector2i):
	match(direction):
		Vector2i(-1,0):
			return TileSet.CELL_NEIGHBOR_LEFT_SIDE
		Vector2i(1,0):
			return TileSet.CELL_NEIGHBOR_RIGHT_SIDE
		Vector2i(0,-1):
			return TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE
		Vector2i(0,1):
			return TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE
		Vector2i(-1,1):
			return TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE
		Vector2i(1,-1):
			return TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE
		_:
			return null

func get_direction_from_neighbor(neighbor:TileSet.CellNeighbor):
	match(neighbor):
		TileSet.CELL_NEIGHBOR_LEFT_SIDE:
			return Vector2i(-1,0)
		TileSet.CELL_NEIGHBOR_RIGHT_SIDE:
			return Vector2i(1,0)
		TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE:
			return Vector2i(0,-1) 
		TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE:
			return Vector2i(0,1)
		TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE:
			return Vector2i(-1,1)
		TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE:
			return Vector2i(1,-1)
		_:
			return null

# Get all adjacent trenches to the one defined by the two given hex positions
func get_adjacent_trench_positions(hex_position_a, hex_position_b):
	var construction_hex_a = get_cell_tile_data(CONSTRUCTION_LAYER_INDEX, hex_position_a)
	var construction_hex_b = get_cell_tile_data(CONSTRUCTION_LAYER_INDEX, hex_position_b)
	var neighbor_to_hex_a = get_neighbor_from_direction(hex_position_a - hex_position_b)
	var neighbor_to_hex_b = get_neighbor_from_direction(hex_position_b - hex_position_a)
	var adjacent_trench_positions = []
	for neighbor in get_neighbor_list():
		if neighbor != neighbor_to_hex_a and construction_hex_b.get_terrain_peering_bit(neighbor) == TRENCH_TERRAIN_INDEX:
			adjacent_trench_positions.append([hex_position_b, hex_position_b+get_direction_from_neighbor(neighbor)])
		if neighbor != neighbor_to_hex_b and construction_hex_a.get_terrain_peering_bit(neighbor) == TRENCH_TERRAIN_INDEX:
			adjacent_trench_positions.append([hex_position_a, hex_position_a+get_direction_from_neighbor(neighbor)])
	return adjacent_trench_positions

func hex_line(start_cell:Vector2i, end_cell:Vector2i) -> Array[Vector2i]:
	var start_position:Vector2 = map_to_local(start_cell)
	var end_position:Vector2 = map_to_local(end_cell)
	var relative_vector:Vector2i = end_cell - start_cell
	var hex_distance:int = maxi(maxi(absi(relative_vector.x),absi(relative_vector.y)),absi(relative_vector.x+relative_vector.y))
	var output_cells:Array[Vector2i] = []
	for i in range(hex_distance + 1):
		output_cells.append(local_to_map(start_position.lerp(end_position,float(i)/hex_distance)))
	return output_cells

func get_rotation_from_direction(direction:Vector2i):
	return rad_to_deg(Vector2.UP.angle_to(map_to_local(direction)-map_to_local(Vector2i.ZERO)))
