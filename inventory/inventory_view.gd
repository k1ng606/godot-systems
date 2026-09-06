class_name InventoryView
extends PanelContainer

## Drag-and-drop grid UI for an `InventoryData`.
##
## Self-contained: instance `inventory_view.tscn`, assign an `InventoryData` to
## `inventory` (or let it make its own), and the grid renders itself and stays in
## sync through the resource's signals. Left-drag moves a whole stack; hold the
## split modifier while starting a drag to pick up half. Dropping onto the same
## item merges (respecting `max_stack`), onto a different item swaps, onto empty
## space returns the stack to where it came from. Because the drag payload
## carries its source inventory, dragging between two `InventoryView`s transfers
## items between their inventories with no extra wiring.

const _SLOT_SCENE: PackedScene = preload("res://inventory/inventory_slot.tscn")

@export_group("Data")
## The inventory this view shows. If left null, the view creates an empty one on
## ready so it still works standalone.
@export var inventory: InventoryData:
	set = set_inventory

@export_group("Layout")
## Side length of each square slot, in pixels.
@export_range(16, 256) var slot_size: int = 48:
	set(value):
		slot_size = value
		_rebuild()
## Gap between slots, in pixels.
@export_range(0, 32) var slot_separation: int = 4:
	set(value):
		slot_separation = value
		_apply_separation()

@export_group("Split")
## Modifier held while starting a drag to pick up half the stack instead of all
## of it. Read straight off the keyboard, so the view needs no InputMap actions.
@export_enum("Shift", "Ctrl", "Alt") var split_modifier_key: int = 0

var _grid: GridContainer
var _built_size: int = -1

# Set while a drag started from this view is in flight, so a drag that ends over
# nothing can be returned to its origin slot.
var _drag_stack: ItemStack
var _drag_origin: int = -1


func _ready() -> void:
	_grid = GridContainer.new()
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grid)
	_apply_separation()
	if inventory == null:
		inventory = InventoryData.new()
	else:
		_rebuild()


## Swap in a different inventory, moving the signal connections with it.
func set_inventory(data: InventoryData) -> void:
	if inventory == data:
		return
	if inventory != null and inventory.slot_changed.is_connected(_refresh_slot):
		inventory.slot_changed.disconnect(_refresh_slot)
		inventory.contents_changed.disconnect(_on_inventory_changed)
	inventory = data
	if inventory != null:
		inventory.slot_changed.connect(_refresh_slot)
		inventory.contents_changed.connect(_on_inventory_changed)
	_rebuild()


func _get_drag_data(at_position: Vector2) -> Variant:
	var index: int = _index_at(at_position)
	if index < 0:
		return null

	var payload: Dictionary = _pick_up(index, _split_held())
	if payload.is_empty():
		return null

	set_drag_preview(_build_drag_preview(payload["stack"]))
	return payload


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.has("stack") and data["stack"] is ItemStack):
		return false
	# Reject drops on the padding between/around slots so the stack falls back to
	# its origin instead of vanishing into a no-op.
	return _index_at(at_position) >= 0


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var index: int = _index_at(at_position)
	if index < 0:
		return
	_place(index, data)


func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END:
		return
	if _drag_stack == null:
		return
	if not is_drag_successful():
		# Back to the slot it left — same item or an empty slot, never a swap.
		inventory.drop_into_slot(_drag_origin, _drag_stack, false)
	_drag_stack = null
	_drag_origin = -1


# Detach a stack (half of it when `split` and more than one) from `index` and
# record it as this view's in-flight drag. Returns the drag payload, or an empty
# dict when the slot holds nothing to pick up.
func _pick_up(index: int, split: bool) -> Dictionary:
	var stack: ItemStack = inventory.get_slot(index)
	if stack == null:
		return {}

	var amount: int = stack.count
	if split and stack.count > 1:
		amount = int(ceil(stack.count / 2.0))

	var taken: ItemStack = inventory.take_from_slot(index, amount)
	if taken == null:
		return {}

	_drag_stack = taken
	_drag_origin = index
	return {"source": inventory, "index": index, "stack": taken}


# Resolve a drag payload onto `index` of this view's inventory without ever
# losing items: merge/swap here, then send any remainder back to the origin
# slot, and as a last resort top up / refill the source inventory.
func _place(index: int, data: Dictionary) -> void:
	var source: InventoryData = data["source"]
	var origin: int = data["index"]
	# A split pickup leaves same-kind items in the origin slot; swapping a
	# different item into it there would strand them, so only allow a swap when
	# the whole stack was lifted and the origin slot is now empty.
	var whole_pickup: bool = source.get_slot(origin) == null

	var leftover: ItemStack = inventory.drop_into_slot(index, data["stack"], whole_pickup)
	if leftover != null:
		leftover = source.drop_into_slot(origin, leftover, false)
	if leftover != null:
		source.add_item(leftover.type, leftover.count)

	# This view owns the in-flight stack only if the drag started here.
	if source == inventory:
		_drag_stack = null
		_drag_origin = -1


func _build_drag_preview(stack: ItemStack) -> Control:
	var preview: InventorySlot = _SLOT_SCENE.instantiate()
	preview.custom_minimum_size = Vector2(slot_size, slot_size)
	preview.size = Vector2(slot_size, slot_size)
	preview.modulate.a = 0.85
	preview.display(stack)
	var wrapper: Control = Control.new()
	wrapper.add_child(preview)
	preview.position = -0.5 * Vector2(slot_size, slot_size)
	return wrapper


# Index of the slot under a view-local position, or -1.
func _index_at(at_position: Vector2) -> int:
	if _grid == null:
		return -1
	var local: Vector2 = at_position - _grid.position
	for child in _grid.get_children():
		var slot: InventorySlot = child
		if slot.get_rect().has_point(local):
			return slot.slot_index
	return -1


func _split_held() -> bool:
	match split_modifier_key:
		1:
			return Input.is_physical_key_pressed(KEY_CTRL)
		2:
			return Input.is_physical_key_pressed(KEY_ALT)
		_:
			return Input.is_physical_key_pressed(KEY_SHIFT)


func _rebuild() -> void:
	if _grid == null or inventory == null:
		return

	# Detach before freeing: `queue_free()` alone leaves the old slots parented
	# until the frame ends, so `_index_at()` / `_refresh_slot()` would read stale
	# nodes for the rest of this frame.
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()

	_grid.columns = inventory.columns
	for i in inventory.size():
		var slot: InventorySlot = _SLOT_SCENE.instantiate()
		slot.slot_index = i
		slot.custom_minimum_size = Vector2(slot_size, slot_size)
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		_grid.add_child(slot)
		slot.display(inventory.get_slot(i))

	_built_size = inventory.size()


func _refresh_slot(index: int) -> void:
	if _grid == null or index < 0 or index >= _grid.get_child_count():
		return
	var slot: InventorySlot = _grid.get_child(index)
	slot.display(inventory.get_slot(index))


func _on_inventory_changed() -> void:
	# Slot-level updates already arrived via `slot_changed`; only a resize needs a
	# full rebuild.
	if inventory.size() != _built_size:
		_rebuild()


func _apply_separation() -> void:
	if _grid == null:
		return
	_grid.add_theme_constant_override("h_separation", slot_separation)
	_grid.add_theme_constant_override("v_separation", slot_separation)
