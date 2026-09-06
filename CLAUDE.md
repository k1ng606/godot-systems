# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

A library of modular, reusable **2D** Godot features. Each feature is developed here in isolation so it can be dropped into other projects.

## Architecture constraint

- Each feature lives in its own top-level folder as a standalone scene (e.g. `inventory/`, `rts_camera/`, `player_movement/`).
- A feature must be **self-contained**: no dependencies on other feature folders, no reliance on project-wide autoloads/singletons or input actions that aren't defined within the feature's own folder. It should work when its folder is copied into an unrelated project.
- If a feature needs configuration (input maps, layers, settings), expose it on the scene's root node via `@export` rather than reaching into global project settings.
- Prefer reading hardware keys/mouse (`Input.is_physical_key_pressed`, `InputEventMouse*`) over named input actions, so a module carries no InputMap requirements.

## Module layout

Each module folder contains:

- `<module>.gd` — the reusable root script, with a `class_name`.
- `<module>.tscn` — the scene other projects instance.
- `demo.gd` / `demo.tscn` — a self-contained demo (grid, landmarks, sample content) exercising the module. Demos may use throwaway nodes and are not held to the "reusable" bar, but must still stay within the module folder.
- Committed `.uid` files for each script (Godot 4.7 generates these; keep them tracked).

`project.godot`'s `run/main_scene` points at the demo of whichever module is currently being worked on — update it when switching focus.

## Code style

- **Readability first.** Write for the next person dropping this module into an unfamiliar project: clear names, small focused functions, a short comment where intent isn't obvious from the code. Follow idiomatic Godot 4 / GDScript practice and engine conventions unless there's a stated reason not to.
- Godot 4.7, GDScript, **statically typed**. Annotate every variable, function parameter, and return type. Use `:=` for locals whose type is obvious from the right-hand side; otherwise write the type explicitly.
- Give reusable scene root scripts a `class_name` so other projects can reference them without preload paths.
- Document the root script with a `##` class doc comment (what it does, that it's self-contained, how to drop it in) and a `##` comment on every `@export`. Group related exports with `@export_group`.
- Private helpers and fields are prefixed `_`.

## Modules

| Module | Status | Notes |
| --- | --- | --- |
| `rts_camera` | Built | Top-down RTS-style camera: keyboard/edge/drag pan, cursor-anchored zoom, optional world bounds. `RTSCamera extends Camera2D`. |
| `player_movement` | Built | Side-scroller, 4/8-way, and RTS click-to-move. Three `CharacterBody2D` scenes sharing `Mover`; click-to-move steers via `NavigationAgent2D`. |
| `inventory` | Built | Fixed NxM slot grid. `InventoryData extends Resource` (stacks, add/take/drop/swap/sort + `slot_changed`/`changed` signals) drives `InventoryView extends PanelContainer`, a drag-and-drop grid with Shift-to-split, merge/swap on drop, tooltips, and cross-inventory transfer. Items are `ItemType` resources (`inventory/items/`). |
