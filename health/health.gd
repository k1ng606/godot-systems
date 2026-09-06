class_name Health
extends Node

## Hit-point store for any node: attach it as a child and drive it through
## `damage()` / `heal()` / `kill()` / `revive()`.
##
## Self-contained — pure state plus signals, no physics and no UI, no project
## autoloads or input actions. Drop the `health/` folder into any Godot 4
## project. Pair it with a `Hurtbox` to take collision damage and a `HealthBar`
## to show it, or just read `current_health` / `fraction()` from your own code.
## Every change funnels through the methods below so `health_changed`, `damaged`,
## `healed`, `died` and `revived` stay accurate.

## Emitted after any change to `current_health`, with the new values.
signal health_changed(current: int, maximum: int)

## Emitted when `damage()` actually removes hit points. `source` is whatever the
## caller passed (an attacker node, a hazard, or null).
signal damaged(amount: int, source: Node)

## Emitted when `heal()` actually restores hit points.
signal healed(amount: int)

## Emitted once when health reaches 0. `source` carries through from the lethal
## `damage()` / `kill()` call.
signal died(source: Node)

## Emitted when a dead target is brought back by `revive()`.
signal revived

@export_group("Health")
## Maximum hit points. Change it at runtime through `set_max_health()` so
## `current_health` and listeners stay in sync.
@export_range(1, 100000) var max_health: int = 100
## Start at `max_health`. Turn off to start at `starting_health` instead.
@export var start_full: bool = true
## Initial hit points when `start_full` is off. Clamped to `[0, max_health]`.
@export_range(0, 100000) var starting_health: int = 100

## Current hit points. Read freely; never assign directly — go through the
## mutating methods so signals fire.
var current_health: int
## Latched true once health hits 0, cleared only by `revive()`. Keeps `died`
## from firing more than once per death.
var is_dead: bool

var _initialized: bool = false


func _enter_tree() -> void:
	# Seed on the first tree entry (runs synchronously from `add_child`, unlike
	# `_ready`); the guard keeps a reparent from wiping current health.
	_initialize_state()


func _ready() -> void:
	_initialize_state()


func _initialize_state() -> void:
	if _initialized:
		return
	_initialized = true
	max_health = maxi(1, max_health)
	current_health = max_health if start_full else clampi(starting_health, 0, max_health)
	is_dead = current_health == 0
	health_changed.emit(current_health, max_health)


## Remove up to `amount` hit points. No-op when `amount <= 0` or already dead.
## Returns the hit points actually removed (less than `amount` near 0). Reaching
## 0 latches `is_dead` and emits `died(source)`.
func damage(amount: int, source: Node = null) -> int:
	if amount <= 0 or is_dead:
		return 0

	var before: int = current_health
	current_health = maxi(0, current_health - amount)
	var removed: int = before - current_health
	if removed > 0:
		damaged.emit(removed, source)
		health_changed.emit(current_health, max_health)

	if current_health == 0:
		is_dead = true
		died.emit(source)
	return removed


## Restore up to `amount` hit points, capped at `max_health`. No-op when
## `amount <= 0` or dead — a dead target only comes back through `revive()`.
## Returns the hit points actually restored.
func heal(amount: int) -> int:
	if amount <= 0 or is_dead:
		return 0

	var before: int = current_health
	current_health = mini(max_health, current_health + amount)
	var restored: int = current_health - before
	if restored > 0:
		healed.emit(restored)
		health_changed.emit(current_health, max_health)
	return restored


## Drop the target to 0 and mark it dead. `source` is passed on to `died`.
func kill(source: Node = null) -> void:
	if is_dead:
		return
	if current_health > 0:
		damage(current_health, source)
	else:
		is_dead = true
		died.emit(source)


## Bring a dead target back. No-op unless `is_dead`. With no argument (or a
## negative one) it returns to `max_health`; otherwise the argument is clamped to
## `[1, max_health]` so the target never revives already dead.
func revive(amount: int = -1) -> void:
	if not is_dead:
		return
	is_dead = false
	current_health = max_health if amount < 0 else clampi(amount, 1, max_health)
	revived.emit()
	health_changed.emit(current_health, max_health)


## Change `max_health` at runtime. By default `current_health` is only re-clamped
## into the new range; pass `scale_current` to keep the same health fraction
## (e.g. a +max-HP buff that heals proportionally).
func set_max_health(value: int, scale_current: bool = false) -> void:
	var new_max: int = maxi(1, value)
	if new_max == max_health:
		return

	if scale_current and max_health > 0:
		var frac: float = float(current_health) / max_health
		max_health = new_max
		current_health = clampi(roundi(frac * new_max), 0, new_max)
	else:
		max_health = new_max
		current_health = mini(current_health, new_max)

	if current_health == 0:
		is_dead = true
	health_changed.emit(current_health, max_health)


## Current health as a 0–1 fraction of `max_health`, for bars and shaders.
func fraction() -> float:
	return 0.0 if max_health <= 0 else clampf(float(current_health) / max_health, 0.0, 1.0)


## True when `current_health` has reached `max_health`.
func is_full() -> bool:
	return current_health >= max_health
