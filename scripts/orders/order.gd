extends Node2D
class_name Order

@export var rally_points : Array[RallyPoint] = []

signal order_removed

func _remove_order():
	for rally_point in rally_points:
		rally_point._remove_rally_point()
	order_removed.emit(self)
	queue_free()

func get_total_assigned_soldiers():
	var total = 0
	for rally_point in rally_points:
		total += rally_point.assigned_soldiers
	return total
