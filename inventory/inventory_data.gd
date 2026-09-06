class_name InventoryData
extends Resource

## A fixed grid of inventory slots holding `ItemStack`s.
##
## Pure data + signals, no UI and no dependencies — drop `inventory/` into any
## Godot 4 project and use this from your own scripts, or point an
## `InventoryView` at it. An empty slot is `null`. Every mutation goes through
## the methods below so `slot_changed` / `contents_changed` stay accurate; moving items
## between two inventories is just `take_from_slot()` on one and
## `drop_into_slot()` on the other.

## Emitted for each slot whose contents changed. `index` is `cell.y * columns + cell.x`.
signal slot_changed(index: int)

## Emitted once after any operation that changed the inventory, for listeners
## that just rebuild everything (bulk adds, `clear()`, `sort_items()`, resizes).
signal contents_changed

# Backing store, declared before the exports so the `columns` / `rows` setters
# can safely re-fit it while member initializers run.
var _slots: Array[ItemStack] = []

## Grid width in slots. Changing it re-fits the backing array, preserving the
## items that still fall inside the grid.
@export_range(1, 64) var columns: int = 5:
	set(value):
		columns = maxi(1, value)
		_fit_slots()

## Grid height in slots.
@export_range(1, 64) var rows: int = 4:
	set(value):
		rows = maxi(1, value)
		_fit_slots()


func _init() -> void:
	_fit_slots()


## Total number of slots (`columns * rows`).
func size() -> int:
	return columns * rows


## The stack in `index`, or `null` if the slot is empty or the index is invalid.
func get_slot(index: int) -> ItemStack:
	if index < 0 or index >= _slots.size():
		return null
	return _slots[index]


## Replace a slot's contents outright. Pass `null` to empty it.
func set_slot(index: int, stack: ItemStack) -> void:
	if index < 0 or index >= _slots.size():
		return
	_slots[index] = stack
	slot_changed.emit(index)
	contents_changed.emit()


## Add `amount` of `type`, topping up existing stacks first, then filling empty
## slots. Returns the amount that did not fit.
func add_item(type: ItemType, amount: int) -> int:
	if type == null or amount <= 0:
		return amount

	var left: int = amount
	for i in _slots.size():
		var stack: ItemStack = _slots[i]
		if stack != null and stack.type != null and stack.type.id == type.id:
			var moved: int = mini(left, stack.remaining_space())
			if moved > 0:
				stack.count += moved
				left -= moved
				slot_changed.emit(i)
		if left == 0:
			break

	if left > 0:
		for i in _slots.size():
			if _slots[i] == null:
				var moved: int = mini(left, type.max_stack)
				_slots[i] = ItemStack.new(type, moved)
				left -= moved
				slot_changed.emit(i)
			if left == 0:
				break

	if left != amount:
		contents_changed.emit()
	return left


## Swap the contents of two slots.
func swap_slots(a: int, b: int) -> void:
	if a == b or a < 0 or b < 0 or a >= _slots.size() or b >= _slots.size():
		return
	var tmp: ItemStack = _slots[a]
	_slots[a] = _slots[b]
	_slots[b] = tmp
	slot_changed.emit(a)
	slot_changed.emit(b)
	contents_changed.emit()


## Detach up to `amount` items from `index` for a drag. Returns the detached
## stack (a fresh `ItemStack`), or `null` if the slot is empty. When `amount`
## covers the whole slot the slot is emptied.
func take_from_slot(index: int, amount: int) -> ItemStack:
	var stack: ItemStack = get_slot(index)
	if stack == null or amount <= 0:
		return null

	if amount >= stack.count:
		_slots[index] = null
		slot_changed.emit(index)
		contents_changed.emit()
		return stack

	stack.count -= amount
	slot_changed.emit(index)
	contents_changed.emit()
	return ItemStack.new(stack.type, amount)


## Drop `stack` onto `index`. If the slot holds the same item, merge into it up
## to `max_stack`. Otherwise swap the two stacks, unless `allow_swap` is false —
## then the drop is refused and `stack` comes straight back.
##
## Returns whatever is left in hand afterwards: merge overflow, the displaced
## stack, the untouched `stack` when the drop was refused or the target was a
## full stack of the same item, or `null` when `stack` was placed in full.
func drop_into_slot(index: int, stack: ItemStack, allow_swap: bool = true) -> ItemStack:
	if stack == null or index < 0 or index >= _slots.size():
		return stack

	var target: ItemStack = _slots[index]
	if target == null:
		_slots[index] = stack
		slot_changed.emit(index)
		contents_changed.emit()
		return null

	if target.is_same_item(stack):
		# Same item: absorb what fits, hand the rest back. A full target moves
		# nothing and is a no-op rather than a surprise swap of equal items.
		var moved: int = mini(stack.count, target.remaining_space())
		if moved > 0:
			target.count += moved
			stack.count -= moved
			slot_changed.emit(index)
			contents_changed.emit()
		return null if stack.count == 0 else stack

	if not allow_swap:
		return stack

	_slots[index] = stack
	slot_changed.emit(index)
	contents_changed.emit()
	return target


## Empty every slot.
func clear() -> void:
	for i in _slots.size():
		if _slots[i] != null:
			_slots[i] = null
			slot_changed.emit(i)
	contents_changed.emit()


## Compact the grid: merge stacks of the same item, drop gaps, order by item id.
func sort_items() -> void:
	var before: Array[ItemStack] = _slots.duplicate()

	var totals: Dictionary = {}
	var types: Dictionary = {}
	for stack in _slots:
		if stack == null or stack.type == null:
			continue
		var key: StringName = stack.type.id
		totals[key] = int(totals.get(key, 0)) + stack.count
		types[key] = stack.type

	for i in _slots.size():
		_slots[i] = null

	# Sort by the id's text, not `Array.sort()`'s default: comparing `StringName`s
	# directly orders them by intern order, which is effectively arbitrary.
	var keys: Array = totals.keys()
	keys.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var slot_index: int = 0
	for key in keys:
		var type: ItemType = types[key]
		var remaining: int = totals[key]
		while remaining > 0 and slot_index < _slots.size():
			var moved: int = mini(remaining, type.max_stack)
			_slots[slot_index] = ItemStack.new(type, moved)
			remaining -= moved
			slot_index += 1

	# Sorting rewrites the whole grid; tell views about every slot that moved so a
	# listener wired to `slot_changed` alone still repaints.
	for i in _slots.size():
		if before[i] != _slots[i]:
			slot_changed.emit(i)
	contents_changed.emit()


# Resize `_slots` to `columns * rows`, keeping stacks whose slot still exists.
func _fit_slots() -> void:
	var wanted: int = columns * rows
	if _slots.size() == wanted:
		return
	_slots.resize(wanted)
	contents_changed.emit()
