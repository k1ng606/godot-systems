extends SceneTree

## Headless test runner for the `inventory` module.
##
## Exercises `InventoryData` / `ItemStack` in isolation plus the drag-and-drop
## logic of `InventoryView`. No test framework dependency — it is a plain
## `SceneTree` script. Run from the project root:
##
##   godot --headless --path . --script res://inventory/tests/test_inventory.gd
##
## Exit code is 0 when every check passes and 1 otherwise, so it drops straight
## into CI.

var _checks: int = 0
var _failures: int = 0
var _suite: String = ""


func _initialize() -> void:
	_run()


func _run() -> void:
	_suite_item_stack()
	_suite_add_item()
	_suite_take_and_drop()
	_suite_swap_sort_clear()
	_suite_signals()
	await _suite_view_drag_drop()
	await _suite_view_rebuild()
	await _suite_view_index_at()

	print("\n%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


# --- InventoryData / ItemStack ------------------------------------------------


func _suite_item_stack() -> void:
	_begin("ItemStack")
	var apple: ItemType = _mk_type(&"apple", 10)
	var sword: ItemType = _mk_type(&"sword", 1)

	_check(ItemStack.new(apple, 3).is_same_item(ItemStack.new(apple, 1)), "is_same_item: same id")
	_check(not ItemStack.new(apple, 3).is_same_item(ItemStack.new(sword, 1)), "is_same_item: different id")
	_check(not ItemStack.new(apple, 3).is_same_item(null), "is_same_item: null")

	_check(ItemStack.new(apple, 3).can_merge_with(ItemStack.new(apple, 1)), "can_merge_with: room left")
	_check(not ItemStack.new(apple, 10).can_merge_with(ItemStack.new(apple, 1)), "can_merge_with: full stack")
	_check_eq(ItemStack.new(apple, 4).remaining_space(), 6, "remaining_space")


func _suite_add_item() -> void:
	_begin("InventoryData.add_item")
	var apple: ItemType = _mk_type(&"apple", 10)
	var data: InventoryData = _mk_data(3, 1)  # 3 slots

	_check_eq(data.add_item(apple, 25), 0, "adds 25 across empty slots, nothing left over")
	_check_eq(_slot_count(data, 0), 10, "slot 0 filled to max")
	_check_eq(_slot_count(data, 1), 10, "slot 1 filled to max")
	_check_eq(_slot_count(data, 2), 5, "slot 2 holds the remainder")

	_check_eq(data.add_item(apple, 3), 0, "tops up an existing partial stack first")
	_check_eq(_slot_count(data, 2), 8, "partial stack topped up in place")

	_check_eq(data.add_item(apple, 99), 99 - 2, "overflow returned once the grid is full")
	_check_eq(_total(data), 30, "grid caps at 3 * max_stack")

	_check_eq(data.add_item(null, 5), 5, "null type is a no-op")
	_check_eq(data.add_item(apple, 0), 0, "zero amount is a no-op")


func _suite_take_and_drop() -> void:
	_begin("InventoryData.take_from_slot / drop_into_slot")
	var apple: ItemType = _mk_type(&"apple", 10)
	var sword: ItemType = _mk_type(&"sword", 1)
	var data: InventoryData = _mk_data(4, 1)

	data.set_slot(0, ItemStack.new(apple, 6))
	var whole: ItemStack = data.take_from_slot(0, 6)
	_check(data.get_slot(0) == null, "take-all empties the slot")
	_check_eq(whole.count, 6, "take-all returns the full count")

	data.set_slot(0, ItemStack.new(apple, 6))
	var half: ItemStack = data.take_from_slot(0, 2)
	_check_eq(_slot_count(data, 0), 4, "partial take leaves the remainder")
	_check_eq(half.count, 2, "partial take returns the detached amount")
	_check(half != data.get_slot(0), "partial take returns a fresh stack, not the origin")

	_check(data.take_from_slot(1, 1) == null, "take from an empty slot returns null")

	# Drop onto empty.
	_check(data.drop_into_slot(1, ItemStack.new(apple, 3)) == null, "drop onto empty consumes the stack")
	_check_eq(_slot_count(data, 1), 3, "dropped stack lands in the empty slot")

	# Merge with overflow.
	data.set_slot(2, ItemStack.new(apple, 8))
	var overflow: ItemStack = data.drop_into_slot(2, ItemStack.new(apple, 5))
	_check_eq(_slot_count(data, 2), 10, "merge fills the target to max_stack")
	_check_eq(overflow.count, 3, "merge hands back the overflow")

	# Same item, full target -> no-op, not a swap.
	data.set_slot(2, ItemStack.new(apple, 10))
	var hand: ItemStack = ItemStack.new(apple, 4)
	var back: ItemStack = data.drop_into_slot(2, hand)
	_check(back == hand, "dropping onto a full stack of the same item is a no-op")
	_check_eq(_slot_count(data, 2), 10, "full target is untouched")

	# Different item, swap allowed by default.
	data.set_slot(3, ItemStack.new(sword, 1))
	var displaced: ItemStack = data.drop_into_slot(3, ItemStack.new(apple, 2))
	_check_eq(displaced.type.id, &"sword", "different item swaps out the target")
	_check_eq(data.get_slot(3).type.id, &"apple", "different item swaps in the dropped stack")

	# Different item, swap refused.
	data.set_slot(3, ItemStack.new(sword, 1))
	var refused_hand: ItemStack = ItemStack.new(apple, 2)
	var refused: ItemStack = data.drop_into_slot(3, refused_hand, false)
	_check(refused == refused_hand, "allow_swap=false refuses a different-item drop")
	_check_eq(data.get_slot(3).type.id, &"sword", "refused drop leaves the target in place")


func _suite_swap_sort_clear() -> void:
	_begin("InventoryData.swap_slots / sort_items / clear")
	var apple: ItemType = _mk_type(&"apple", 10)
	var coin: ItemType = _mk_type(&"coin", 99)
	var data: InventoryData = _mk_data(6, 1)

	data.set_slot(0, ItemStack.new(apple, 3))
	data.set_slot(1, ItemStack.new(coin, 7))
	data.swap_slots(0, 1)
	_check_eq(data.get_slot(0).type.id, &"coin", "swap_slots moves b into a")
	_check_eq(data.get_slot(1).type.id, &"apple", "swap_slots moves a into b")

	data.clear()
	data.set_slot(0, ItemStack.new(coin, 5))
	data.set_slot(2, ItemStack.new(apple, 4))
	data.set_slot(4, ItemStack.new(apple, 8))
	data.set_slot(5, ItemStack.new(coin, 6))
	data.sort_items()
	_check_eq(data.get_slot(0).type.id, &"apple", "sort orders by item id (apple before coin)")
	_check_eq(_slot_count(data, 0), 10, "sort merges apples into a full stack")
	_check_eq(_slot_count(data, 1), 2, "sort carries the apple remainder")
	_check_eq(data.get_slot(2).type.id, &"coin", "sort places coins after apples")
	_check_eq(_slot_count(data, 2), 11, "sort merges the coins")
	_check(data.get_slot(3) == null, "sort leaves trailing slots empty")
	_check_eq(_total(data), 12 + 11, "sort preserves the item totals")

	data.clear()
	for i in data.size():
		_check(data.get_slot(i) == null, "clear empties slot %d" % i)


func _suite_signals() -> void:
	_begin("InventoryData signals")
	var apple: ItemType = _mk_type(&"apple", 10)
	var data: InventoryData = _mk_data(4, 1)

	var changed: Array[int] = []
	var bulk: Array[bool] = []
	data.slot_changed.connect(func(i: int) -> void: changed.append(i))
	data.contents_changed.connect(func() -> void: bulk.append(true))

	changed.clear()
	bulk.clear()
	data.set_slot(0, ItemStack.new(apple, 2))
	_check(changed == [0], "set_slot emits slot_changed for the touched slot")
	_check(bulk.size() == 1, "set_slot emits contents_changed once")

	changed.clear()
	data.add_item(apple, 25)  # tops slot 0 to 10, fills slots 1 and 2
	_check(changed.has(0) and changed.has(1) and changed.has(2), "add_item emits slot_changed for every slot it writes")

	changed.clear()
	data.clear()
	_check(changed.has(0) and changed.has(1) and changed.has(2), "clear emits slot_changed for each emptied slot")
	_check(not changed.has(3), "clear does not signal slots that were already empty")

	data.set_slot(0, ItemStack.new(apple, 4))
	data.set_slot(3, ItemStack.new(apple, 4))
	changed.clear()
	data.sort_items()
	_check(changed.has(0), "sort_items signals a slot whose contents changed")
	_check(changed.has(3), "sort_items signals a slot it emptied")


# --- InventoryView ----------------------------------------------------------


func _suite_view_drag_drop() -> void:
	_begin("InventoryView drag & drop")
	var potion: ItemType = _mk_type(&"potion", 20)
	var sword: ItemType = _mk_type(&"sword", 1)
	var apple: ItemType = _mk_type(&"apple", 10)

	# Regression: a split pickup dropped onto a different item must not destroy
	# the items still sitting in the origin slot.
	var data: InventoryData = _mk_data(4, 1)
	data.set_slot(0, ItemStack.new(potion, 20))
	data.set_slot(1, ItemStack.new(sword, 1))
	var view: InventoryView = _mk_view(data)
	await _frames(1)

	var payload: Dictionary = view._pick_up(0, true)  # split -> lift 10
	_check_eq(_count_of(data, &"potion"), 10, "split pickup leaves 10 potions in the origin slot")
	view._place(1, payload)
	_check_eq(_count_of(data, &"potion"), 20, "no potions lost after split-drop onto a different item")
	_check_eq(_count_of(data, &"sword"), 1, "the sword is still there too")
	_check_eq(data.get_slot(0).type.id, &"potion", "split-drop onto a different item is a no-op: potions stay put")

	# Whole-stack drag onto a different item still swaps.
	data.clear()
	data.set_slot(0, ItemStack.new(potion, 5))
	data.set_slot(1, ItemStack.new(sword, 1))
	view._place(1, view._pick_up(0, false))
	_check_eq(data.get_slot(1).type.id, &"potion", "whole-stack drag swaps potions into the target")
	_check_eq(data.get_slot(0).type.id, &"sword", "whole-stack drag swaps the sword back to the origin")

	# Whole-stack drag that merges with overflow returns the remainder home.
	data.clear()
	data.set_slot(0, ItemStack.new(apple, 6))
	data.set_slot(1, ItemStack.new(apple, 8))
	view._place(1, view._pick_up(0, false))
	_check_eq(data.get_slot(1).count, 10, "merge fills the target to max")
	_check_eq(data.get_slot(0).count, 4, "merge overflow returns to the origin slot")
	view.free()

	# Cross-inventory transfer needs no extra wiring.
	var a: InventoryData = _mk_data(2, 1)
	var b: InventoryData = _mk_data(2, 1)
	a.set_slot(0, ItemStack.new(_mk_type(&"coin", 99), 50))
	var va: InventoryView = _mk_view(a)
	var vb: InventoryView = _mk_view(b)
	await _frames(1)
	vb._place(0, va._pick_up(0, false))
	_check(a.get_slot(0) == null, "coins leave the source inventory")
	_check_eq(_count_of(b, &"coin"), 50, "coins arrive in the destination inventory")
	va.free()
	vb.free()


func _suite_view_rebuild() -> void:
	_begin("InventoryView._rebuild")
	var data: InventoryData = _mk_data(3, 2)  # 6 slots
	var view: InventoryView = _mk_view(data)
	await _frames(1)

	var grid: GridContainer = view._grid
	_check_eq(grid.get_child_count(), 6, "grid has one node per slot after ready")

	# Two rebuilds with no frame between them: queue_free() alone would leave the
	# first batch of slots parented and the grid would balloon.
	view.slot_size = 40
	view.slot_size = 44
	_check_eq(grid.get_child_count(), 6, "back-to-back rebuilds keep exactly one node per slot")
	_check_eq(grid.get_child(0).slot_index, 0, "rebuilt child 0 maps to slot 0")
	_check_eq(grid.get_child(5).slot_index, 5, "rebuilt child 5 maps to slot 5")

	# A slot refresh right after a synchronous rebuild must hit the live node.
	data.set_slot(2, ItemStack.new(_mk_type(&"apple", 10), 3))
	_check_eq(grid.get_child(2).get("_stack").count, 3, "slot_changed reaches the freshly rebuilt slot node")
	view.free()


func _suite_view_index_at() -> void:
	_begin("InventoryView._index_at")
	var data: InventoryData = _mk_data(3, 2)
	var view: InventoryView = _mk_view(data)
	await _frames(2)

	var grid: GridContainer = view._grid
	for i in 6:
		var slot: Control = grid.get_child(i)
		var center: Vector2 = grid.position + slot.position + slot.size * 0.5
		_check_eq(view._index_at(center), i, "index_at resolves the centre of slot %d" % i)

	var corner: Control = grid.get_child(0)
	var gap: Vector2 = grid.position + corner.position - Vector2(2, 2)  # in the padding
	_check_eq(view._index_at(gap), -1, "index_at rejects the padding around the grid")
	_check_eq(view._index_at(Vector2(-100, -100)), -1, "index_at rejects points outside the grid")
	view.free()


# --- helpers ---------------------------------------------------------------


func _begin(name: String) -> void:
	_suite = name
	print("\n[%s]" % name)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)


func _check_eq(actual: Variant, expected: Variant, label: String) -> void:
	_check(actual == expected, "%s (got %s, want %s)" % [label, actual, expected])


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _mk_type(id: StringName, max_stack: int) -> ItemType:
	var type: ItemType = ItemType.new()
	type.id = id
	type.display_name = String(id).capitalize()
	type.max_stack = max_stack
	return type


func _mk_data(columns: int, rows: int) -> InventoryData:
	var data: InventoryData = InventoryData.new()
	data.columns = columns
	data.rows = rows
	return data


func _mk_view(data: InventoryData) -> InventoryView:
	var view: InventoryView = InventoryView.new()
	view.inventory = data
	root.add_child(view)
	return view


func _slot_count(data: InventoryData, index: int) -> int:
	var stack: ItemStack = data.get_slot(index)
	return 0 if stack == null else stack.count


func _total(data: InventoryData) -> int:
	var sum: int = 0
	for i in data.size():
		sum += _slot_count(data, i)
	return sum


func _count_of(data: InventoryData, id: StringName) -> int:
	var sum: int = 0
	for i in data.size():
		var stack: ItemStack = data.get_slot(i)
		if stack != null and stack.type != null and stack.type.id == id:
			sum += stack.count
	return sum
