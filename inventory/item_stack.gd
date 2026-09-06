class_name ItemStack
extends Resource

## A quantity of one `ItemType` occupying a single inventory slot.
##
## Self-contained `Resource`, so an `InventoryData` with its stacks serialises to
## one `.tres`. `count` is always kept in `1..type.max_stack`; an empty slot is
## represented by `null`, never by a zero-count stack.

## What this stack holds.
@export var type: ItemType

## How many, in `1..type.max_stack`.
@export var count: int = 1


func _init(stack_type: ItemType = null, stack_count: int = 1) -> void:
	type = stack_type
	count = stack_count


## True when `other` holds the same kind of item as this stack, regardless of
## how full either stack is.
func is_same_item(other: ItemStack) -> bool:
	return (
		other != null
		and type != null
		and other.type != null
		and other.type.id == type.id
	)


## True when `other` holds the same item and this stack has room to absorb some
## of it.
func can_merge_with(other: ItemStack) -> bool:
	return is_same_item(other) and count < type.max_stack


## Free space left in this stack before it hits `type.max_stack`.
func remaining_space() -> int:
	if type == null:
		return 0
	return type.max_stack - count


## Independent copy, so a dragged half-stack never shares state with its origin.
func duplicate_stack() -> ItemStack:
	return ItemStack.new(type, count)
