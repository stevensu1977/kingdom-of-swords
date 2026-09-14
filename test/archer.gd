extends SceneTree
## Real animation-event and projectile collision checks, plus encounter integration.

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

func fire(from: Vector3, to: Vector3) -> Node3D:
	var arrow: Node3D = game.launch_arrow(from, to)
	if arrow != null:
		arrow.set_physics_process(false)
	return arrow

func count_archers() -> int:
	var count := 0
	for enemy in game.enemies:
		if not enemy.dead and enemy.get_meta("archetype", "") == "archer":
			count += 1
	return count

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
		enemy.position = Vector3(8, 0, -8)
	var archer: CharacterBody3D = game.enemies[2]
	archer.position = Vector3(0, 0, -6)
	game.player.position = Vector3.ZERO
	await ticks()
	check(game.enemies.size() == 3 and count_archers() == 1, "first watch contains two melee guardians and one archer")
	check(archer.hp == 40 and archer.config.damage == 8 and archer.visual.skeleton.get_bone_count() == 63, "supplied 63-bone archer uses its own 40-HP / 8-damage profile")
	check(archer.visual.animation.has_animation("draw") and archer.visual.animation.has_animation("shoot") and archer.visual.animation.has_animation("run"), "all three prepared clips are present")
	archer.begin_draw()
	archer.visual.advance(1.199)
	check(game.arrows_fired == 0 and archer.phase == "draw" and game.player.hp == 100, "draw animation does not apply instant damage or release early")
	archer.visual.advance(0.001)
	check(archer.phase == "shoot" and archer.visual.current_clip == "shoot", "the supplied aim_ready event transitions draw into shoot")
	archer.visual.advance(0.132)
	check(game.arrows_fired == 0, "shoot waits for the supplied arrow_release timestamp")
	archer.visual.advance(0.002)
	check(game.arrows_fired == 1 and archer.shots == 1 and game.player.hp == 100, "arrow_release creates one projectile without hitscan damage")
	var arrow: Node3D = game.projectiles.get_child(0)
	arrow.set_physics_process(false)
	check(arrow.global_position.distance_to(archer.visual.release_origin()) < 0.001 and arrow.position.y > 0.8, "the projectile originates from the prepared arrow bone at bow height")
	var position: Vector3 = arrow.global_position
	arrow.advance(0.01)
	check(is_equal_approx(arrow.global_position.distance_to(position), 0.1) and game.player.hp == 100, "the visible arrow travels at ten metres per second")
	arrow.advance(1.0)
	check(arrow.spent and game.player.hp == 92 and game.arrow_hits == 1, "swept projectile collision applies exactly eight damage on arrival")
	arrow.advance(1.0)
	check(game.player.hp == 92 and game.arrow_hits == 1, "a consumed arrow cannot hit a second time")
	archer.visual.advance(1.0)
	check(game.arrows_fired == 1 and archer.phase == "ready" and archer.cooldown == 1.0, "reload completes without duplicate arrows and gives a recovery window")
	await ticks()
	archer.begin_draw()
	archer._physics_process(0.84)
	game.player.position.x = 1.0
	archer._physics_process(0.02)
	var locked: Vector3 = archer.shot_target
	game.player.position.x = -2.0
	archer._physics_process(0.1)
	check(archer.locked and archer.shot_target == locked and locked.x == 1.0, "aim locks before release and stops following a sidestepping player")
	var fired: int = game.arrows_fired
	archer.take_damage(1)
	archer.visual.advance(2)
	check(archer.phase == "ready" and game.arrows_fired == fired and not archer.aim_line.visible, "a melee hit interrupts drawing and cancels the pending arrow")
	archer.begin_draw()
	archer.take_periodic_damage(6)
	check(archer.phase == "draw" and archer.visual.current_clip == "draw", "Consecration damage does not gain an unintended ranged-attack interrupt")
	archer.take_damage(1)
	archer.position = Vector3(0, 0, -2.8)
	game.player.position = Vector3.ZERO
	archer.velocity = Vector3.ZERO
	archer.stagger = 0
	archer.cooldown = 3.0
	var before: float = archer.position.distance_to(game.player.position)
	for i in range(30):
		archer._physics_process(1.0 / 60.0)
	check(archer.position.distance_to(game.player.position) > before + 0.3, "a nearby archer retreats at a catchable speed")
	var health: int = game.player.hp
	game.resolve_attack(archer)
	check(game.player.hp == health, "the archer never applies the inherited melee attack")
	archer.position = Vector3(0, 0, -6)
	archer.velocity = Vector3.ZERO
	archer.cooldown = 0
	var wall: Node3D = game.box("ArrowTestWall", Vector3(0, 1, -3), Vector3(2, 2, 0.12), Color.GRAY, true)
	await ticks()
	archer._physics_process(0.05)
	check(archer.phase == "ready" and not archer.aim_line.visible, "solid cover prevents starting a shot without line of sight")
	arrow = fire(Vector3(0, 1, -6), Vector3(0, 1, 0))
	arrow.advance(1.0)
	check(arrow.spent and game.player.hp == health and game.arrows_stopped == 1, "a thin wall stops a high-speed arrow across a large frame step")
	wall.queue_free()
	await ticks()
	arrow = fire(Vector3(0, 1, -6), Vector3(0, 1, 0))
	var heading: Vector3 = arrow.direction
	game.player.position = Vector3(2, 0, 0)
	await ticks()
	arrow.advance(1.0)
	check(arrow.direction == heading and is_zero_approx(arrow.position.x) and game.player.hp == health, "arrows keep a straight trajectory and miss players who sidestep")
	# A clear high path isolates lifetime from the sanctuary's altar collisions.
	arrow = fire(Vector3(0, 5, -8), Vector3(0, 5, 8))
	arrow.advance(2.0)
	check(arrow.spent and is_equal_approx(arrow.traveled, 16.0), "missed arrows expire at their sixteen-metre range")
	game.player.position = Vector3.ZERO
	game.player.stagger = 0
	game.player.cast_divine_shield()
	await ticks()
	arrow = fire(Vector3(0, 1, -6), Vector3(0, 1, 0))
	arrow.advance(1.0)
	check(arrow.spent and game.player.hp == health and game.player.shield_blocks == 1 and game.arrows_deflected == 1, "Divine Shield blocks and consumes arrows through the normal damage entry")
	game.player.cancel_divine_shield()
	game.player.dodge_time = 0.1
	arrow = fire(Vector3(0, 1, -6), Vector3(0, 1, 0))
	arrow.advance(1.0)
	check(arrow.spent and game.player.hp == health and game.arrows_deflected == 2, "the original dodge immunity also protects against arrows")
	game.player.dodge_time = 0
	arrow = fire(Vector3(0, 1, -6), Vector3(0, 1, 0))
	archer.position = Vector3(3, 0, -5)
	archer.begin_draw()
	archer.visual.advance(0.4)
	var time: float = archer.visual.action_time
	position = arrow.position
	game.toggle_pause()
	arrow.advance(5)
	archer._physics_process(5)
	check(arrow.position == position and archer.visual.action_time == time and game.launch_arrow(Vector3.ZERO, Vector3.FORWARD) == null, "pause freezes arrows and draw animation and prevents new projectiles")
	game.toggle_pause()
	arrow.advance(0.1)
	check(arrow.position != position, "an in-flight arrow resumes after unpausing")
	game.clear_arrows()
	await ticks()
	fired = game.arrows_fired
	archer.take_periodic_damage(999)
	archer._physics_process(2)
	check(archer.dead and game.kills == 1 and game.arrows_fired == fired and not archer.aim_line.visible, "a dying archer cannot release a pending arrow and counts as one kill")
	fire(Vector3(4, 1, -6), Vector3(4, 1, 0))
	for enemy in game.enemies:
		if not enemy.dead:
			enemy.take_damage(999)
	await ticks()
	check(game.wave_cleared and game.projectiles.get_child_count() == 0, "clearing the watch removes leftover arrows before seal interaction")
	game.kindle()
	game._physics_process(2.01)
	check(game.wave == 2 and game.alive_count() == 4 and count_archers() == 1, "second watch contains three melee guardians and one archer")
	for enemy in game.enemies:
		enemy.set_physics_process(false)
		if not enemy.dead:
			enemy.take_damage(999)
	game.kindle()
	game._physics_process(2.01)
	check(game.wave == 3 and game.alive_count() == 5 and count_archers() == 2 and game.enemies[-1].get_meta("elite", false), "final watch mixes two archers, two melee guardians, and the existing elite")
	for enemy in game.enemies:
		enemy.set_physics_process(false)
		if not enemy.dead:
			enemy.take_damage(999)
	game.kindle()
	game.player.position = Vector3(0, 0, -10.5)
	game.command_interact = true
	game._physics_process(0.1)
	check(game.ended and game.won and game.kills == 12 and game.seals == 3, "the mixed twelve-enemy encounter still completes through the original gate")
	game.restart()
	await ticks(5)
	game = current_scene
	game.record_results = false
	game.sound_enabled = false
	check(game.arrows_fired == 0 and game.projectiles.get_child_count() == 0 and count_archers() == 1, "restart resets all projectiles and restores the first mixed wave")
	game.return_menu()
	await ticks(5)
	check(current_scene.has_node("MeleeCourtyard") and current_scene.has_node("Controls"), "return-to-menu exposes the game and its controls")
	current_scene.queue_free()
	current_scene = null
	game = null
	archer = null
	arrow = null
	await ticks(3)
	print("ARCHER COMPLETE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
