class_name DemoLauncher
extends Control

## Splash screen that lists every demo in the repository and switches the running
## scene to the one you pick. Self-contained: it depends only on scene paths, so
## it lives outside the module folders (like `game/`) and is wired up as
## `run/main_scene`. The whole UI is built in code to keep the scene file tiny.
##
## Drop-in note: this is a workbench entry point, not a reusable module. Copying a
## single module folder into another project does not need this file.

## One launchable demo: a display name, a short blurb and the scene to load.
class DemoEntry:
	var name: String
	var blurb: String
	var scene_path: String

	func _init(p_name: String, p_blurb: String, p_scene_path: String) -> void:
		name = p_name
		blurb = p_blurb
		scene_path = p_scene_path


## Categories shown top to bottom, each with its own list of demos.
var _catalog: Array = [
	{
		"title": "Modules",
		"demos": [
			DemoEntry.new(
				"RTS Camera",
				"Top-down camera: keyboard / edge / drag pan, cursor-anchored zoom, optional world bounds.",
				"res://rts_camera/demo.tscn"),
			DemoEntry.new(
				"Player Movement",
				"Side-scroller, 8-way top-down and click-to-move controllers. Press 1 / 2 / 3 to switch.",
				"res://player_movement/demo.tscn"),
			DemoEntry.new(
				"Inventory",
				"NxM slot grid with drag-and-drop, Shift-to-split, merge / swap on drop and cross-inventory transfer.",
				"res://inventory/demo.tscn"),
			DemoEntry.new(
				"Health",
				"Hit-point component with hitbox / hurtbox pair and a trailing-drain health bar.",
				"res://health/demo.tscn"),
		],
	},
	{
		"title": "Demo games",
		"demos": [
			DemoEntry.new(
				"Gate Run",
				"Vertical slice wiring all four modules together: arena combat, loot, a bag and a gated exit.",
				"res://game/game.tscn"),
		],
	},
]

@onready var _title_font_size: int = 32


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.09, 0.10, 0.13)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)

	var heading := Label.new()
	heading.text = "godot-systems  ·  demo launcher"
	heading.add_theme_font_size_override("font_size", _title_font_size)
	column.add_child(heading)

	var hint := Label.new()
	hint.text = "Pick a demo to run.  Arrow keys / Tab to move, Enter to launch."
	hint.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74))
	column.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	var first_button: Button = null
	for category: Dictionary in _catalog:
		var section := Label.new()
		section.text = String(category["title"]).to_upper()
		section.add_theme_font_size_override("font_size", 16)
		section.add_theme_color_override("font_color", Color(0.55, 0.72, 0.95))
		list.add_child(_spacer(12))
		list.add_child(section)

		for demo: DemoEntry in category["demos"]:
			var button := _make_demo_button(demo)
			list.add_child(button)
			if first_button == null:
				first_button = button

	if first_button != null:
		first_button.grab_focus()


func _make_demo_button(demo: DemoEntry) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(0, 56)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = demo.scene_path
	button.pressed.connect(_launch.bind(demo))

	# Two-line label (name over blurb) laid out inside the button.
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.set_anchors_preset(Control.PRESET_FULL_RECT)
	rows.add_theme_constant_override("separation", 2)
	rows.offset_left = 12
	rows.offset_right = -12
	rows.offset_top = 8
	rows.offset_bottom = -8

	var name_label := Label.new()
	name_label.text = demo.name
	name_label.add_theme_font_size_override("font_size", 18)
	rows.add_child(name_label)

	var blurb_label := Label.new()
	blurb_label.text = demo.blurb
	blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb_label.add_theme_color_override("font_color", Color(0.66, 0.70, 0.78))
	rows.add_child(blurb_label)

	button.add_child(rows)
	return button


func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


func _launch(demo: DemoEntry) -> void:
	var result: int = get_tree().change_scene_to_file(demo.scene_path)
	if result != OK:
		push_error("DemoLauncher: could not load %s (error %d)" % [demo.scene_path, result])
