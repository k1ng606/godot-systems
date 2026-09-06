class_name ClickToMoveMover
extends Mover

## RTS-style click-to-move. Click a reachable point and the character paths to
## it, steering around static geometry with a NavigationAgent2D child and around
## other agents through that agent's avoidance. Needs a baked NavigationRegion2D
## in the scene — the demo builds one at runtime. Reads the mouse directly, so
## it needs no InputMap actions.
##
## `max_speed` / `acceleration` / `deceleration` are inherited from Mover.

@export_group("Click to move")
## Mouse button that issues a move order.
@export_enum("Left:1", "Middle:2", "Right:3") var move_button: int = 1
## Treat the destination as reached once within this many pixels.
@export var arrival_distance: float = 8.0
## Rotate the node to face its travel direction.
@export var face_travel_direction: bool = true
## How quickly facing catches up to the travel direction; higher is snappier.
@export var turn_smoothing: float = 12.0

@onready var _agent: NavigationAgent2D = $NavigationAgent2D


func _ready() -> void:
	_agent.path_desired_distance = maxf(arrival_distance, 4.0)
	_agent.target_desired_distance = arrival_distance
	_agent.max_speed = max_speed
	_agent.velocity_computed.connect(_on_avoidance_velocity)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == move_button:
			_agent.target_position = get_global_mouse_position()


func _physics_process(delta: float) -> void:
	if _agent.is_navigation_finished():
		velocity = accelerate(velocity, Vector2.ZERO, delta)
		move_and_slide()
		return

	var next_point := _agent.get_next_path_position()
	var desired := global_position.direction_to(next_point) * max_speed

	if _agent.avoidance_enabled:
		# Hand the intended velocity to the agent; it replies on
		# `velocity_computed` with an avoidance-corrected one.
		_agent.set_velocity(desired)
	else:
		_move(desired, delta)


func _on_avoidance_velocity(safe_velocity: Vector2) -> void:
	_move(safe_velocity, get_physics_process_delta_time())


func _move(target_velocity: Vector2, delta: float) -> void:
	velocity = accelerate(velocity, target_velocity, delta)
	move_and_slide()
	if face_travel_direction and velocity.length_squared() > 1.0:
		rotation = rotate_toward(rotation, velocity.angle(), turn_smoothing * delta)
