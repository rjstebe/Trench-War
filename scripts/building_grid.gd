extends TileMap
class_name BuildingGrid

@export var soldier_map:SoldierMap

const PLANNING_LAYER_INDEX = 2
const CONSTRUCTION_LAYER_INDEX = 1
const REAL_LAYER_INDEX = 0

const NO_COLLIDE_LAYERS = [PLANNING_LAYER_INDEX, CONSTRUCTION_LAYER_INDEX]
var trench_neighbors_lookup_table = {}

const TRENCH_TERRAIN_INDEX = 0
const TRENCH_TILE_SOURCE_INDEX = 0

var trench_pathfinding:TrenchPathfinding = TrenchPathfinding.new(self)

# Use _tile_data_runtime_update when updating tilemap layers that should have collisions disabled
func _use_tile_data_runtime_update(layer:int, _coords:Vector2i) -> bool:
	return layer in NO_COLLIDE_LAYERS

# Disable collisions for tiles on layers that shouldn't have collisions
func _tile_data_runtime_update(_layer:int, _coords:Vector2i, tile_data:TileData) -> void:
	tile_data.set_collision_polygons_count(0, 0)

func _ready():
	_set_up_trench_neighbors_lookup_table()
	for hex_position in get_used_cells(REAL_LAYER_INDEX):
		for neighbor_position in get_adjacent_trench_hex_positions(hex_position):
			trench_pathfinding.add_trench(hex_position, neighbor_position)

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

func build_trench(hex_position_a, hex_position_b):
	#Construct trench segment
	set_cells_terrain_path(REAL_LAYER_INDEX, [hex_position_a, hex_position_b], 0, TRENCH_TERRAIN_INDEX)
	#Remove segment in construction layer
	_erase_half_trench_segment(CONSTRUCTION_LAYER_INDEX, hex_position_a, get_neighbor_from_direction(hex_position_b-hex_position_a))
	_erase_half_trench_segment(CONSTRUCTION_LAYER_INDEX, hex_position_b, get_neighbor_from_direction(hex_position_a-hex_position_b))
	#Initialize new hexes if applicable
	soldier_map._init_hex(hex_position_a)
	soldier_map._init_hex(hex_position_b)
	#Update vision data
	var newly_visible_trenches = _get_trench_hexes_in_line_of_sight_in_direction(hex_position_a, hex_position_b-hex_position_a)
	newly_visible_trenches.append_array(_get_trench_hexes_in_line_of_sight_in_direction(hex_position_b, hex_position_a-hex_position_b))
	for hex_position in newly_visible_trenches:
		soldier_map.update_vision_for_tile(hex_position)
	trench_pathfinding.add_trench(hex_position_a, hex_position_b)
	soldier_map.update_trench_vision = true

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

# Get all adjacent construction trenches to the one defined by the two given hex positions
func get_trench_positions_adjacent_to_trench(hex_position_a, hex_position_b):
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

# Get all adjacent real trench hexes to the given one
func get_adjacent_trench_hex_positions(hex_position):
	var tile_data = get_cell_tile_data(REAL_LAYER_INDEX, hex_position)
	var adjacent_trench_hex_positions = []
	if tile_data != null:
		for neighbor in get_neighbor_list():
			var direction = get_direction_from_neighbor(neighbor)
			if tile_data.get_terrain_peering_bit(neighbor) == TRENCH_TERRAIN_INDEX:
				adjacent_trench_hex_positions.append(hex_position + direction)
	return adjacent_trench_hex_positions

#Returns all trench hexes that have a clear line of sight to the given hex position
func get_trench_hexes_in_line_of_sight(hex_position):
	var trench_hex_positions_in_line_of_sight = [hex_position]
	for neighbor in get_neighbor_list():
		var direction = get_direction_from_neighbor(neighbor)
		trench_hex_positions_in_line_of_sight.append_array(_get_trench_hexes_in_line_of_sight_in_direction(hex_position, direction))
	return trench_hex_positions_in_line_of_sight

#Does not include origin hex
func _get_trench_hexes_in_line_of_sight_in_direction(hex_position:Vector2i, direction:Vector2i):
	var trench_positions = []
	var current_hex_position = hex_position
	var current_hex = get_cell_tile_data(REAL_LAYER_INDEX, hex_position)
	while(current_hex != null and current_hex.get_terrain_peering_bit(get_neighbor_from_direction(direction)) == TRENCH_TERRAIN_INDEX):
		current_hex_position += direction
		trench_positions.append(current_hex_position)
		current_hex = get_cell_tile_data(REAL_LAYER_INDEX, current_hex_position)
	return trench_positions

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
