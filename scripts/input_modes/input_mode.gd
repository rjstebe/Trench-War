extends RefCounted
class_name InputMode

var name = "Unknown"
var help_text = "You should not be seeing this"
var building_grid:TileMap = null

func _init():
	building_grid = InputManager.get_building_grid()

func _unhandled_input(_event:InputEvent):
	pass

func _unhandled_key_input(_event:InputEvent):
	pass

func _on_input_event(_event:InputEvent, _object:Soldier):
	pass
