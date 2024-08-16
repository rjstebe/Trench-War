extends Camera2D

const MIN_ZOOM : float = 0.02 #0.4
const MAX_ZOOM : float = 2
const ZOOM_INCREMENT : float = 1.1
const SCROLL_SPEED : float = 15

signal moved()
signal zoomed()

var _current_zoom : float = 2
var _map_size : Vector2 = Vector2(2000, 2000)
var motion_input : Vector2i = Vector2i(0, 0)

func _process(_delta):
	if motion_input != Vector2i.ZERO:
		_update_position()

# move and/or zoom camera
func _unhandled_input(event):
	if event.is_action("cam_zoom_in"):
		_update_zoom(1.0/ZOOM_INCREMENT, get_local_mouse_position())
	elif event.is_action("cam_zoom_out"):
		_update_zoom(ZOOM_INCREMENT, get_local_mouse_position())
	elif event.is_action_pressed("ui_left") or event.is_action_released("ui_right"):
		motion_input.x -= 1
	elif event.is_action_pressed("ui_right") or event.is_action_released("ui_left"):
		motion_input.x += 1
	elif event.is_action_pressed("ui_up") or event.is_action_released("ui_down"):
		motion_input.y -= 1
	elif event.is_action_pressed("ui_down") or event.is_action_released("ui_up"):
		motion_input.y += 1

func _update_position():
	var motion_vector : Vector2 = Vector2(motion_input).normalized() * SCROLL_SPEED
	position += motion_vector * _current_zoom
	_apply_limits()
	moved.emit()

func _update_zoom(increment : float, zoom_anchor : Vector2):
	var old_zoom = _current_zoom
	_current_zoom = clamp(_current_zoom * increment, MIN_ZOOM, MAX_ZOOM)
	if old_zoom == _current_zoom:
		return
	
	var zoom_center = zoom_anchor - get_offset()
	var ratio = 1 - _current_zoom / old_zoom
	position += zoom_center * ratio
	
	set_zoom(Vector2.ONE / Vector2(_current_zoom, _current_zoom))
	_apply_limits()
	zoomed.emit()

func _apply_limits():
	var view_offset = Vector2(0,0) * _current_zoom + Vector2(20, 20)
	var view_offset_2 = Vector2(0,0) * _current_zoom + Vector2(20, 20)
	var view_width = get_viewport().size.x * _current_zoom
	var view_height = get_viewport().size.y * _current_zoom
	if view_width > _map_size.x + view_offset.x + view_offset_2.x:
		position.x = (_map_size.x - view_offset.x + view_offset_2.x) / 2
	else:
		position.x = clamp(position.x, get_viewport().size.x/2 * _current_zoom - view_offset.x, _map_size.x - get_viewport().size.x/2 * _current_zoom + view_offset_2.x)
	if view_height > _map_size.y + view_offset.y + view_offset_2.y:
		position.y = (_map_size.y - view_offset.y + view_offset_2.y) / 2
	else:
		position.y = clamp(position.y, get_viewport().size.y/2 * _current_zoom - view_offset.y, _map_size.y - get_viewport().size.y/2 * _current_zoom + view_offset_2.y)
