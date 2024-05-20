extends CharacterBody2D
class_name Soldier

@export var speed = 40
@export var build_speed = 1

@onready var nav_agent = $"./NavigationAgent"
@onready var selection_marker = $"./SelectionMarker"

enum State {IDLE, PATHING}
var current_state = State.IDLE
@export var current_rally_point:RallyPoint = null

func _ready():
	input_event.connect(InputManager._on_input_event.bind(self))
	OrderManager.idle_soldiers[self] = null

func _physics_process(delta):
	match(current_state):
		State.PATHING:
			if nav_agent.is_navigation_finished():
				_set_state(State.IDLE)
		State.IDLE:
			if current_rally_point != null:
				if not current_rally_point.overlaps_body(self):
					_set_state(State.PATHING)
				elif current_rally_point.get_parent() is BuildOrder:
					current_rally_point.get_parent().progress_build(build_speed*delta)
	match(current_state):
		State.PATHING:
			var next_waypoint: Vector2 = nav_agent.get_next_path_position()
			nav_agent.set_velocity(global_position.direction_to(next_waypoint) * speed)
		State.IDLE:
			nav_agent.set_velocity(Vector2.ZERO)

func _on_safe_velocity_computed(safe_velocity:Vector2):
	velocity = safe_velocity
	move_and_slide()

func _set_state(new_state):
	match(new_state):
		State.IDLE:
			nav_agent.avoidance_priority = 0
		State.PATHING:
			nav_agent.avoidance_priority = 1
	current_state = new_state

# Assign a rally point to this soldier and adjust behavior accordingly
# (does not check or modify assigned soldiers on rally point)
func set_rally_point(new_rally_point=null):
	if new_rally_point == null:
		_set_state(State.IDLE)
	else:
		_set_state(State.PATHING)
		nav_agent.target_position = new_rally_point.position
	current_rally_point = new_rally_point
