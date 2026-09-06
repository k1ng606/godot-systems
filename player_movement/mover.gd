class_name Mover
extends CharacterBody2D

## Base for the player_movement controllers. Holds the tuning every mode shares
## — top speed, and how fast velocity ramps toward or away from its target —
## plus a frame-rate-independent accelerator built on `Vector2.move_toward`.
##
## Not meant to be instanced directly; use PlatformerMover, TopDownMover or
## ClickToMoveMover. Every mode reads the keyboard or mouse through `Input` /
## `_unhandled_input`, so the module needs no InputMap actions.

## Target speed, in pixels per second, at full input.
@export var max_speed: float = 320.0
## Speed gained per second while accelerating toward the target velocity.
@export var acceleration: float = 2400.0
## Speed shed per second while braking toward a stop.
@export var deceleration: float = 2600.0


## Step `current_velocity` toward `desired_velocity`, using `acceleration` when
## there is somewhere to go and `deceleration` when braking. The step scales
## with `delta`, so the outcome is the same at any frame rate.
func accelerate(current_velocity: Vector2, desired_velocity: Vector2, delta: float) -> Vector2:
	var braking := desired_velocity.length_squared() <= 1.0
	var rate := deceleration if braking else acceleration
	return current_velocity.move_toward(desired_velocity, rate * delta)
