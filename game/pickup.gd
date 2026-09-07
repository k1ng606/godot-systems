class_name GamePickup
extends Area2D

## A stack of loot lying on the floor. Walk over it and it goes into the
## player's `InventoryData`.
##
## Game code. It draws itself from `ItemType.placeholder_color()`, so loot needs
## no art, and it hands leftovers back to the floor when the bag is full.

@export_group("Contents")
## What this pickup holds.
@export var item_type: ItemType
## How many. Drops to whatever didn't fit if the bag filled up.
@export var amount: int = 1

@export_group("Feel")
## Distance at which the pickup starts sliding toward `attract_to`.
@export var magnet_radius: float = 110.0
## How fast it slides in, in pixels per second.
@export var magnet_speed: float = 300.0

## Who the magnet pulls toward. Left null, the pickup just sits there.
var attract_to: Node2D

var _bob_time: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_bob_time += delta

	if attract_to != null:
		var to_target := attract_to.global_position - global_position
		if to_target.length() < magnet_radius:
			global_position += to_target.normalized() * magnet_speed * delta

	queue_redraw()


func _draw() -> void:
	if item_type == null:
		return

	var bob := Vector2(0.0, sin(_bob_time * 3.0) * 3.0)
	draw_circle(Vector2(0.0, 8.0), 9.0, Color(0, 0, 0, 0.25))

	var half := 10.0
	var diamond := PackedVector2Array([
		bob + Vector2(0, -half), bob + Vector2(half, 0),
		bob + Vector2(0, half), bob + Vector2(-half, 0),
	])
	draw_polygon(diamond, PackedColorArray([item_type.placeholder_color()]))

	if amount > 1:
		# Node2D has no theme, so pull the engine's fallback font directly.
		draw_string(
			ThemeDB.fallback_font, bob + Vector2(8, 16), str(amount),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE
		)


func _on_body_entered(body: Node2D) -> void:
	var player := body as GamePlayer
	if player == null or item_type == null:
		return

	var leftover: int = player.inventory.add_item(item_type, amount)
	if leftover <= 0:
		queue_free()
		return

	# Bag full — leave the remainder on the floor to come back for.
	amount = leftover
	queue_redraw()
