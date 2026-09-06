extends SceneTree

## Headless test runner for the `health` module.
##
## Exercises `Health` in isolation plus the `Hitbox` -> `Hurtbox` -> `Health`
## collision path and the `HealthBar` binding. No test framework dependency — it
## is a plain `SceneTree` script. Run from the project root:
##
##   godot --headless --path . --script res://health/tests/test_health.gd
##
## Exit code is 0 when every check passes and 1 otherwise, so it drops straight
## into CI.

var _checks: int = 0
var _failures: int = 0
var _suite: String = ""


func _initialize() -> void:
	_run()


func _run() -> void:
	_suite_init()
	_suite_damage()
	_suite_heal()
	_suite_death()
	_suite_revive()
	_suite_max_health()
	_suite_signals()
	await _suite_hitbox_hurtbox()
	await _suite_health_bar()

	print("\n%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


# --- Health -----------------------------------------------------------------


func _suite_init() -> void:
	_begin("Health init")

	var full: Health = _mk_health(80)
	_check_eq(full.current_health, 80, "start_full fills to max_health")
	_check(not full.is_dead, "a full health is not dead")
	full.free()

	var partial: Health = _mk_health(100, false, 40)
	_check_eq(partial.current_health, 40, "starting_health seeds current when start_full is off")
	partial.free()

	var over: Health = _mk_health(50, false, 999)
	_check_eq(over.current_health, 50, "starting_health clamps to max_health")
	over.free()

	var zero: Health = _mk_health(50, false, 0)
	_check(zero.is_dead, "starting at 0 health is dead from the start")
	zero.free()


func _suite_damage() -> void:
	_begin("Health.damage")

	var hp: Health = _mk_health(100)
	_check_eq(hp.damage(30), 30, "damage returns the amount removed")
	_check_eq(hp.current_health, 70, "damage subtracts from current")
	_check_eq(hp.damage(999), 70, "damage clamps at 0 and returns only what was removed")
	_check_eq(hp.current_health, 0, "current bottoms out at 0")
	hp.free()

	var hp2: Health = _mk_health(100)
	_check_eq(hp2.damage(0), 0, "zero damage is a no-op")
	_check_eq(hp2.damage(-5), 0, "negative damage is a no-op")
	_check_eq(hp2.current_health, 100, "no-op damage leaves health untouched")
	hp2.kill()
	_check_eq(hp2.damage(20), 0, "damage after death is a no-op")
	hp2.free()


func _suite_heal() -> void:
	_begin("Health.heal")

	var hp: Health = _mk_health(100)
	hp.damage(60)
	_check_eq(hp.heal(25), 25, "heal returns the amount restored")
	_check_eq(hp.current_health, 65, "heal adds to current")
	_check_eq(hp.heal(999), 35, "heal clamps at max_health and returns only what fit")
	_check_eq(hp.current_health, 100, "current tops out at max_health")
	_check_eq(hp.heal(0), 0, "zero heal is a no-op")
	_check_eq(hp.heal(-5), 0, "negative heal is a no-op")
	hp.kill()
	_check_eq(hp.heal(50), 0, "heal does not resurrect the dead")
	_check(hp.is_dead, "still dead after a heal attempt")
	hp.free()


func _suite_death() -> void:
	_begin("Health death & kill")

	var attacker: Node = Node.new()
	root.add_child(attacker)

	var hp: Health = _mk_health(100)
	var deaths: Array = []
	hp.died.connect(func(s: Node) -> void: deaths.append(s))

	hp.damage(40, attacker)
	_check(not hp.is_dead, "not dead above 0")
	hp.damage(80, attacker)
	_check(hp.is_dead, "dead when damage takes health to 0")
	_check_eq(deaths.size(), 1, "died fires exactly once")
	_check(deaths[0] == attacker, "died carries the damage source")
	hp.damage(10, attacker)
	_check_eq(deaths.size(), 1, "further damage does not re-fire died")
	hp.free()

	var hp2: Health = _mk_health(30)
	hp2.kill()
	_check(hp2.is_dead, "kill() drops the target")
	_check_eq(hp2.current_health, 0, "kill() empties health")
	hp2.free()

	attacker.free()


func _suite_revive() -> void:
	_begin("Health.revive")

	var hp: Health = _mk_health(100)
	var revives: Array = []
	hp.revived.connect(func() -> void: revives.append(true))

	hp.revive()
	_check(revives.is_empty(), "revive on a living target is a no-op")

	hp.kill()
	hp.revive()
	_check(not hp.is_dead, "revive clears the dead state")
	_check_eq(hp.current_health, 100, "revive with no argument restores full health")
	_check_eq(revives.size(), 1, "revive emits revived")
	_check_eq(hp.damage(10), 10, "the target takes damage again after reviving")

	hp.kill()
	hp.revive(150)
	_check_eq(hp.current_health, 100, "revive clamps its argument to max_health")

	hp.kill()
	hp.revive(0)
	_check_eq(hp.current_health, 1, "revive floors its argument at 1 so it doesn't come back dead")
	hp.free()


func _suite_max_health() -> void:
	_begin("Health.set_max_health")

	var hp: Health = _mk_health(100)
	hp.set_max_health(60)
	_check_eq(hp.max_health, 60, "max_health updates")
	_check_eq(hp.current_health, 60, "current re-clamps into the smaller range")
	hp.free()

	var hp2: Health = _mk_health(100)
	hp2.damage(50)  # sitting at half
	hp2.set_max_health(200, true)
	_check_eq(hp2.max_health, 200, "scaled max_health updates")
	_check_eq(hp2.current_health, 100, "scale_current preserves the health fraction")
	hp2.free()


func _suite_signals() -> void:
	_begin("Health signals")

	var hp: Health = _mk_health(100)
	var changes: Array = []
	var dmg: Array = []
	var heals: Array = []
	hp.health_changed.connect(func(c: int, m: int) -> void: changes.append([c, m]))
	hp.damaged.connect(func(a: int, _s: Node) -> void: dmg.append(a))
	hp.healed.connect(func(a: int) -> void: heals.append(a))

	hp.damage(30)
	_check(changes.has([70, 100]), "damage emits health_changed with the new pair")
	_check(dmg == [30], "damage emits damaged with the amount removed")

	hp.heal(10)
	_check(heals == [10], "heal emits healed with the amount restored")
	_check(changes.has([80, 100]), "heal emits health_changed")

	hp.heal(999)  # top back up to full
	changes.clear()
	hp.heal(5)
	_check(changes.is_empty(), "healing at full is a no-op with no signal")

	changes.clear()
	hp.set_max_health(200)
	_check(changes == [[100, 200]], "set_max_health emits health_changed with the new max")
	hp.free()


# --- Hitbox / Hurtbox / HealthBar ----------------------------------------


func _suite_hitbox_hurtbox() -> void:
	_begin("Hitbox -> Hurtbox -> Health")

	var body: Node2D = Node2D.new()
	root.add_child(body)
	var hp: Health = Health.new()
	hp.max_health = 100
	body.add_child(hp)
	var hurt: Hurtbox = Hurtbox.new()
	hurt.hit_cooldown = 0.2
	_add_shape(hurt, 16.0)
	body.add_child(hurt)

	var hit: Hitbox = Hitbox.new()
	hit.damage = 15
	_add_shape(hit, 16.0)
	root.add_child(hit)
	hit.global_position = body.global_position
	await _physics(3)
	_check_eq(hp.current_health, 85, "an overlapping hitbox removes its damage once")

	# Re-entering within the cooldown window is ignored.
	await _reenter(hit, body.global_position)
	_check_eq(hp.current_health, 85, "a second hit inside hit_cooldown is ignored")

	# ...but lands again once the cooldown has elapsed.
	OS.delay_msec(220)
	await _reenter(hit, body.global_position)
	_check_eq(hp.current_health, 70, "the hit lands again after hit_cooldown elapses")

	# Direct, collision-free damage through the same path.
	var taken: Array = []
	hurt.hit_taken.connect(func(a: int, _s: Node) -> void: taken.append(a))
	hurt.apply(10)
	_check_eq(hp.current_health, 60, "apply() deals damage directly")
	_check(taken == [10], "apply() emits hit_taken")

	body.free()
	hit.free()

	# one_shot projectile disarms itself after the first hit.
	var body2: Node2D = Node2D.new()
	root.add_child(body2)
	var hp2: Health = Health.new()
	hp2.max_health = 100
	body2.add_child(hp2)
	var hurt2: Hurtbox = Hurtbox.new()
	_add_shape(hurt2, 16.0)
	body2.add_child(hurt2)

	var proj: Hitbox = Hitbox.new()
	proj.damage = 25
	proj.one_shot = true
	_add_shape(proj, 16.0)
	root.add_child(proj)
	proj.global_position = body2.global_position
	await _physics(3)
	await _frames(1)  # deferred disarm
	_check_eq(hp2.current_health, 75, "one_shot projectile hits once")
	_check(not proj.active, "one_shot projectile disarms after its hit")
	_check(not proj.monitoring, "one_shot projectile stops monitoring")

	body2.free()
	proj.free()


func _suite_health_bar() -> void:
	_begin("HealthBar")

	var hp: Health = _mk_health(100)

	var bar: HealthBar = HealthBar.new()
	bar.size = Vector2(100, 10)
	bar.drain_speed = 0.0
	root.add_child(bar)
	bar.set_health(hp)
	_check_eq(bar._target_fraction, 1.0, "bar starts full")

	hp.damage(40)
	_check(is_equal_approx(bar._target_fraction, 0.6), "target fraction follows health_changed")
	await _frames(1)
	_check(is_equal_approx(bar._display_fraction, 0.6), "drain_speed 0 snaps the display fraction")

	var hidden: HealthBar = HealthBar.new()
	hidden.hide_when_full = true
	root.add_child(hidden)
	hidden.set_health(hp)
	_check(hidden.visible, "hide_when_full keeps the bar visible below full")
	hp.heal(100)
	_check(not hidden.visible, "hide_when_full hides the bar at full health")

	bar.free()
	hidden.free()
	hp.free()


# --- helpers -------------------------------------------------------------


func _begin(name: String) -> void:
	_suite = name
	print("\n[%s]" % name)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)


func _check_eq(actual: Variant, expected: Variant, label: String) -> void:
	_check(actual == expected, "%s (got %s, want %s)" % [label, actual, expected])


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _physics(count: int) -> void:
	for _i in count:
		await physics_frame


# Move an area well clear of the target, let the overlap end, then bring it back.
func _reenter(area: Area2D, at: Vector2) -> void:
	area.global_position = at + Vector2(2000, 0)
	await _physics(2)
	area.global_position = at
	await _physics(3)


func _mk_health(max_hp: int, full: bool = true, starting: int = -1) -> Health:
	var h: Health = Health.new()
	h.max_health = max_hp
	h.start_full = full
	if starting >= 0:
		h.start_full = false
		h.starting_health = starting
	root.add_child(h)
	# `_ready` propagation is deferred until the main loop starts ticking, which
	# is after `_initialize()` runs; seed the state now so the sync suites can
	# poke at a fresh component. In-game `_ready`/`_enter_tree` do this for you.
	h._initialize_state()
	return h


func _add_shape(area: Area2D, radius: float) -> void:
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
