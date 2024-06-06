extends RefCounted
class_name InputMode

var name = "Unknown"
var help_text = "You should not be seeing this"
var building_grid:TileMap = null
var human_player_manager:PlayerManager = null

func _init():
	building_grid = InputManager.building_grid
	human_player_manager = InputManager.player_manager

func _unhandled_input(_event:InputEvent):
	pass

func _unhandled_key_input(_event:InputEvent):
	pass

func _on_input_event(_event:InputEvent, _object:Soldier):
	pass
