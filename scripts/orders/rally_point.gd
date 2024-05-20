extends Area2D
class_name RallyPoint

@export var assigned_soldiers:Array = []
@export var soldier_limit = 2

func assign_soldier(soldier:Soldier):
	if assigned_soldiers.size() >= soldier_limit:
		print("Can't assign soldier to rally point, no more space available in rally point")
	else:
		assigned_soldiers.append(soldier)
		soldier.set_rally_point(self)
