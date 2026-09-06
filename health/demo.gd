extends Node2D

## Standalone playground for the `health` module. Not part of the reusable
## module — it wires a movable dummy (`Health` + `Hurtbox` + `HealthBar`)
## against spinning `Hitbox` hazards and destructible target dummies, plus a
## fired one-shot projectile, so the damage flow and signals are easy to watch.

const _PLAYER_SPEED: float = 260.0
const _PROJECTILE_SPEED: float = 520.0
const _GRID_EXTENT: int = 1200
const _GRID_STEP: int = 100

var _player: CharacterBody2D
var _health: Health
var _label: Label
var _projectiles: Array[Hitbox] = []


func _ready() -> void:
	_label = $HUD/Label
	_build_player()
	_build_hazards()
	_build_targets()
	_refresh_label()


func _draw() -> void:
	var line := Color(1, 1, 1, 0.06)
	for x in range(-_GRID_EXTENT, _GRID_EXTENT + 1, _GRID_STEP):
		draw_line(Vector2(x, -_GRID_EXTENT), Vector2(x, _GRID_EXTENT), line)
	for y in range(-_GRID_EXTENT, _GRID_EXTENT + 1, _GRID_STEP):
		draw_line(Vector2(-_GRID_EXTENT, y), Vector2(_GRID_EXTENT, y), line)


func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		dir.y += 1.0
	_player.velocity = dir.normalized() * _PLAYER_SPEED
	_player.move_and_slide()

	for proj in _projectiles.duplicate():
		proj.position += Vector2(proj.get_meta("velocity")) * delta
		proj.set_meta("life", float(proj.get_meta("life")) - delta)
		if float(proj.get_meta("life")) <= 0.0:
			_forget_projectile(proj)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_SPACE:
			_fire()
		KEY_R:
			_health.revive()


func _build_player() -> void:
	_player = CharacterBody2D.new()
	add_child(_player)

	_health = Health.new()
	_health.max_health = 100
	_player.add_child(_health)
	_health.health_changed.connect(func(_c: int, _m: int) -> void: _refresh_label())
	_health.died.connect(func(_s: Node) -> void: _refresh_label())
	_health.revived.connect(_refresh_label)

	var body := Polygon2D.new()
	body.polygon = _square(18.0)
	body.color = Color(0.4, 0.7, 1.0)
	_player.add_child(body)

	var hurt := Hurtbox.new()
	hurt.hit_cooldown = 0.5
	_add_circle(hurt, 20.0)
	_player.add_child(hurt)
	hurt.hit_taken.connect(_on_player_hit)

	var bar := HealthBar.new()
	bar.size = Vector2(80, 10)
	bar.position = Vector2(-40, -44)
	bar.drain_speed = 6.0
	_player.add_child(bar)
	bar.set_health(_health)


func _build_hazards() -> void:
	_add_spinner(Vector2(-260, 0), 120.0, 1.4)
	_add_spinner(Vector2(300, 140), 96.0, -2.1)


func _add_spinner(at: Vector2, arm: float, angular_speed: float) -> void:
	var pivot := Node2D.new()
	pivot.position = at
	add_child(pivot)

	var spin := create_tween().set_loops()
	spin.tween_property(pivot, "rotation", TAU * signf(angular_speed), TAU / absf(angular_speed)).from(0.0)

	var hit := Hitbox.new()
	hit.damage = 12
	hit.position = Vector2(arm, 0)
	_add_circle(hit, 22.0)
	pivot.add_child(hit)

	var vis := Polygon2D.new()
	vis.polygon = _square(16.0)
	vis.color = Color(1.0, 0.45, 0.4)
	hit.add_child(vis)


func _build_targets() -> void:
	_spawn_target(Vector2(-40, -320))
	_spawn_target(Vector2(200, -260))


func _spawn_target(at: Vector2) -> void:
	var target := Node2D.new()
	target.position = at
	add_child(target)

	var health := Health.new()
	health.max_health = 50
	target.add_child(health)

	var vis := Polygon2D.new()
	vis.polygon = _square(14.0)
	vis.color = Color(0.7, 0.85, 0.5)
	target.add_child(vis)

	var hurt := Hurtbox.new()
	_add_circle(hurt, 16.0)
	target.add_child(hurt)

	var bar := HealthBar.new()
	bar.size = Vector2(60, 7)
	bar.position = Vector2(-30, -30)
	target.add_child(bar)
	bar.set_health(health)

	health.died.connect(func(_s: Node) -> void:
		vis.color = Color(0.3, 0.3, 0.3)
		get_tree().create_timer(1.5).timeout.connect(func() -> void:
			health.revive()
			vis.color = Color(0.7, 0.85, 0.5)))


func _fire() -> void:
	if _health.is_dead:
		return
	var dir := (get_global_mouse_position() - _player.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	var proj := Hitbox.new()
	proj.damage = 25
	proj.one_shot = true
	proj.active = false  # armed a beat later so it can clear the player's hurtbox
	proj.global_position = _player.global_position + dir * 24.0
	proj.set_meta("velocity", dir * _PROJECTILE_SPEED)
	proj.set_meta("life", 2.0)
	_add_circle(proj, 7.0)

	var vis := Polygon2D.new()
	vis.polygon = _square(5.0)
	vis.color = Color(1.0, 0.9, 0.4)
	proj.add_child(vis)
	proj.hit_landed.connect(func(_t: Node) -> void: _forget_projectile(proj))

	add_child(proj)
	_projectiles.append(proj)
	get_tree().create_timer(0.05).timeout.connect(func() -> void:
		if is_instance_valid(proj):
			proj.active = true)


func _forget_projectile(proj: Hitbox) -> void:
	if _projectiles.has(proj):
		_projectiles.erase(proj)
		proj.queue_free()


func _on_player_hit(_amount: int, _source: Node) -> void:
	_player.modulate = Color(1.0, 0.5, 0.5)
	create_tween().tween_property(_player, "modulate", Color.WHITE, 0.25)


func _refresh_label() -> void:
	var state := "DEAD — press R to revive" if _health.is_dead \
		else "%d / %d HP" % [_health.current_health, _health.max_health]
	_label.text = "WASD move   ·   SPACE fire projectile   ·   R revive          %s" % state


func _add_circle(area: Area2D, radius: float) -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)


func _square(half: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half),
	])
