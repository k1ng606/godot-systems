extends Node2D

## "Gate Run" — a tiny vertical slice assembled from the library modules.
##
## Three waves of slimes spawn in a walled arena. Cut them down (`health`
## hitboxes and hurtboxes), walk over the loot they drop (`inventory`), and once
## the arena is clear pay the gatekeeper 10 gold to escape through the north
## gate. Movement is `player_movement`'s `TopDownMover`, and the view is an
## `rts_camera` configured as a follow-and-zoom camera.
##
## Demo code, not a module: it owns the arena, the wave pacing and the HUD, and
## is the only script here allowed to depend on every module folder at once.

const _PLAYER_SCENE: PackedScene = preload("res://game/player.tscn")
const _ENEMY_SCENE: PackedScene = preload("res://game/enemy.tscn")
const _PICKUP_SCENE: PackedScene = preload("res://game/pickup.tscn")
const _COIN: ItemType = preload("res://inventory/items/coin.tres")
const _POTION: ItemType = preload("res://inventory/items/potion.tres")

const _COIN_ID: StringName = &"coin"

# Playable floor; the walls are built just outside it.
const _ARENA: Rect2 = Rect2(-780.0, -500.0, 1560.0, 1000.0)
const _WALL_THICKNESS: float = 48.0
const _GATE_HALF_WIDTH: float = 90.0
const _GRID_STEP: int = 80

const _WAVE_SIZES: Array[int] = [3, 4, 5]
const _WAVE_GAP: float = 1.5
const _GATE_TOLL: int = 10

const _VOID_COLOR: Color = Color(0.07, 0.07, 0.09)
const _FLOOR_COLOR: Color = Color(0.13, 0.14, 0.17)
const _WALL_COLOR: Color = Color(0.22, 0.24, 0.3)
const _GATE_COLOR: Color = Color(0.72, 0.52, 0.2)

var _player: GamePlayer
var _gate_bar: StaticBody2D
var _living: Array[GameEnemy] = []
var _wave: int = 0
var _gate_open: bool = false
var _over: bool = false
var _rng := RandomNumberGenerator.new()

@onready var _status: Label = $HUD/Status
@onready var _shade: ColorRect = $HUD/Shade
@onready var _banner: Label = $HUD/Shade/Banner
@onready var _bag: InventoryView = $HUD/Bag
@onready var _bag_hint: Label = $HUD/BagHint
@onready var _player_bar: HealthBar = $HUD/PlayerBar


func _ready() -> void:
	_rng.randomize()
	_build_arena()
	_spawn_player()

	_bag.inventory = _player.inventory
	_player_bar.set_health(_player.health)
	_player.health.health_changed.connect(_on_player_health_changed)
	_player.health.died.connect(_on_player_died)
	_player.inventory.contents_changed.connect(_refresh_status)

	_start_wave()


func _process(_delta: float) -> void:
	if _over or not _gate_open:
		return
	if _gate_rect().has_point(_player.global_position):
		_try_escape()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return

	match key.physical_keycode:
		KEY_TAB, KEY_I:
			_bag.visible = not _bag.visible
			_bag_hint.visible = _bag.visible
		KEY_R:
			get_tree().reload_current_scene()


func _draw() -> void:
	# Void beyond the walls, so the arena reads as a room at any zoom.
	draw_rect(_ARENA.grow(1600.0), _VOID_COLOR)
	draw_rect(_ARENA, _FLOOR_COLOR)

	var line := Color(1, 1, 1, 0.05)
	for x in range(int(_ARENA.position.x), int(_ARENA.end.x) + 1, _GRID_STEP):
		draw_line(Vector2(x, _ARENA.position.y), Vector2(x, _ARENA.end.y), line)
	for y in range(int(_ARENA.position.y), int(_ARENA.end.y) + 1, _GRID_STEP):
		draw_line(Vector2(_ARENA.position.x, y), Vector2(_ARENA.end.x, y), line)

	if _gate_open:
		draw_rect(_gate_rect(), Color(_GATE_COLOR, 0.35))


# --- world -------------------------------------------------------------------


func _build_arena() -> void:
	var t := _WALL_THICKNESS
	var left := _ARENA.position.x
	var top := _ARENA.position.y
	var right := _ARENA.end.x
	var bottom := _ARENA.end.y

	_add_wall(Rect2(left - t, top - t, t, _ARENA.size.y + t * 2.0), _WALL_COLOR)
	_add_wall(Rect2(right, top - t, t, _ARENA.size.y + t * 2.0), _WALL_COLOR)
	_add_wall(Rect2(left - t, bottom, _ARENA.size.x + t * 2.0, t), _WALL_COLOR)

	# North wall, split around the gate doorway.
	_add_wall(Rect2(left - t, top - t, -_GATE_HALF_WIDTH - (left - t), t), _WALL_COLOR)
	_add_wall(Rect2(_GATE_HALF_WIDTH, top - t, right + t - _GATE_HALF_WIDTH, t), _WALL_COLOR)

	# The doorway itself is barred until the arena is cleared.
	_gate_bar = _add_wall(_gate_rect(), _GATE_COLOR)


func _add_wall(rect: Rect2, color: Color) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.position = rect.position + rect.size * 0.5
	add_child(wall)

	var box := RectangleShape2D.new()
	box.size = rect.size
	var shape := CollisionShape2D.new()
	shape.shape = box
	wall.add_child(shape)

	var vis := Polygon2D.new()
	var half := rect.size * 0.5
	vis.polygon = PackedVector2Array([
		-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y),
	])
	vis.color = color
	wall.add_child(vis)

	return wall


func _gate_rect() -> Rect2:
	return Rect2(
		-_GATE_HALF_WIDTH,
		_ARENA.position.y - _WALL_THICKNESS,
		_GATE_HALF_WIDTH * 2.0,
		_WALL_THICKNESS,
	)


func _spawn_player() -> void:
	_player = _PLAYER_SCENE.instantiate()
	_player.position = Vector2(0, 260)
	add_child(_player)


# --- waves -------------------------------------------------------------------


func _start_wave() -> void:
	if _over:
		return
	for i in _WAVE_SIZES[_wave]:
		_spawn_enemy()
	_refresh_status()


func _spawn_enemy() -> void:
	var enemy: GameEnemy = _ENEMY_SCENE.instantiate()
	# Later waves are a little faster and a little tougher.
	enemy.setup(_player, 105.0 + _wave * 18.0, 40 + _wave * 12)
	enemy.position = _spawn_point()
	enemy.defeated.connect(_on_enemy_defeated)
	add_child(enemy)
	_living.append(enemy)


# A random floor position that isn't right on top of the player.
func _spawn_point() -> Vector2:
	var inset := _ARENA.grow(-90.0)
	var point := Vector2.ZERO
	for attempt in 16:
		point = Vector2(
			_rng.randf_range(inset.position.x, inset.end.x),
			_rng.randf_range(inset.position.y, inset.end.y),
		)
		if point.distance_to(_player.position) > 340.0:
			break
	return point


func _on_enemy_defeated(enemy: GameEnemy) -> void:
	_living.erase(enemy)
	# Deferred: this fires from inside a collision callback, and loot is an Area2D.
	_drop_loot.call_deferred(enemy.global_position)

	if not _living.is_empty() or _over:
		_refresh_status()
		return

	_wave += 1
	if _wave < _WAVE_SIZES.size():
		get_tree().create_timer(_WAVE_GAP).timeout.connect(_start_wave)
	else:
		_open_gate()
	_refresh_status()


func _drop_loot(at: Vector2) -> void:
	_spawn_pickup(_COIN, _rng.randi_range(1, 3), at + _scatter())
	if _rng.randf() < 0.35:
		_spawn_pickup(_POTION, 1, at + _scatter())


func _spawn_pickup(type: ItemType, amount: int, at: Vector2) -> void:
	var pickup: GamePickup = _PICKUP_SCENE.instantiate()
	pickup.item_type = type
	pickup.amount = amount
	pickup.attract_to = _player
	pickup.position = at
	add_child(pickup)


func _scatter() -> Vector2:
	return Vector2(_rng.randf_range(-26.0, 26.0), _rng.randf_range(-26.0, 26.0))


# --- outcomes ----------------------------------------------------------------


func _open_gate() -> void:
	_gate_open = true
	_gate_bar.queue_free()
	_gate_bar = null
	queue_redraw()


func _try_escape() -> void:
	# The toll is charged straight out of the bag, so the loot has to be carried
	# all the way to the gate.
	if _player.consume(_COIN_ID, _GATE_TOLL):
		_finish("ESCAPED\nPaid %d gold at the gate\n\nR to play again" % _GATE_TOLL)


func _on_player_died(_source: Node) -> void:
	_finish("YOU DIED\n\nR to try again")


func _finish(message: String) -> void:
	_over = true
	_banner.text = message
	_shade.visible = true
	for enemy in _living:
		if is_instance_valid(enemy):
			enemy.set_physics_process(false)
	_refresh_status()


# --- HUD ---------------------------------------------------------------------


func _on_player_health_changed(_current: int, _maximum: int) -> void:
	_refresh_status()


func _refresh_status() -> void:
	var gold: int = _player.count(_COIN_ID)
	var potions: int = _player.count(GamePlayer.POTION_ID)
	_status.text = "%s\n%d / %d HP   ·   %d gold   ·   %d %s\n%s" % [
		"WASD move  ·  LMB swing  ·  Q drink potion  ·  TAB bag  ·  R restart",
		_player.health.current_health,
		_player.health.max_health,
		gold,
		potions,
		"potion" if potions == 1 else "potions",
		_objective(gold),
	]


func _objective(gold: int) -> String:
	if _over:
		return "Press R to play again"
	if _gate_open:
		if gold >= _GATE_TOLL:
			return "Gate open — head north and pay the %d gold toll" % _GATE_TOLL
		return "Gate open — the gatekeeper wants %d gold, you have %d" % [_GATE_TOLL, gold]
	if _living.is_empty():
		return "Wave %d of %d incoming..." % [_wave + 1, _WAVE_SIZES.size()]
	return "Wave %d of %d — %d slimes left" % [_wave + 1, _WAVE_SIZES.size(), _living.size()]
