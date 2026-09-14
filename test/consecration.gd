extends SceneTree
## Combat-facing acceptance checks, including burn balance and no hit-stun.

var game: Node3D
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	print("%s: %s" % ["PASS" if value else "FAIL", message])
	if not value:
		failures += 1

func ticks(count := 2) -> void:
	for i in range(count):
		await physics_frame

func run() -> void:
	game = load("res://scenes/ember.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.auto_control = true
	game.record_results = false
	game.sound_enabled = false
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	for enemy in game.enemies:
		enemy.set_physics_process(false)
	game.player.position = Vector3.ZERO
	game.player.hp = 50
	var close: CharacterBody3D = game.enemies[0]
	var outside: CharacterBody3D = game.enemies[1]
	close.position = Vector3(1.5, 0, 0)
	outside.position = Vector3(3.1, 0, 0)
	game.enemies[2].position = Vector3(0, 0, -8)
	var ally_settings: Dictionary = game.settings.hero.duplicate(true)
	ally_settings.health = 200
	var ally: CharacterBody3D = game.spawn(ally_settings, Vector3(-1.5, 0, 0), false)
	ally.hp = 100
	ally.set_physics_process(false)
	await ticks()
	var skill: Node3D = game.consecration
	skill.rng.seed = 71
	check(InputMap.action_get_events("consecrate")[0].physical_keycode == KEY_Q, "Q is bound to Consecration")
	check(skill.cast(), "a living player can cast a ready skill")
	check(skill.cooldown_remaining == 18 and skill.active_remaining == 6 and skill.pulse_count == 0, "cast starts an 18-second cooldown and a six-second field with no instant tick")
	check(not skill.cast() and skill.casts == 1, "repeated casts cannot stack fields or reset cooldown")
	skill.advance(0.99)
	check(game.player.hp == 50 and close.hp == 50 and ally.hp == 100, "no healing or burning before the first full second")
	skill.advance(0.01)
	check(game.player.hp == 54 and ally.hp == 108, "each ally heals for 4% of their own maximum health")
	check(close.hp >= 42 and close.hp <= 44 and outside.hp == 50, "inside enemy burns for 6–8; an enemy beyond three metres is untouched")
	check(not skill.affects(outside), "the radius does not grow to include actor collision capsules")
	var origin: Vector3 = skill.global_position
	game.player.position = Vector3(3.5, 0, 0)
	outside.position = Vector3(2.0, 0, 1.0)
	var wall: Node3D = game.box("ConsecrationTestWall", Vector3(-0.75, 0.9, 0), Vector3(0.2, 1.8, 2.0), Color.GRAY, true)
	await ticks()
	close.attack_time = 0.30
	close.stagger = 0
	close.cooldown = 0
	close.visual.play(close.config.attack)
	skill.advance(1.0)
	check(skill.global_position == origin and skill.center == origin, "the field stays at the cast location when the player moves")
	check(game.player.hp == 54 and ally.hp == 108, "leaving the circle or standing behind a wall stops healing")
	check(outside.hp < 50, "an enemy entering an existing field burns on its next tick")
	check(close.attack_time == 0.30 and close.stagger == 0 and close.cooldown == 0 and close.visual.current_clip == close.config.attack, "burning does not interrupt attack windup, reset clips, or apply hit-stun")
	wall.queue_free()
	game.player.position = Vector3(0, 0, 0.2)
	ally.hp = 199
	await ticks()
	skill.advance(1.0)
	check(game.player.hp == 58 and ally.hp == 200, "returning resumes healing without exceeding maximum health")
	skill.advance(3.0)
	check(skill.pulse_count == 6 and skill.active_remaining == 0, "large frame steps still produce exactly six pulses")
	check(close.hp >= 2 and close.hp <= 14 and not close.dead, "even maximum luck cannot kill a full-health 50-HP skeleton with one field")
	check(game.player.hp == 70 and ally.hp == 200, "missed healing ticks are not paid back on return")
	var total: int = skill.total_damage
	skill.advance(0.5)
	check(skill.pulse_count == 6 and skill.total_damage == total, "expiry has no seventh tick or lingering damage")
	check(not skill.cast(), "the twelve-second recovery after expiry cannot be skipped")
	game.toggle_pause()
	var remaining: float = skill.cooldown_remaining
	var age: float = skill.field.age
	skill.advance(5)
	check(skill.cooldown_remaining == remaining and skill.field.age == age and not skill.cast(), "pause freezes cooldown and visual time and prevents casting")
	game.toggle_pause()
	skill.advance(11.5)
	check(is_zero_approx(skill.cooldown_remaining) and skill.cast(), "a second cast becomes available exactly eighteen seconds after the first")
	# Pick a deterministic lucky roll while leaving the runtime 12% rule intact.
	var lucky_seed := -1
	for candidate in range(100):
		var probe := RandomNumberGenerator.new()
		probe.seed = candidate
		if probe.randf() < 0.12:
			lucky_seed = candidate
			break
	check(lucky_seed >= 0, "deterministic lucky-hit fixture exists")
	skill.rng.seed = lucky_seed
	close.hp = 50
	close.position = Vector3(1.5, 0, 0)
	outside.position = Vector3(6, 0, 0)
	await ticks()
	skill.advance(1.0)
	check(close.hp == 42 and skill.lucky_hits > 0, "a lucky pulse adds exactly two damage, without amplifying healing")
	ally.take_damage(999)
	check(ally.dead and game.kills == 0 and not skill.affects(ally), "fallen allies are not healed, resurrected, or counted as enemy kills")
	close.hp = 6
	skill.advance(1.0)
	check(close.dead and close.collision_layer == 0 and game.kills == 1, "a lethal burn uses normal death collision cleanup and kill accounting")
	skill.advance(1.0)
	check(game.kills == 1, "dead targets cannot pay out additional kills")
	game.player.take_damage(999)
	check(game.ended and skill.active_remaining == 0 and not skill.field.visible and not skill.cast(), "death immediately cancels the field and prevents further casts")
	game.restart()
	await ticks(5)
	game = current_scene
	game.record_results = false
	game.sound_enabled = false
	check(game.consecration.cooldown_remaining == 0 and game.consecration.casts == 0 and not game.consecration.field.visible, "restart clears cooldown, area, and per-run skill state")
	Input.action_press("consecrate")
	await ticks(120)
	check(game.consecration.casts == 1 and game.consecration.cooldown_remaining > 15, "normal gameplay input casts once when Q is held")
	Input.action_release("consecrate")
	game.toggle_pause()
	var active_before: float = game.consecration.active_remaining
	var cooldown_before: float = game.consecration.cooldown_remaining
	await ticks(60)
	check(game.consecration.active_remaining == active_before and game.consecration.cooldown_remaining == cooldown_before, "the real pause flow freezes active healing, damage, and cooldown")
	game.toggle_pause()
	game.return_menu()
	await ticks(5)
	check(current_scene.has_node("MeleeCourtyard"), "return to menu still works after casting and pausing")
	current_scene.queue_free()
	current_scene = null
	game = null
	await ticks(3)
	print("CONSECRATION COMPLETE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
