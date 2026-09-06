class_name HealthBar
extends Control

## A slim bar that tracks a `Health`, with a trailing "chip" that eases toward
## the current value after a hit.
##
## Self-contained: instance `health_bar.tscn` (or add the script to a `Control`),
## then either set `health_path` or call `set_health()`. It redraws itself from
## the resource's `health_changed` signal. Size and colours are `@export`ed; the
## bar fills its own rect, so parent it wherever you want it (a `CanvasLayer`, or
## a `Node2D` above a character).

@export_group("Target")
## Path to the `Health` this bar visualises. Can also be set at runtime with
## `set_health()`.
@export var health_path: NodePath:
	set(value):
		health_path = value
		if is_inside_tree():
			set_health(get_node_or_null(health_path) as Health)

@export_group("Appearance")
## Fill drawn behind everything.
@export var background_color: Color = Color(0.1, 0.1, 0.12, 0.9)
## Fill colour at full health.
@export var fill_color: Color = Color(0.35, 0.78, 0.4)
## Fill colour blended in as health approaches empty.
@export var low_color: Color = Color(0.85, 0.3, 0.3)
## Below this fraction the fill blends toward `low_color`.
@export_range(0.0, 1.0, 0.01) var low_fraction: float = 0.25
## Speed the trailing chip chases the real value, in fraction per second.
## 0 snaps instantly with no chip.
@export_range(0.0, 50.0, 0.5) var drain_speed: float = 8.0
## Hide the whole bar while health is full.
@export var hide_when_full: bool = false

var _health: Health
var _target_fraction: float = 1.0
var _display_fraction: float = 1.0


func _ready() -> void:
	if _health == null and not health_path.is_empty():
		set_health(get_node_or_null(health_path) as Health)
	else:
		_sync()
	_display_fraction = _target_fraction
	queue_redraw()


## Point the bar at a different `Health`, moving the signal connection with it.
func set_health(health: Health) -> void:
	if _health == health:
		return
	if _health != null and _health.health_changed.is_connected(_on_health_changed):
		_health.health_changed.disconnect(_on_health_changed)
	_health = health
	if _health != null:
		_health.health_changed.connect(_on_health_changed)
	_sync()


func _process(delta: float) -> void:
	if is_equal_approx(_display_fraction, _target_fraction):
		return
	if drain_speed <= 0.0:
		_display_fraction = _target_fraction
	else:
		_display_fraction = move_toward(_display_fraction, _target_fraction, drain_speed * delta)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background_color)

	# Trailing chip: the shrinking gap between the old and new fill.
	if _display_fraction > _target_fraction:
		draw_rect(_bar_rect(_display_fraction), fill_color.darkened(0.45))

	if _target_fraction > 0.0:
		var t: float = clampf(_target_fraction / maxf(low_fraction, 0.0001), 0.0, 1.0)
		draw_rect(_bar_rect(_target_fraction), low_color.lerp(fill_color, t))


func _bar_rect(frac: float) -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size.x * clampf(frac, 0.0, 1.0), size.y))


func _on_health_changed(current: int, maximum: int) -> void:
	_target_fraction = 0.0 if maximum <= 0 else clampf(float(current) / maximum, 0.0, 1.0)
	if hide_when_full:
		visible = _target_fraction < 1.0
	queue_redraw()


func _sync() -> void:
	if _health != null:
		_on_health_changed(_health.current_health, _health.max_health)
	else:
		_target_fraction = 1.0
