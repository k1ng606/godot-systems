# game — "Gate Run" vertical slice

A tiny playable proof of concept that wires every module in this repo together.
Run `game.tscn` (it is the project's current main scene).

**This folder is not a module.** Modules are self-contained and may never depend
on each other; this one deliberately depends on all four of them at once. Nothing
here should ever be imported by a module folder.

## The loop

1. Three waves of slimes (3, 4, then 5) spawn in a walled arena.
2. Swing at them; each one drops 1–3 gold and sometimes a potion.
3. Walk over loot to bag it. Drink potions when you're hurt.
4. Clear the last wave and the north gate unbars — step into it with at least
   10 gold and the gatekeeper takes the toll and lets you out.

Die and the run ends; `R` restarts either way.

| Key | Action |
| --- | --- |
| WASD | Move |
| Left mouse | Swing at the cursor |
| Mouse wheel | Zoom |
| Q | Drink a potion |
| TAB / I | Toggle the bag |
| R | Restart |

## What each module does here

| Module | Used for |
| --- | --- |
| `player_movement` | `GamePlayer extends TopDownMover` (WASD, 8-way). `GameEnemy extends Mover` and chases with the shared `accelerate()`. |
| `health` | `Health` + `Hurtbox` on the player and every slime; the slime's contact damage is a `Hitbox`; a `HealthBar` floats over each slime and another sits in the HUD. |
| `inventory` | `InventoryData` is the player's bag, filled by `GamePickup` from the shipped `coin` / `potion` `ItemType`s; the HUD's `InventoryView` renders it with drag, split and merge. |
| `rts_camera` | The camera, parented to the player with panning switched off (`pan_speed = 0`, no edge scroll, no drag) so it acts as a follow camera with mouse-wheel zoom — WASD belongs to the player here. |

## Physics layers

Modules take their layers from their own nodes, so the slice picks them:

| Layer (value) | Contents |
| --- | --- |
| 1 (1) | Solid bodies: walls, player, slimes |
| 2 (2) | Player hurtbox |
| 3 (4) | Slime contact hitbox |
| 4 (8) | Slime hurtbox |
| 6 (32) | Loot pickups (they watch layer 1 for the player) |

## Known module rough edge

`Hurtbox` only reacts to an overlap that *begins*. Arming a `Hitbox` that is
already sitting on top of a `Hurtbox` fires nothing, so a swing implemented as
"switch the box on for 0.12 s" misses any enemy already standing in the arc.
`GamePlayer.attack()` therefore uses a one-shot `intersect_shape()` query and
`Hurtbox.apply()` — the module's documented entry point for scripted hits — and
the slimes' always-on contact `Hitbox` covers the collision path instead. Worth
fixing inside `health/` if armed attack boxes ever become the norm.
