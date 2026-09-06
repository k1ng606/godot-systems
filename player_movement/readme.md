# player_movement

Three drop-in 2D character controllers, each a `CharacterBody2D` scene. They
share `mover.gd` (`class_name Mover`) for the common speed / acceleration
tuning, so copy the whole folder.

| Scene | class_name | Input | Notes |
| --- | --- | --- | --- |
| `platformer_mover.tscn` | `PlatformerMover` | A/D + Space | Coyote time, jump buffer, variable jump height, air control. |
| `topdown_mover.tscn` | `TopDownMover` | WASD | Four- or eight-way (`eight_way`), optional facing. |
| `click_to_move_mover.tscn` | `ClickToMoveMover` | Mouse | Paths via a `NavigationAgent2D`; needs a baked `NavigationRegion2D` in the scene. |

All input is read from hardware keys / mouse buttons, so there are no InputMap
requirements. Tuning is exposed with `@export` on each root node.

`demo.tscn` is a combined playground — press 1 / 2 / 3 to switch modes. It bakes
the click-to-move navigation mesh in code (`demo.gd`), which is one way to set
up `ClickToMoveMover` without an editor bake step.
