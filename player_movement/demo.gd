extends Node2D

## Switcher playground for the player_movement module. Press 1, 2 or 3 to move
## between the side-scroller, top-down and click-to-move controllers.
##
## The three worlds sit far apart in space so only the active one is on camera;
## their level geometry is built here in code purely to keep this scene file
## small. None of this file is part of the reusable module.

@onready var _worlds: Array[Node2D] = [
	$PlatformerWorld, $TopDownWorld, $ClickToMoveWorld,
]
@onready var _camera: Camera2D = $Camera2D
@onready var _label: Label = $HUD/Label

const _CAMERA_OFFSET: Array[Vector2] = [
	Vector2(0, -140), Vector2.ZERO, Vector2.ZERO,
]
const _HELP: Array[String] = [
	"1  Side-scroller    A / D or arrows to run, Space to jump",
	"2  Top-down         WASD or arrows, eight-way movement",
	"3  Click-to-move    left click to path around the pillars",
]

## Click-to-move arena, in that world's local space.
const _ARENA := Rect2(-600, -400, 1200, 800)
const _PILLARS: Array[Rect2] = [
	Rect2(-280, -300, 130, 230),
	Rect2(150, -60, 220, 150),
	Rect2(-340, 130, 190, 180),
]

var _active: int = -1


func _ready() -> void:
	_build_platformer_level($PlatformerWorld)
	_build_top_down_obstacles($TopDownWorld)
	_build_click_to_move_arena($ClickToMoveWorld)
	_activate(0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_1:
				_activate(0)
			KEY_2:
				_activate(1)
			KEY_3:
				_activate(2)


func _activate(index: int) -> void:
	if index == _active:
		return
	_active = index
	for i in _worlds.size():
		var world: Node2D = _worlds[i]
		var is_on: bool = i == index
		world.visible = is_on
		world.process_mode = Node.PROCESS_MODE_INHERIT if is_on else Node.PROCESS_MODE_DISABLED
	_camera.global_position = _worlds[index].global_position + _CAMERA_OFFSET[index]
	_label.text = "\n".join(PackedStringArray(_HELP)) + "\n\nActive:  " + _HELP[index].strip_edges()


func _build_platformer_level(parent: Node2D) -> void:
	var solid := Color(0.30, 0.33, 0.40)
	_add_static_box(parent, Rect2(-800, 0, 1600, 80), solid)      # floor
	_add_static_box(parent, Rect2(-560, -150, 200, 32), solid)    # platforms
	_add_static_box(parent, Rect2(-180, -280, 240, 32), solid)
	_add_static_box(parent, Rect2(240, -180, 200, 32), solid)
	_add_static_box(parent, Rect2(-820, -560, 40, 640), solid)    # side walls
	_add_static_box(parent, Rect2(780, -560, 40, 640), solid)


func _build_top_down_obstacles(parent: Node2D) -> void:
	var rock := Color(0.40, 0.36, 0.32)
	for box: Rect2 in [
		Rect2(-380, -260, 170, 170),
		Rect2(140, -320, 150, 240),
		Rect2(-90, 40, 250, 150),
		Rect2(-440, 130, 130, 210),
	]:
		_add_static_box(parent, box, rock)


func _build_click_to_move_arena(parent: Node2D) -> void:
	var region: NavigationRegion2D = parent.get_node("NavigationRegion2D")

	# Navigation: the arena rectangle is traversable; each pillar punches a hole.
	var geometry := NavigationMeshSourceGeometryData2D.new()
	geometry.add_traversable_outline(_rect_points(_ARENA))
	for pillar: Rect2 in _PILLARS:
		geometry.add_obstruction_outline(_rect_points(pillar))

	var nav_poly := NavigationPolygon.new()
	nav_poly.agent_radius = 24.0
	NavigationServer2D.bake_from_source_geometry_data(nav_poly, geometry)
	region.navigation_polygon = nav_poly

	# Matching physics: pillars, plus a perimeter wall so the body is stopped
	# even when avoidance nudges it off the path.
	var wall := Color(0.34, 0.37, 0.44)
	for pillar: Rect2 in _PILLARS:
		_add_static_box(parent, pillar, wall)
	var t := 40.0
	_add_static_box(parent, Rect2(_ARENA.position.x - t, _ARENA.position.y - t, _ARENA.size.x + 2.0 * t, t), wall)
	_add_static_box(parent, Rect2(_ARENA.position.x - t, _ARENA.end.y, _ARENA.size.x + 2.0 * t, t), wall)
	_add_static_box(parent, Rect2(_ARENA.position.x - t, _ARENA.position.y, t, _ARENA.size.y), wall)
	_add_static_box(parent, Rect2(_ARENA.end.x, _ARENA.position.y, t, _ARENA.size.y), wall)


func _add_static_box(parent: Node2D, box: Rect2, color: Color) -> void:
	var body := StaticBody2D.new()
	body.position = box.position + box.size * 0.5

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = box.size
	shape.shape = rect
	body.add_child(shape)

	var fill := Polygon2D.new()
	fill.polygon = _rect_points(Rect2(-box.size * 0.5, box.size))
	fill.color = color
	body.add_child(fill)

	parent.add_child(body)


static func _rect_points(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		r.position,
		r.position + Vector2(r.size.x, 0.0),
		r.position + r.size,
		r.position + Vector2(0.0, r.size.y),
	])
