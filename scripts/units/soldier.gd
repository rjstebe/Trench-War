extends CharacterBody2D
class_name Soldier

# Unit Stats
@export var speed = 40
@export var build_speed = 1

# References to child objects
@onready var nav_agent = $"./NavigationAgent"
@onready var selection_marker = $"./SelectionMarker"

# Unit State
enum Behavior {IDLE, RALLYING, EXECUTING, FIGHTING}
var current_behavior = Behavior.IDLE
@export var current_rally_point:RallyPoint = null

signal soldier_unassigned
signal soldier_assigned

func _ready():
	input_event.connect(InputManager._on_input_event.bind(self))
	soldier_unassigned.emit(self)

func _physics_process(delta):
	match(current_behavior):
		Behavior.RALLYING:
			if nav_agent.is_navigation_finished():
				_set_behavior(Behavior.EXECUTING)
		Behavior.EXECUTING:
			if not current_rally_point.overlaps_body(self):
				_set_behavior(Behavior.RALLYING)
			elif current_rally_point.get_parent() is BuildOrder:
				current_rally_point.get_parent().progress_build(build_speed*delta)
	match(current_behavior):
		Behavior.RALLYING:
			var next_waypoint: Vector2 = nav_agent.get_next_path_position()
			nav_agent.set_velocity(global_position.direction_to(next_waypoint) * speed)
		Behavior.IDLE:
			nav_agent.set_velocity(Vector2.ZERO)
		Behavior.EXECUTING:
			nav_agent.set_velocity(Vector2.ZERO)

func _on_safe_velocity_computed(safe_velocity:Vector2):
	velocity = safe_velocity
	move_and_slide()

func _set_behavior(new_behavior):
	match(new_behavior):
		Behavior.IDLE:
			nav_agent.avoidance_priority = 0
		Behavior.RALLYING:
			nav_agent.avoidance_priority = 1
		Behavior.EXECUTING:
			nav_agent.avoidance_priority = 0
	current_behavior = new_behavior

# Assign a rally point to this soldier and adjust behavior accordingly
# null represents unassigning the soldier without a replacement rally point
func set_rally_point(new_rally_point=null):
	if new_rally_point == null:
		_set_behavior(Behavior.IDLE)
		if current_rally_point != null:
			current_rally_point.assigned_soldiers.erase(self)
			soldier_unassigned.emit(self)
			current_rally_point = null
	elif current_rally_point != new_rally_point and new_rally_point.is_assignable():
		if current_rally_point != null:
			current_rally_point.assigned_soldiers.erase(self)
		new_rally_point.assigned_soldiers.append(self)
		_set_behavior(Behavior.RALLYING)
		nav_agent.target_position = new_rally_point.position
		soldier_assigned.emit(self)
		current_rally_point = new_rally_point
	else:
		print("Soldier could not be assigned to rally point, either it is already assigned, or the rally point is at its capacity for assigned soldiers")
