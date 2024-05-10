extends Node

@onready var input_mode:InputMode = DefaultInputMode.new()

@export var selection = {}

func get_building_grid():
	return $"../Battle/BuildingGrid"

func get_battle():
	return $"../Battle"

func _unhandled_key_input(event:InputEvent):
	if input_mode != null:
		input_mode._unhandled_key_input(event)

func _unhandled_input(event:InputEvent):
	if input_mode != null:
		input_mode._unhandled_input(event)

# Called when unit, building, or other game object is clicked
# Needs to be connected with input_event signal when game object is created
func _on_input_event(_viewport, event, _shape_idx, object):
	if input_mode != null:
		input_mode._on_input_event(event, object)
