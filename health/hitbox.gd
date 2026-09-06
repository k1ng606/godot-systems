class_name Hitbox
extends Area2D

## The "deals damage" volume — an attack arc, a projectile body, a spike.
##
## Self-contained: add it where the damage should come from, give it a
## `CollisionShape2D`, set `damage`, and overlap it with a `Hurtbox`. Detection
## is driven from the `Hurtbox` side, so damage is applied exactly once per pair
## per frame no matter which entered first. Configure detection with this node's
## own `collision_layer` / `collision_mask`.

## Emitted after this box's damage has been taken by a `Hurtbox`'s owner.
signal hit_landed(target: Node)

@export_group("Hitbox")
## Hit points removed from a `Health` when this box overlaps its `Hurtbox`.
@export_range(0, 100000) var damage: int = 10
## Attributed attacker, forwarded to `Health.damage()` and on to `died`.
## Defaults to this node's `owner` when left null.
@export var source: Node
## Disable the box after its first landed hit — for single-use projectiles and
## one-shot traps.
@export var one_shot: bool = false
## While false the box detects nothing, so an attack box can be armed only for
## the active frames of a swing.
@export var active: bool = true:
	set(value):
		active = value
		monitoring = value
		monitorable = value


func _ready() -> void:
	if source == null:
		source = owner
	monitoring = active
	monitorable = active


## Called back by a `Hurtbox` once it has taken a hit from this box.
func report_hit(hurtbox: Hurtbox) -> void:
	hit_landed.emit(hurtbox.get_parent())
	if one_shot:
		# Deferred: toggling monitoring mid-collision-callback is not allowed.
		_disarm.call_deferred()


func _disarm() -> void:
	active = false
