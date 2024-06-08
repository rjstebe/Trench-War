extends Order
class_name BuildOrder

@onready var building_grid = InputManager.building_grid

@export var hex_positions : Array = []
@export var build_time = 10

@export var rally_points : Array[RallyPoint] = []

signal order_removed

func _ready():
	for i in range(0, rally_points.size()):
		rally_points[i].position = building_grid.map_to_local(hex_positions[i])

func progress_build(progress:float):
	build_time -= progress
	if build_time <= 0:
		#Call subclass' implementation of build
		_build()
		#Remove order
		_remove_order()

func _remove_order():
	for rally_point in rally_points:
		rally_point._remove_rally_point()
	order_removed.emit(self)
	queue_free()

# Virtual function to be inherited by subclass
# Called when construction is complete to update tileset and/or instantiate objects
func _build():
	pass
