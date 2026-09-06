extends Node2D

## Standalone playground for RTSCamera: a reference grid plus scattered
## landmarks so panning and zooming are easy to read. Not part of the module.

const EXTENT: int = 2000
const STEP: int = 100


func _draw() -> void:
	var grid: Color = Color(1, 1, 1, 0.12)
	for x in range(-EXTENT, EXTENT + 1, STEP):
		draw_line(Vector2(x, -EXTENT), Vector2(x, EXTENT), grid)
	for y in range(-EXTENT, EXTENT + 1, STEP):
		draw_line(Vector2(-EXTENT, y), Vector2(EXTENT, y), grid)

	draw_line(Vector2(-EXTENT, 0), Vector2(EXTENT, 0), Color(1, 0.4, 0.4, 0.6), 2.0)
	draw_line(Vector2(0, -EXTENT), Vector2(0, EXTENT), Color(0.4, 1, 0.4, 0.6), 2.0)

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in 48:
		var p := Vector2(rng.randf_range(-EXTENT, EXTENT), rng.randf_range(-EXTENT, EXTENT))
		draw_circle(p, rng.randf_range(12.0, 36.0), Color.from_hsv(rng.randf(), 0.55, 0.95))
