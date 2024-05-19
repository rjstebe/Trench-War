extends CharacterBody2D
class_name Soldier

@export var speed = 40
@export var build_speed = 1

@onready var nav_agent = $"./NavigationAgent"
@onready var selection_marker = $"./SelectionMarker"

signal became_available(soldier:Soldier)

enum State {IDLE, PATHING}
var current_state = State.IDLE
@export var current_order:Order = null
@export var current_rally_point:RallyPoint = null

func _ready():
	input_event.connect(InputManager._on_input_event.bind(self))
	OrderManager.idle_soldiers[self] = null

func _physics_process(delta):
	match(current_state):
		State.PATHING:
			if nav_agent.is_navigation_finished():
				set_state(State.IDLE)
			var next_waypoint: Vector2 = nav_agent.get_next_path_position()
			nav_agent.set_velocity(global_position.direction_to(next_waypoint) * speed)
		State.IDLE:
			if current_order is BuildOrder and current_rally_point.overlaps_body(self):
				current_order.progress_build(build_speed*delta)
			nav_agent.set_velocity(Vector2.ZERO)
		_:
			nav_agent.set_velocity(Vector2.ZERO)

func _on_safe_velocity_computed(safe_velocity:Vector2):
	velocity = safe_velocity
	move_and_slide()

func set_state(new_state:State):
	match(new_state):
		State.PATHING:
			nav_agent.avoidance_priority = 1
			OrderManager.idle_soldiers.erase(self)
		State.IDLE:
			nav_agent.avoidance_priority = 0
			if current_order == null:
				OrderManager.idle_soldiers[self] = null
	current_state = new_state
