extends CharacterBody2D
class_name Soldier

var debug_path_line_scene = preload("res://scenes/debug/debug_path_line.tscn")

const show_debug_path = true

# Unit Stats
@export var speed = 40
@export var build_speed = 1

# References to child objects
@onready var nav_agent = $"./NavigationAgent"
@onready var selection_marker = $"./SelectionMarker"
var debug_path_line:Line2D

# Unit State
enum Behavior {IDLE, RALLYING, EXECUTING, FIGHTING}
var current_behavior = Behavior.IDLE
@export var current_rally_point:RallyPoint = null
var current_path = []

@export var side:PlayerManager.Side

signal soldier_entered_hex
signal soldier_left_hex

func _ready():
	input_event.connect(InputManager._on_input_event.bind(self))
	var hex_position = InputManager.building_grid.local_to_map(position)
	soldier_entered_hex.emit(self, hex_position)

func _physics_process(delta):
	match(current_behavior):
		Behavior.RALLYING:
			if nav_agent.is_navigation_finished():
				if current_path.size() > 1:
					current_path.pop_front()
					nav_agent.target_position = current_path[0]
				else:
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
	var previous_hex = InputManager.building_grid.local_to_map(position)
	move_and_slide()
	var new_hex = InputManager.building_grid.local_to_map(position)
	if new_hex != previous_hex:
		soldier_left_hex.emit(self, previous_hex)
		soldier_entered_hex.emit(self, new_hex)

func _remove_soldier():
	set_rally_point(null)
	soldier_left_hex.emit(self, InputManager.building_grid.local_to_map(position))

func _set_behavior(new_behavior):
	match(new_behavior):
		Behavior.IDLE:
			nav_agent.avoidance_priority = 0
		Behavior.RALLYING:
			nav_agent.avoidance_priority = 1
			nav_agent.target_position = current_path[0]
		Behavior.EXECUTING:
			nav_agent.avoidance_priority = 0
	current_behavior = new_behavior

func set_path(destination:Vector2):
	var disabled_hex_conditional = \
		func lambda(hex): 
			for given_side in PlayerManager.Side.values():
				if given_side != side and InputManager.soldier_map.soldier_vision_counts[given_side][hex] != 0:
					return hex != InputManager.building_grid.local_to_map(destination)
			return false
	if current_path.size() == 0 or current_path.back() != destination or \
	not InputManager.building_grid.trench_pathfinding.check_path(current_path, disabled_hex_conditional):
		current_path = InputManager.building_grid.trench_pathfinding.get_position_path(position, destination, disabled_hex_conditional)
	if current_path.size() == 0: #If no valid path found, unassign self from current rally point
		set_rally_point(null)
	if show_debug_path:
		if debug_path_line == null:
			debug_path_line = debug_path_line_scene.instantiate()
			get_parent().add_child(debug_path_line)
		debug_path_line.points = [position, destination]

func clear_path():
	current_path = []
	if show_debug_path:
		debug_path_line.points = []

# Assign a rally point to this soldier and adjust behavior accordingly
# null represents unassigning the soldier without a replacement rally point
func set_rally_point(new_rally_point=null):
	if new_rally_point == null:
		clear_path()
		_set_behavior(Behavior.IDLE)
		if current_rally_point != null:
			current_rally_point.assigned_soldiers.erase(self)
			current_rally_point = null
	elif current_rally_point != new_rally_point and new_rally_point.is_assignable():
		if current_rally_point != null:
			current_rally_point.assigned_soldiers.erase(self)
		new_rally_point.assigned_soldiers.append(self)
		current_rally_point = new_rally_point
		set_path(current_rally_point.position)
		_set_behavior(Behavior.RALLYING)
	else:
		print("Soldier could not be assigned to rally point, either it is already assigned, or the rally point is at its capacity for assigned soldiers")
