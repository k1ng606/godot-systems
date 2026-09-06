class_name Hurtbox
extends Area2D

## The "can be hit" volume that feeds a `Health`.
##
## Self-contained: add it as a child of the damageable body, give it a
## `CollisionShape2D`, and it finds the body's `Health` automatically (or point
## `health_path` at one). When a `Hitbox` overlaps, its `damage` is applied to
## the linked `Health`. Configure detection with the node's own
## `collision_layer` / `collision_mask` — no project layers assumed.
##
## Connect `hit_taken` for reaction effects (flash, knockback, sound); those are
## left to the host project so this stays UI- and gameplay-agnostic.

## Emitted after a hit is applied, whether from a `Hitbox` overlap or `apply()`.
signal hit_taken(amount: int, source: Node)

@export_group("Hurtbox")
## The `Health` to damage. Leave empty to auto-find the first `Health` among this
## node's siblings, or on its parent.
@export var health_path: NodePath
## Minimum seconds between hits accepted from the same `Hitbox`. 0 lets every
## overlap through; raise it so a stationary overlap doesn't drain health on
## every physics frame. Timed against a monotonic clock, so it's frame-rate
## independent.
@export_range(0.0, 5.0, 0.05) var hit_cooldown: float = 0.0

var _health: Health
# Hitbox instance id -> Time.get_ticks_msec() when it last landed a hit here.
var _last_hit_ms: Dictionary = {}


func _ready() -> void:
	_health = _resolve_health()
	area_entered.connect(_on_area_entered)


## Deal damage straight to the linked `Health`, bypassing collision — for
## scripted hits, damage-over-time ticks, fall damage and the like.
func apply(amount: int, source: Node = null) -> void:
	if _health == null or _health.is_dead:
		return
	var removed: int = _health.damage(amount, source)
	if removed > 0:
		hit_taken.emit(removed, source)


func _on_area_entered(area: Area2D) -> void:
	var hitbox := area as Hitbox
	if hitbox == null or not hitbox.active:
		return
	if _health == null or _health.is_dead:
		return
	if not _off_cooldown(hitbox):
		return

	_last_hit_ms[hitbox.get_instance_id()] = Time.get_ticks_msec()
	var removed: int = _health.damage(hitbox.damage, hitbox.source)
	hit_taken.emit(removed, hitbox.source)
	hitbox.report_hit(self)


func _off_cooldown(hitbox: Hitbox) -> bool:
	if hit_cooldown <= 0.0:
		return true
	var last: int = _last_hit_ms.get(hitbox.get_instance_id(), -1)
	if last < 0:
		return true
	return Time.get_ticks_msec() - last >= int(hit_cooldown * 1000.0)


func _resolve_health() -> Health:
	if not health_path.is_empty():
		return get_node_or_null(health_path) as Health

	var parent: Node = get_parent()
	if parent == null:
		return null
	if parent is Health:
		return parent
	for sibling in parent.get_children():
		if sibling is Health:
			return sibling
	return null
