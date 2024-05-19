extends Area2D
class_name RallyPoint

@export var assigned_soldiers:Array = []
@export var soldier_limit = 2

func assign_soldier(soldier:Soldier):
	if assigned_soldiers.size() >= soldier_limit:
		print("Can't assign soldier to order, no more space available in order")
	else:
		assigned_soldiers.append(soldier)
		soldier.current_order = get_parent()
		soldier.current_rally_point = self
		soldier.nav_agent.target_position = position
		soldier.set_state(Soldier.State.PATHING)
