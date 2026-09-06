extends Node2D

## Demo-only: draws a faint reference grid so movement reads clearly against it.
## Not part of the reusable module.

@export var extent: int = 2400
@export var step: int = 100
@export var line_color: Color = Color(1, 1, 1, 0.07)
@export var axis_color: Color = Color(1, 1, 1, 0.16)


func _draw() -> void:
	for x in range(-extent, extent + 1, step):
		draw_line(Vector2(x, -extent), Vector2(x, extent), line_color)
	for y in range(-extent, extent + 1, step):
		draw_line(Vector2(-extent, y), Vector2(extent, y), line_color)
	draw_line(Vector2(-extent, 0), Vector2(extent, 0), axis_color)
	draw_line(Vector2(0, -extent), Vector2(0, extent), axis_color)
