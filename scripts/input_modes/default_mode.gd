extends InputMode
class_name DefaultInputMode

func _init():
	super._init()
	name = "Default"
	help_text = ""

func _unhandled_key_input(event:InputEvent):
	if event.is_action_released("build_trench_hotkey"):
		InputManager.selection.clear()
		InputManager.input_mode = BuildTrenchInputMode.new()
		print("building trench")

func _unhandled_input(event:InputEvent):
	if event.is_action_released("quick_action"):
		var mouse_position = null
		for node in InputManager.selection:
			mouse_position = node.get_global_mouse_position()
			#node.set_rally_point()
			print("Manual move orders are not currently implemented")
		print("Ordered selection to move to position: ", mouse_position)

func _on_input_event(event:InputEvent, object:Soldier):
	if event.is_action_released("select"):
		for node in InputManager.selection:
			node.selection_marker.visible = false
		InputManager.selection.clear()
		InputManager.selection[object] = true
		object.selection_marker.visible = true
		print("Selected new unit")
