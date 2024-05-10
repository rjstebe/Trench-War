extends InputMode
class_name BuildTrenchInputMode

var mouse_hex = null
var start_hex = null

func _init():
	super._init()
	name = "Build Trench"
	help_text = "Click to place start of trench line, Esc to cancel"
	mouse_hex = building_grid.local_to_map(building_grid.get_local_mouse_position())

func _unhandled_key_input(event:InputEvent):
	if event.is_action_released("ui_cancel"):
		building_grid.clear_layer(building_grid.PLANNING_LAYER_INDEX)
		InputManager.input_mode = DefaultInputMode.new()
		print("canceling action")
		return

func _unhandled_input(event:InputEvent):
	if event is InputEventMouseMotion:
		mouse_hex = building_grid.local_to_map(building_grid.get_local_mouse_position())
		building_grid.clear_layer(building_grid.PLANNING_LAYER_INDEX)
		if start_hex != null:
			building_grid.set_cells_terrain_path(building_grid.PLANNING_LAYER_INDEX, building_grid.hex_line(start_hex,mouse_hex), 0, 0)
		return
	if event.is_action_released("select"):
		if start_hex != null:
			building_grid.clear_layer(building_grid.PLANNING_LAYER_INDEX)
			_set_construction_layer(building_grid.hex_line(start_hex,mouse_hex))
			InputManager.input_mode = DefaultInputMode.new()
			print("Finished action")
			return
		start_hex = mouse_hex
		help_text = "Click again to set endpoint, Esc to cancel"
		print("Started Trench")
		return

# Add hex line to construction layer, but not including connections that already exist
func _set_construction_layer(hex_line:Array[Vector2i]):
	var lines = []
	var build_trench_order_positions = []
	var start_index = 0
	var end_index = 0
	for i in range(hex_line.size()):
		var current_real_hex = building_grid.get_cell_tile_data(building_grid.REAL_LAYER_INDEX,hex_line[i])
		# add line to lines if (current is real or at end of hex_line) and currently counting
		if current_real_hex != null or i + 1 >= hex_line.size():
			if end_index > start_index:
				lines.append(hex_line.slice(start_index, end_index+1))
				start_index = i
				end_index = i
				# Also create construction order for end of line if applicable
				if current_real_hex != null:
					build_trench_order_positions.append([hex_line[i], hex_line[i-1]-hex_line[i]])
		# if not counting a line start a new one when no connection to next hex
		if i + 1 < hex_line.size() and (current_real_hex == null or current_real_hex.get_terrain_peering_bit(building_grid.get_neighbor_from_direction(hex_line[i+1]-hex_line[i])) != building_grid.TRENCH_TERRAIN_INDEX):
			if end_index <= start_index:
				start_index = i
				# Also create construction order for beginning of line if applicable
				if current_real_hex != null:
					build_trench_order_positions.append([hex_line[i], hex_line[i+1]-hex_line[i]])
			end_index = i+1
	
	for line in lines:
		building_grid.set_cells_terrain_path(building_grid.CONSTRUCTION_LAYER_INDEX, line, 0, building_grid.TRENCH_TERRAIN_INDEX)
	
	OrderManager.create_build_trench_orders(build_trench_order_positions)
