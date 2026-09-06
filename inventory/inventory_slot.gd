class_name InventorySlot
extends Panel

## One cell of an `InventoryView`'s grid.
##
## Internal to the `inventory` module: `InventoryView` instances one per slot and
## also uses a detached copy as the drag preview. Renders its stack entirely in
## `_draw()` — the item icon, or a coloured placeholder swatch with the item's
## initial when `ItemType.icon` is null — plus a count badge for stacks of two or
## more. No child nodes, so it stays cheap to spawn in bulk.

## Position of this cell in the owning inventory, `cell.y * columns + cell.x`.
var slot_index: int = 0

var _stack: ItemStack


## Show `stack` (or clear the cell when `null`).
func display(stack: ItemStack) -> void:
	_stack = stack
	tooltip_text = _tooltip_for(stack)
	queue_redraw()


func _draw() -> void:
	if _stack == null or _stack.type == null:
		return

	var inner: Rect2 = Rect2(Vector2(4, 4), size - Vector2(8, 8))
	var type: ItemType = _stack.type

	if type.icon != null:
		draw_texture_rect(type.icon, inner, false)
	else:
		draw_rect(inner, type.placeholder_color())
		var initial: String = type.display_name.substr(0, 1).to_upper()
		if initial != "":
			var font: Font = get_theme_default_font()
			var font_size: int = int(inner.size.y * 0.5)
			var text_size: Vector2 = font.get_string_size(
				initial, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size
			)
			var origin: Vector2 = inner.position + (inner.size - text_size) * 0.5
			origin.y += text_size.y * 0.8
			draw_string(
				font, origin, initial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.BLACK
			)

	if _stack.count > 1:
		var font: Font = get_theme_default_font()
		var badge_size: int = 14
		var label: String = str(_stack.count)
		var label_size: Vector2 = font.get_string_size(
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, badge_size
		)
		var pos: Vector2 = size - label_size - Vector2(4, 3)
		# Dark plate so the count stays readable over any icon or swatch colour.
		draw_rect(Rect2(pos - Vector2(3, badge_size - 1), label_size + Vector2(6, 5)), Color(0, 0, 0, 0.6))
		draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, badge_size, Color.WHITE)


func _tooltip_for(stack: ItemStack) -> String:
	if stack == null or stack.type == null:
		return ""
	if stack.count > 1:
		return "%s  x%d" % [stack.type.display_name, stack.count]
	return stack.type.display_name
