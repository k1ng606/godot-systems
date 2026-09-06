class_name ItemType
extends Resource

## Definition of one kind of item that can live in an inventory.
##
## Self-contained: plain `Resource`, no autoloads or project settings. Author one
## `.tres` per item (see `inventory/items/`) and hand it to
## `InventoryData.add_item()`, or build them in code. `icon` is optional — the
## UI falls back to a colour swatch drawn from `meta["color"]` plus the first
## letter of `display_name`, so the module ships without art.

## Stable identifier, unique per item kind. Used to test whether two stacks hold
## the same item, so keep it constant once content ships.
@export var id: StringName = &""

## Human-readable name shown in tooltips.
@export var display_name: String = ""

## Optional icon. When null the inventory UI draws a placeholder swatch instead.
@export var icon: Texture2D

## Largest number of this item that may share a single slot. 1 means unstackable.
@export_range(1, 9999) var max_stack: int = 99

## Open bag for host-project data (rarity, weight, effects...). The demo/UI read
## an optional `"color"` (Color) here for the no-art placeholder swatch.
@export var meta: Dictionary = {}


## True when more than one of this item fits in a slot.
func is_stackable() -> bool:
	return max_stack > 1


## Placeholder colour for the no-icon swatch. Falls back to a stable colour
## derived from `id` so distinct items still look distinct.
func placeholder_color() -> Color:
	if meta.has("color"):
		return meta["color"]
	return Color.from_hsv(float(hash(id) % 360) / 360.0, 0.55, 0.85)
