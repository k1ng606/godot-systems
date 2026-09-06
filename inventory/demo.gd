extends Control

## Demo for the `inventory` module. Not reusable — it just exercises the module.
##
## Two independent `InventoryView`s ("Backpack" and "Chest"), each on its own
## `InventoryData`. Drag stacks around inside a grid or between the two grids;
## hold Shift while dragging to pick up half a stack. The buttons drive the
## `InventoryData` API directly so you can watch both views react to its signals.

const _ITEMS: Array[String] = [
	"res://inventory/items/potion.tres",
	"res://inventory/items/apple.tres",
	"res://inventory/items/coin.tres",
	"res://inventory/items/sword.tres",
]

var _item_types: Array[ItemType] = []
var _backpack: InventoryData
var _chest: InventoryData


func _ready() -> void:
	for path in _ITEMS:
		_item_types.append(load(path))

	_backpack = InventoryData.new()
	_backpack.columns = 5
	_backpack.rows = 4

	_chest = InventoryData.new()
	_chest.columns = 5
	_chest.rows = 4

	# Seed the backpack with a bit of everything so stacking is visible up front.
	_backpack.add_item(_item_types[0], 25)  # potions: overflows one 20-stack
	_backpack.add_item(_item_types[1], 6)   # apples
	_backpack.add_item(_item_types[2], 140) # coins: two full stacks + change
	_backpack.add_item(_item_types[3], 1)   # sword

	_build_ui()


func _build_ui() -> void:
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 24)
	root.add_theme_constant_override("margin_top", 24)
	root.add_theme_constant_override("margin_right", 24)
	root.add_theme_constant_override("margin_bottom", 24)
	add_child(root)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	root.add_child(column)

	var title := Label.new()
	title.text = "Inventory demo — drag to move, Shift-drag to split, drag between grids to transfer"
	column.add_child(title)

	var grids := HBoxContainer.new()
	grids.add_theme_constant_override("separation", 32)
	column.add_child(grids)
	grids.add_child(_labelled_grid("Backpack", _backpack))
	grids.add_child(_labelled_grid("Chest", _chest))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	column.add_child(buttons)
	buttons.add_child(_button("Add random item", _add_random_item))
	buttons.add_child(_button("Sort backpack", _backpack.sort_items))
	buttons.add_child(_button("Clear backpack", _backpack.clear))


func _labelled_grid(title: String, data: InventoryData) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = title
	box.add_child(label)

	var view := InventoryView.new()
	view.inventory = data
	box.add_child(view)
	return box


func _button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(handler)
	return button


func _add_random_item() -> void:
	var type: ItemType = _item_types[randi() % _item_types.size()]
	_backpack.add_item(type, randi_range(1, 8))
