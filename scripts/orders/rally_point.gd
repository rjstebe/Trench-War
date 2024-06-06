extends Area2D
class_name RallyPoint

@export var assigned_soldiers:Array = []
@export var soldier_limit = 2

signal rally_point_removed

func is_assignable():
	return assigned_soldiers.size() < soldier_limit

func _remove_rally_point():
	for soldier in assigned_soldiers:
		soldier.set_rally_point(null)
	rally_point_removed.emit(self)
	queue_free()
