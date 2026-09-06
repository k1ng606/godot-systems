# health

A drop-in 2D hit-point system: a `Health` component, a `Hitbox` / `Hurtbox`
Area2D pair that routes collisions into it, and a `HealthBar` that shows it.
Copy the whole `health/` folder — nothing here touches project settings, input
actions or autoloads.

| Script | class_name | Extends | Role |
| --- | --- | --- | --- |
| `health.gd` | `Health` | `Node` | Hit points + signals. `damage()` / `heal()` / `kill()` / `revive()` / `set_max_health()`; emits `health_changed`, `damaged`, `healed`, `died`, `revived`. |
| `hurtbox.gd` | `Hurtbox` | `Area2D` | The "can be hit" volume. Auto-finds the body's `Health` (or set `health_path`); applies an overlapping `Hitbox`'s damage, with an optional per-source `hit_cooldown`. `apply()` deals collision-free damage. Emits `hit_taken`. |
| `hitbox.gd` | `Hitbox` | `Area2D` | The "deals damage" volume. `damage`, `source`, `one_shot`, `active`. Emits `hit_landed`. |
| `health_bar.gd` (`health_bar.tscn`) | `HealthBar` | `Control` | Binds to a `Health` via `health_path` or `set_health()`; trailing-chip drain, low-health colour, optional hide-when-full. |

## Drop-in

1. Add a `Health` node under the entity and set `max_health`.
2. Add a `Hurtbox` under the same entity with a `CollisionShape2D`. It finds the
   sibling `Health` automatically.
3. Give attacks/projectiles/hazards a `Hitbox` with a `CollisionShape2D` and a
   `damage` value. Set the two areas' `collision_layer` / `collision_mask` so
   hurtboxes see hitboxes.
4. Optionally instance `health_bar.tscn` and call `set_health()` (or set
   `health_path`).

Non-collision damage (DoT, fall damage, scripted hits) goes through
`Hurtbox.apply(amount, source)` or `Health.damage(amount, source)` directly.

`demo.tscn` is a playground — a movable dummy against spinning hazards and
destructible targets, plus `SPACE` to fire a one-shot projectile and `R` to
revive. Not part of the reusable module.

## Tests

```
godot --headless --path . --script res://health/tests/test_health.gd
```

Framework-free `SceneTree` script; exit code 0 on success.
