class_name RTSCamera
extends Camera2D

## Top-down RTS-style camera.
##
## Keyboard + screen-edge panning, hold-to-drag panning, and cursor-anchored
## zoom, with an optional world-space bounding rect. Self-contained: it reads
## hardware keys and mouse buttons directly, so it needs no project input
## actions and no autoloads. Copy the `rts_camera/` folder into any Godot 4
## project and add `rts_camera.tscn` where the view should be controlled.

@export_group("Pan")
## Pan speed in world pixels per second, measured at zoom = 1.
@export var pan_speed: float = 800.0
## Pan while the mouse sits within `edge_margin` pixels of the viewport border.
@export var edge_scroll_enabled: bool = true
## Distance from the viewport edge, in pixels, that triggers edge scrolling.
@export var edge_margin: float = 24.0
## Mouse button that pans the view while held. "None" disables drag panning.
@export_enum("None:0", "Left:1", "Middle:2", "Right:3") var drag_button: int = 3
## Higher is snappier. 0 disables smoothing (movement is applied instantly).
@export var pan_smoothing: float = 12.0

@export_group("Zoom")
@export var zoom_min: float = 0.5
@export var zoom_max: float = 4.0
## Zoom multiplier applied per scroll-wheel notch.
@export var zoom_step: float = 1.1
## Higher is snappier. 0 disables smoothing.
@export var zoom_smoothing: float = 12.0
## Zoom toward the cursor instead of the screen centre.
@export var zoom_to_cursor: bool = true

@export_group("Bounds")
## When enabled, the camera centre is clamped inside `limit_rect`.
@export var limit_to_rect: bool = false
## Allowed range for the camera centre, in world coordinates.
@export var limit_rect: Rect2 = Rect2(-2000, -2000, 4000, 4000)

var _target_position: Vector2
var _target_zoom: Vector2
var _dragging: bool = false


func _ready() -> void:
	_target_position = position
	_target_zoom = zoom
	# This script does its own smoothing; keep Camera2D's follow smoothing off.
	position_smoothing_enabled = false


func _process(delta: float) -> void:
	if not is_current():
		return

	var move: Vector2 = _keyboard_vector()
	if edge_scroll_enabled and not _dragging:
		move += _edge_vector()
	if move != Vector2.ZERO:
		# Divide by zoom so the on-screen pan speed is constant at any zoom.
		_target_position += move.normalized() * pan_speed * delta / _target_zoom.x
		_target_position = _clamp_to_bounds(_target_position)

	if pan_smoothing > 0.0:
		position = position.lerp(_target_position, 1.0 - exp(-pan_smoothing * delta))
	else:
		position = _target_position

	if zoom_smoothing > 0.0:
		zoom = zoom.lerp(_target_zoom, 1.0 - exp(-zoom_smoothing * delta))
	else:
		zoom = _target_zoom


func _unhandled_input(event: InputEvent) -> void:
	if not is_current():
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_apply_zoom(1.0 / zoom_step, mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_apply_zoom(zoom_step, mb.position)
		elif drag_button != 0 and mb.button_index == drag_button:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event
		_target_position -= mm.relative / _target_zoom
		_target_position = _clamp_to_bounds(_target_position)


## Snap instantly to a world position, cancelling any in-flight pan smoothing.
func jump_to(world_position: Vector2) -> void:
	_target_position = _clamp_to_bounds(world_position)
	position = _target_position


func _keyboard_vector() -> Vector2:
	var v: Vector2 = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1.0
	return v


func _edge_vector() -> Vector2:
	if not get_window().has_focus():
		return Vector2.ZERO
	var rect: Rect2 = get_viewport().get_visible_rect()
	var m: Vector2 = get_viewport().get_mouse_position()
	if not rect.has_point(m):
		return Vector2.ZERO

	var v: Vector2 = Vector2.ZERO
	if m.x < edge_margin:
		v.x -= 1.0
	elif m.x > rect.size.x - edge_margin:
		v.x += 1.0
	if m.y < edge_margin:
		v.y -= 1.0
	elif m.y > rect.size.y - edge_margin:
		v.y += 1.0
	return v


func _apply_zoom(factor: float, screen_pos: Vector2) -> void:
	var scalar: float = clampf(_target_zoom.x * factor, zoom_min, zoom_max)
	var new_zoom: Vector2 = Vector2(scalar, scalar)

	if zoom_to_cursor and new_zoom != _target_zoom:
		# Keep the world point under the cursor fixed across the zoom change.
		var from_centre: Vector2 = screen_pos - get_viewport().get_visible_rect().size * 0.5
		_target_position += from_centre / _target_zoom - from_centre / new_zoom
		_target_position = _clamp_to_bounds(_target_position)

	_target_zoom = new_zoom


func _clamp_to_bounds(p: Vector2) -> Vector2:
	if not limit_to_rect:
		return p
	return Vector2(
		clampf(p.x, limit_rect.position.x, limit_rect.position.x + limit_rect.size.x),
		clampf(p.y, limit_rect.position.y, limit_rect.position.y + limit_rect.size.y),
	)
