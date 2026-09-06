# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

A library of modular, reusable **2D** Godot features. Each feature is developed here in isolation so it can be dropped into other projects.

## Architecture constraint

- Each feature lives in its own top-level folder as a standalone scene (e.g. `inventory/`, `rts_camera/`, `player_movement/`).
- A feature must be **self-contained**: no dependencies on other feature folders, no reliance on project-wide autoloads/singletons or input actions that aren't defined within the feature's own folder. It should work when its folder is copied into an unrelated project.
- If a feature needs configuration (input maps, layers, settings), expose it on the scene's root node via `@export` rather than reaching into global project settings.

## Code style

- Godot 4.7, GDScript, **statically typed**. Annotate every variable, function parameter, and return type. Use `:=` for locals whose type is obvious from the right-hand side; otherwise write the type explicitly.
- Give reusable scene root scripts a `class_name` so other projects can reference them without preload paths.

## Planned modules

- `inventory`
- `rts_camera` — top-down RTS-style camera
- `player_movement` — side-scroller, 4/8-way, and RTS click-to-move (with obstacle avoidance)
