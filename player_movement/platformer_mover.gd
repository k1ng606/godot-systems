class_name PlatformerMover
extends Mover

## Side-scrolling character controller: run with A / D or the arrow keys, jump
## with Space (or W / Up). Includes the feel details players expect —
## acceleration and friction, reduced control in the air, coyote time, a jump
## buffer, variable jump height and a capped fall speed.
##
## Gravity and the jump impulse are derived from `jump_height` and
## `jump_time_to_peak`, so the arc is tuned in units you actually care about.
## `max_speed` / `acceleration` / `deceleration` are inherited from Mover.

@export_group("Jump")
## Peak height of a full jump, in pixels.
@export var jump_height: float = 96.0
## Time to reach the peak of a full jump, in seconds. With `jump_height` this
## fixes gravity and the jump impulse.
@export var jump_time_to_peak: float = 0.38
## Seconds after walking off a ledge during which a jump still registers.
@export var coyote_time: float = 0.10
## Seconds a jump press is remembered before landing.
@export var jump_buffer_time: float = 0.10
## Gravity multiplier while falling, for a snappier arc than the rise.
@export var fall_gravity_multiplier: float = 1.6
## Fraction of upward velocity kept when jump is released early (0 = hard cut).
@export_range(0.0, 1.0) var short_hop_factor: float = 0.45
## Maximum downward speed, in pixels per second.
@export var max_fall_speed: float = 1400.0

@export_group("Air control")
## Share of `acceleration` / `deceleration` that applies while airborne.
@export_range(0.0, 1.0) var air_control: float = 0.65

var _gravity: float = 0.0
var _jump_velocity: float = 0.0
var _coyote_timer: float = 0.0
var _buffer_timer: float = 0.0
var _jump_held: bool = false


func _ready() -> void:
	_derive_jump()


## Projectile motion: h = g * t^2 / 2 at the apex, and apex speed v = g * t.
func _derive_jump() -> void:
	_gravity = 2.0 * jump_height / (jump_time_to_peak * jump_time_to_peak)
	_jump_velocity = -_gravity * jump_time_to_peak


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()

	var jump_input := Input.is_physical_key_pressed(KEY_SPACE) \
		or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var jump_pressed := jump_input and not _jump_held
	var jump_released := not jump_input and _jump_held
	_jump_held = jump_input

	_coyote_timer = coyote_time if on_floor else _coyote_timer - delta
	_buffer_timer = jump_buffer_time if jump_pressed else _buffer_timer - delta

	_apply_horizontal(delta, on_floor)

	if not on_floor:
		var g := _gravity
		if velocity.y > 0.0:
			g *= fall_gravity_multiplier
		velocity.y = minf(velocity.y + g * delta, max_fall_speed)

	if _buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = _jump_velocity
		_buffer_timer = 0.0
		_coyote_timer = 0.0

	# Releasing jump while still rising trims the arc into a short hop.
	if jump_released and velocity.y < 0.0:
		velocity.y *= short_hop_factor

	move_and_slide()


func _apply_horizontal(delta: float, on_floor: bool) -> void:
	var direction := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		direction -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		direction += 1.0

	var control := 1.0 if on_floor else air_control
	var rate := (acceleration if direction != 0.0 else deceleration) * control
	velocity.x = move_toward(velocity.x, direction * max_speed, rate * delta)
