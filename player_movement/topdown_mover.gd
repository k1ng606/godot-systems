class_name TopDownMover
extends Mover

## Bird's-eye character controller: move with WASD or the arrow keys. With
## `eight_way` on, diagonals are allowed and normalised so diagonal speed
## matches the cardinals; with it off, input snaps to a single axis.
##
## `max_speed` / `acceleration` / `deceleration` are inherited from Mover.

@export_group("Top-down")
## Allow diagonal movement. When off, the axis you were already moving on wins.
@export var eight_way: bool = true
## Rotate the node to face its travel direction.
@export var face_travel_direction: bool = false
## How quickly facing catches up to the travel direction; higher is snappier.
@export var turn_smoothing: float = 12.0

var _kept_axis := Vector2.RIGHT


func _physics_process(delta: float) -> void:
	var direction := _read_direction()
	velocity = accelerate(velocity, direction * max_speed, delta)
	move_and_slide()

	if face_travel_direction and velocity.length_squared() > 1.0:
		rotation = rotate_toward(rotation, velocity.angle(), turn_smoothing * delta)


func _read_direction() -> Vector2:
	var raw := Vector2(
		_axis(KEY_D, KEY_RIGHT) - _axis(KEY_A, KEY_LEFT),
		_axis(KEY_S, KEY_DOWN) - _axis(KEY_W, KEY_UP),
	)
	if raw == Vector2.ZERO:
		return Vector2.ZERO

	if eight_way:
		return raw.normalized()

	# Four-way: when both axes are held, keep the one already in use.
	if raw.x != 0.0 and raw.y != 0.0:
		if _kept_axis.x != 0.0:
			raw.x = 0.0
		else:
			raw.y = 0.0
	_kept_axis = raw
	return raw.normalized()


static func _axis(key_a: Key, key_b: Key) -> float:
	var down := Input.is_physical_key_pressed(key_a) or Input.is_physical_key_pressed(key_b)
	return 1.0 if down else 0.0
