extends Node
class_name SoldierMap

var debug_label_scene = preload("res://scenes/debug/debug_label.tscn")

const show_debug_labels = false

@export var building_grid:BuildingGrid

var trench_occupation = [{}, {}]
var soldier_vision_counts = [{}, {}]

var hex_position_debug_labels = {}
var soldier_count_debug_labels = [{}, {}]
var soldier_vision_debug_labels = [{}, {}]

var update_trench_vision = true

signal trench_vision_updated

func _on_soldier_enter_hex(soldier:Soldier, hex_position:Vector2i):
	add_soldier_to_trench(soldier, hex_position)

func _on_soldier_leave_hex(soldier:Soldier, hex_position:Vector2i):
	remove_soldier_from_trench(soldier, hex_position)

func _ready():
	for hex_position in building_grid.get_used_cells():
		_init_hex(hex_position)

func _process(_delta):
	if update_trench_vision:
		trench_vision_updated.emit()
		update_trench_vision = false

func hex_exists(hex_position:Vector2i):
	return trench_occupation[0].has(hex_position)

func update_vision_for_tile(hex_position:Vector2i):
	for side in PlayerManager.Side.values():
		var running_vision_count = 0
		for visible_hex in building_grid.get_trench_hexes_in_line_of_sight(building_grid, hex_position):
			if hex_exists(visible_hex):
				running_vision_count += trench_occupation[side][visible_hex].size()
		if soldier_vision_counts[side][hex_position] != running_vision_count:
			soldier_vision_counts[side][hex_position] = running_vision_count
			if show_debug_labels:
				soldier_vision_debug_labels[side][hex_position].get_child(0).text = str(running_vision_count)
	update_trench_vision = true

func add_soldier_to_trench(soldier:Soldier, hex_position:Vector2i):
	_init_hex(hex_position)
	var side = soldier.side
	trench_occupation[side][hex_position].append(soldier)
	if show_debug_labels:
		soldier_count_debug_labels[side][hex_position].get_child(0).text = str(trench_occupation[side][hex_position].size())
	for visible_hex in building_grid.get_trench_hexes_in_line_of_sight(building_grid, hex_position):
		if hex_exists(visible_hex):
			soldier_vision_counts[side][visible_hex] += 1
			if show_debug_labels:
				soldier_vision_debug_labels[side][visible_hex].get_child(0).text = str(soldier_vision_counts[side][visible_hex])
	update_trench_vision = true

func remove_soldier_from_trench(soldier:Soldier, hex_position:Vector2i):
	var side = soldier.side
	trench_occupation[side][hex_position].erase(soldier)
	if show_debug_labels:
		soldier_count_debug_labels[side][hex_position].get_child(0).text = str(trench_occupation[side][hex_position].size())
	for visible_hex in building_grid.get_trench_hexes_in_line_of_sight(building_grid, hex_position):
		if hex_exists(visible_hex):
			soldier_vision_counts[side][visible_hex] -= 1
			if show_debug_labels:
				soldier_vision_debug_labels[side][visible_hex].get_child(0).text = str(soldier_vision_counts[side][visible_hex])
	update_trench_vision = true

func _init_hex(hex_position:Vector2i):
	if not hex_exists(hex_position):
		const side_offsets = [-10, 10]
		const side_colors = [Color.BLUE, Color.RED]
		if show_debug_labels:
			var hex_position_label = debug_label_scene.instantiate()
			add_child(hex_position_label)
			hex_position_label.position = building_grid.map_to_local(hex_position)+Vector2(0, -20)
			hex_position_label.get_child(0).set("theme_override_colors/font_color",Color.YELLOW)
			hex_position_label.get_child(0).text = str(hex_position)
			hex_position_debug_labels[hex_position] = hex_position_label
		for side in PlayerManager.Side.values():
			if show_debug_labels:
				var soldier_count_label = debug_label_scene.instantiate()
				add_child(soldier_count_label)
				soldier_count_label.position = building_grid.map_to_local(hex_position)+Vector2(side_offsets[side], -10)
				soldier_count_label.get_child(0).set("theme_override_colors/font_color",side_colors[side])
				soldier_count_label.get_child(0).text = "0"
				soldier_count_debug_labels[side][hex_position] = soldier_count_label
				var soldier_vision_label = debug_label_scene.instantiate()
				add_child(soldier_vision_label)
				soldier_vision_label.position = building_grid.map_to_local(hex_position)+Vector2(side_offsets[side], 10)
				soldier_vision_label.get_child(0).set("theme_override_colors/font_color",side_colors[side])
				soldier_vision_label.get_child(0).text = "0"
				soldier_vision_debug_labels[side][hex_position] = soldier_vision_label
			trench_occupation[side][hex_position] = []
			soldier_vision_counts[side][hex_position] = 0
