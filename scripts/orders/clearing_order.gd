extends Order
class_name ClearingOrder

@onready var building_grid = InputManager.building_grid

@export var hex_position:Vector2i
@export var target_direction:Vector2i

func _ready():
	rally_points[0].position = building_grid.map_to_local(hex_position+target_direction)
	get_child(1).position = building_grid.map_to_local(hex_position)
	get_child(1).rotation = get_child(1).position.direction_to(rally_points[0].position).angle()
	if get_parent().side == PlayerManager.Side.PLAYER:
		get_child(1).color = Color.BLUE
	elif get_parent().side == PlayerManager.Side.ENEMY:
		get_child(1).color = Color.RED
