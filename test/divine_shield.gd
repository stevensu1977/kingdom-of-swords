extends SceneTree
## Damage-path, lifetime, pause, and real-input acceptance checks.

var game: Node3D
var failures := 0
var damage_signals := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	print("%s: %s" % ["PASS" if value else "FAIL", message])
	if not value:
		failures += 1

func ticks(count := 2) -> void:
	for i in range(count):
		await physics_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func run() -> void:
	game = load("res://scenes/ember.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.auto_control = true
	game.record_results = false
	game.sound_enabled = false
	game.set_physics_process(false)
	var actor: CharacterBody3D = game.player
	actor.set_physics_process(false)
	for enemy in game.enemies:
		enemy.set_physics_process(false)
		enemy.position = Vector3(7, 0, -8)
	actor.position = Vector3.ZERO
	actor.hp = 70
	actor.damaged.connect(func(_who, _amount): damage_signals += 1)
	await ticks()
	check(InputMap.action_get_events("divine_shield")[0].physical_keycode == KEY_F, "F is bound to Divine Shield without replacing Q or dodge")
	check(actor.shielded == 0 and actor.shield_cooldown == 0 and not actor.shield_visual.visible, "a new hero starts with a ready but inactive shield")
	actor.attack_time = 0.30
	actor.cooldown = 0.12
	actor.velocity = Vector3(1.0, 0, -2.0)
	actor.visual.play(actor.config.attack)
	var motion: Vector3 = actor.velocity
	check(actor.cast_divine_shield(), "a living friendly actor can activate the shield")
	check(actor.shielded == 3 and actor.shield_cooldown == 24 and actor.hp == 70, "casting gives three seconds of immunity and a 24-second cooldown without healing")
	check(actor.attack_time == 0.30 and actor.cooldown == 0.12 and actor.velocity == motion and actor.visual.current_clip == actor.config.attack, "casting preserves an ongoing attack, movement, and its prepared clip")
	check(not actor.cast_divine_shield() and actor.shield_casts == 1 and actor.shielded == 3, "repeated activation cannot stack or extend protection")
	check(not actor.take_damage(9) and not actor.take_periodic_damage(6) and not actor.take_damage(999), "direct, periodic, and lethal damage all return false during immunity")
	check(actor.hp == 70 and actor.hits_taken == 0 and damage_signals == 0 and not actor.dead and not game.ended, "blocked hits never change health, hit counters, damage signals, or death state")
	check(actor.attack_time == 0.30 and actor.stagger == 0 and actor.cooldown == 0.12 and actor.velocity == motion and game.hurt_flash == 0 and game.camera_shake == 0, "blocked hits do not interrupt attacks, stagger, knock back, flash red, or shake the camera")
	check(actor.shield_blocks == 3 and actor.shield_visual.flash == 1, "blocked hits produce shield feedback")
	check(not game.enemies[0].cast_divine_shield(), "enemy actors do not gain a player skill")
	actor.position = Vector3(1, 0, 1)
	actor.rotation.y = 0.7
	check(actor.shield_visual.get_parent() == actor and actor.shield_visual.global_position == actor.global_position and actor.get_node("WardenRim").light_color == Color("#d3e6e7"), "the golden shell follows its actor and preserves the original Warden rim light")
	game.consecration.cast()
	game.consecration.advance(1.0)
	check(actor.hp == 74 and game.consecration.pulse_count == 1, "Consecration still casts and heals while Divine Shield is active")
	actor.advance_shield(1.0)
	game.toggle_pause()
	var time: float = actor.shielded
	var cooldown: float = actor.shield_cooldown
	var age: float = actor.shield_visual.age
	actor.advance_shield(10.0)
	game.command_shield = true
	game._physics_process(1.0)
	check(actor.shielded == time and actor.shield_cooldown == cooldown and actor.shield_visual.age == age and not actor.cast_divine_shield() and not game.command_shield, "pause freezes protection, cooldown, and visuals, rejects casting, and discards queued input")
	game.toggle_pause()
	actor.position = Vector3.ZERO
	actor.rotation.y = 0
	var enemy: CharacterBody3D = game.enemies[0]
	enemy.position = Vector3(0, 0, -1.5)
	enemy.rotation.y = PI
	await ticks()
	var hp: int = actor.hp
	game.resolve_attack(enemy)
	check(actor.hp == hp and actor.shield_blocks == 4, "the actual enemy melee resolver respects Divine Shield")
	game.resolve_attack(actor)
	check(enemy.hp == 22, "the protected player still deals the unchanged 28-point sword damage")
	actor.advance_shield(1.999)
	check(actor.shielded > 0 and not actor.take_damage(9), "protection lasts until the three-second boundary")
	actor.advance_shield(0.001)
	check(actor.shielded == 0 and not actor.shield_visual.visible and is_equal_approx(actor.shield_cooldown, 21.0), "immunity and its shell end at three seconds while cooldown continues")
	check(actor.take_damage(9) and actor.hp == hp - 9 and actor.stagger == 0.18 and actor.attack_time == -1 and damage_signals == 1, "expiry restores the inherited direct-damage and stagger response")
	check(actor.take_periodic_damage(6) and actor.hp == hp - 15 and actor.hits_taken == 2, "periodic damage also resumes after expiry")
	actor.dodge_time = 0.1
	check(not actor.take_damage(9) and not actor.take_periodic_damage(6), "the original dodge immunity still works independently")
	actor.dodge_time = 0
	actor.advance_shield(20.999)
	check(not actor.cast_divine_shield(), "the shield cannot be refreshed before its full cooldown")
	actor.advance_shield(0.001)
	check(actor.cast_divine_shield() and actor.shield_casts == 2, "a second cast becomes ready exactly 24 seconds after activation")
	game.finish(true)
	check(actor.shielded == 0 and not actor.shield_visual.visible and not actor.cast_divine_shield(), "an ending immediately clears protection and rejects further casting")
	game.restart()
	await ticks(5)
	game = current_scene
	game.record_results = false
	game.sound_enabled = false
	for target in game.enemies:
		target.set_physics_process(false)
	check(game.player.shielded == 0 and game.player.shield_cooldown == 0 and game.player.shield_casts == 0, "restart resets the shield, cooldown, and per-run counters")
	key(KEY_F, true)
	await ticks(2)
	check(game.player.shield_casts == 1 and game.player.shielded > 0, "a real F keyboard event activates the skill in normal gameplay")
	var point: Vector3 = game.player.position
	key(KEY_D, true)
	await ticks(20)
	key(KEY_D, false)
	check(game.player.position.distance_to(point) > 0.3 and game.player.shielded > 0, "normal WASD movement continues while protected")
	var attacks: int = game.player.attacks
	Input.action_press("fire")
	await ticks(4)
	Input.action_release("fire")
	check(game.player.attacks > attacks and game.player.shielded > 0, "normal attack input still works while protected")
	game.toggle_pause()
	time = game.player.shielded
	cooldown = game.player.shield_cooldown
	await ticks(60)
	check(game.player.shielded == time and game.player.shield_cooldown == cooldown, "the real physics loop freezes both timers during pause")
	game.toggle_pause()
	await ticks(1445)
	check(game.player.shield_casts == 1 and game.player.shielded == 0 and game.player.shield_cooldown == 0, "holding F through a full cooldown does not automatically recast")
	key(KEY_F, false)
	await ticks()
	key(KEY_F, true)
	await ticks()
	key(KEY_F, false)
	check(game.player.shield_casts == 2 and game.player.shielded > 0, "release and press F again can activate a ready shield")
	game.player.cancel_divine_shield()
	game.player.take_damage(999)
	check(game.ended and game.player.dead and not game.player.cast_divine_shield(), "a fallen hero cannot activate the shield or be revived by it")
	game.return_menu()
	await ticks(5)
	check(current_scene.has_node("MeleeCourtyard") and current_scene.has_node("Controls"), "pause, ending, and return-to-menu routes remain intact")
	current_scene.queue_free()
	current_scene = null
	game = null
	actor = null
	enemy = null
	await ticks(3)
	print("DIVINE SHIELD COMPLETE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
