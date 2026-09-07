class_name GamePlayer
extends TopDownMover

## The slice's hero: a `TopDownMover` wearing the rest of the library — a
## `Health` + `Hurtbox` that take damage, a swing that deals it through
## `Hurtbox.apply()`, an `InventoryData` bag for loot, and an `RTSCamera` riding
## along as a follow camera.
##
## Game code, not a module: it deliberately depends on four module folders at
## once, which is exactly what a module itself may never do.

## Item id consumed by `use_potion()`, matching `inventory/items/potion.tres`.
const POTION_ID: StringName = &"potion"

@export_group("Combat")
## Hit points removed by one swing.
@export var attack_damage: int = 25
## Seconds between swings.
@export var attack_cooldown: float = 0.35
## Seconds the swing graphic stays up.
@export var attack_duration: float = 0.12
## Distance from the player to the centre of the swing.
@export var attack_reach: float = 34.0
## Radius of the swing itself.
@export var attack_radius: float = 26.0
## Physics layers the swing looks for `Hurtbox`es on. The default is physics
## layer 4 (bit value 8), which is where `enemy.tscn` puts its hurtbox.
@export_flags_2d_physics var attack_mask: int = 8

@export_group("Items")
## Hit points restored by one potion.
@export var potion_heal: int = 40

## The player's bag. Loot is added here by `GamePickup`, and the HUD's
## `InventoryView` renders it.
var inventory: InventoryData = InventoryData.new()

@onready var health: Health = $Health

@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _aim: Node2D = $Aim
@onready var _arc: Polygon2D = $Aim/Arc

var _cooldown_left: float = 0.0
var _swing_left: float = 0.0
var _swing_query := PhysicsShapeQueryParameters2D.new()


func _ready() -> void:
	var circle := CircleShape2D.new()
	circle.radius = attack_radius
	_swing_query.shape = circle
	_swing_query.collision_mask = attack_mask
	_swing_query.collide_with_areas = true
	_swing_query.collide_with_bodies = false

	_arc.position = Vector2(attack_reach, 0.0)
	_arc.visible = false
	_hurtbox.hit_taken.connect(_on_hit_taken)
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if _swing_left > 0.0:
		_swing_left = maxf(0.0, _swing_left - delta)
		if _swing_left == 0.0:
			_end_swing()

	if health.is_dead:
		# Coast to a stop instead of freezing mid-stride.
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
		move_and_slide()
		return

	_aim.rotation = (get_global_mouse_position() - global_position).angle()
	super._physics_process(delta)


func _unhandled_input(event: InputEvent) -> void:
	if health.is_dead:
		return

	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		attack()
		return

	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_Q:
		use_potion()


## Swing at the cursor. No-op while on cooldown or dead.
##
## The hit is a one-shot shape query rather than an armed `Hitbox`: a `Hurtbox`
## only reacts to an overlap that *begins*, so a box switched on over an enemy
## already standing in the arc would never land. `Hurtbox.apply()` is the
## module's own entry point for scripted hits like this one.
func attack() -> void:
	if _cooldown_left > 0.0 or health.is_dead:
		return
	_cooldown_left = attack_cooldown
	_swing_left = attack_duration
	_arc.visible = true

	_swing_query.transform = Transform2D(0.0, _arc.global_position)
	for hit in get_world_2d().direct_space_state.intersect_shape(_swing_query, 8):
		var hurtbox := hit["collider"] as Hurtbox
		if hurtbox != null:
			hurtbox.apply(attack_damage, self)


## Drink one potion from the bag. Returns false when there is none, or when
## there is nothing to heal.
func use_potion() -> bool:
	if health.is_dead or health.is_full():
		return false
	if not consume(POTION_ID, 1):
		return false
	health.heal(potion_heal)
	return true


## How many of `item_id` the bag holds, across every stack.
func count(item_id: StringName) -> int:
	var total: int = 0
	for i in inventory.size():
		var stack := inventory.get_slot(i)
		if stack != null and stack.type != null and stack.type.id == item_id:
			total += stack.count
	return total


## Remove `amount` of `item_id` from the bag. All-or-nothing: returns false and
## leaves the bag untouched unless the full amount is there.
func consume(item_id: StringName, amount: int) -> bool:
	if amount <= 0 or count(item_id) < amount:
		return false

	var left: int = amount
	for i in inventory.size():
		if left == 0:
			break
		var stack := inventory.get_slot(i)
		if stack == null or stack.type == null or stack.type.id != item_id:
			continue
		var taken: int = mini(left, stack.count)
		inventory.take_from_slot(i, taken)
		left -= taken
	return true


func _end_swing() -> void:
	_arc.visible = false


func _on_hit_taken(_amount: int, _source: Node) -> void:
	modulate = Color(1.0, 0.55, 0.55)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.25)


func _on_died(_source: Node) -> void:
	_swing_left = 0.0
	_end_swing()
	modulate = Color(0.45, 0.45, 0.5)
