extends Order
class_name BuildOrder

@onready var building_grid = InputManager.get_building_grid()

@export var hex_position : Vector2i = Vector2i.ZERO
@export var build_time = 10

func _ready():
	position = building_grid.map_to_local(hex_position)

func progress_build(progress:float):
	build_time -= progress
	if build_time <= 0:
		#Call subclass' implementation of build
		_build()
		#Remove order
		OrderManager.remove_build_orders([self])

# Virtual function to be inherited by subclass
# Called when construction is complete to update tileset and/or instantiate objects
func _build():
	pass
