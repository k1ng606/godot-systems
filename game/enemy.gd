class_name GameEnemy
extends Mover

## A slime that walks at its target and hurts on contact.
##
## Game code: it reuses `Mover` purely for the shared speed tuning and its
## frame-rate-independent `accelerate()`, and carries the `health` module's
## `Health` / `Hurtbox` / `Hitbox` / `HealthBar` set.

## Emitted the moment this enemy's health reaches 0, before the corpse fades.
signal defeated(enemy: GameEnemy)

@export_group("Chase")
## Stop closing in once this near the target, so a swarm doesn't pile up on it.
@export var stop_distance: float = 22.0
## Speed of the shove applied away from whatever landed a hit.
@export var knockback_speed: float = 420.0
## How fast that shove bleeds off, in pixels per second squared.
@export var knockback_decay: float = 1600.0

## Who to walk at. Set through `setup()` before adding this enemy to the tree.
var target: Node2D

@onready var _health: Health = $Health
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _contact: Hitbox = $ContactHitbox
@onready var _shape: CollisionShape2D = $CollisionShape2D

var _knockback: Vector2 = Vector2.ZERO


## Configure a freshly instanced enemy. Call before `add_child()` — `Health`
## seeds its hit points the moment it enters the tree.
func setup(chase_target: Node2D, speed: float, hit_points: int) -> void:
	target = chase_target
	max_speed = speed
	var health: Health = $Health
	health.max_health = hit_points


func _ready() -> void:
	_health.died.connect(_on_died)
	_hurtbox.hit_taken.connect(_on_hit_taken)


func _physics_process(delta: float) -> void:
	var desired := Vector2.ZERO
	if target != null and not _health.is_dead:
		var to_target := target.global_position - global_position
		if to_target.length() > stop_distance:
			desired = to_target.normalized() * max_speed

	velocity = accelerate(velocity, desired, delta)
	# Knockback rides on top of the chase velocity and bleeds off, so a hit
	# visibly shoves the slime and it walks the momentum off afterwards.
	velocity += _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, knockback_decay * delta)
	move_and_slide()


func _on_hit_taken(_amount: int, source: Node) -> void:
	var attacker := source as Node2D
	if attacker != null:
		_knockback = (global_position - attacker.global_position).normalized() * knockback_speed

	modulate = Color(1.6, 1.6, 1.6)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.18)


func _on_died(_source: Node) -> void:
	defeated.emit(self)

	# This runs inside the Hurtbox's collision callback, so every collision
	# change has to wait for the physics flush.
	_contact.set_deferred("active", false)
	_hurtbox.set_deferred("monitoring", false)
	_shape.set_deferred("disabled", true)
	set_physics_process(false)

	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.35)
	fade.tween_callback(queue_free)
