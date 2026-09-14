extends SceneTree
## Deterministic state fixtures complement the natural combat playthrough.

var game: Node3D
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	print("%s: %s" % ["PASS" if value else "FAIL", message])
	if not value:
		failures += 1

func ticks(count: int) -> void:
	for i in range(count):
		await physics_frame

func run() -> void:
	game = load("res://scenes/ember.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.auto_control = true
	game.record_results = false
	await ticks(3)
	check(game.dungeon and game.collection_layout.get_child_count() == 69, "all 69 selected native scene instances populate the room")
	var paths := {}
	for part in game.collection_layout.get_children():
		paths[part.get_meta("collection_scene")] = true
	check(paths.size() == 9, "all nine Collection roles are present")
	check(game.decoration.altar_nodes.size() == 3, "three authored Blender altars are wired into gameplay")
	game.kindle()
	check(game.seals == 0, "a guarded seal cannot be kindled early")
	for wave in range(3):
		check(game.alive_count() == wave + 3, "watch %d has the configured guardian count" % (wave + 1))
		for enemy in game.enemies:
			enemy.set_physics_process(false)
			if not enemy.dead:
				enemy.take_damage(999)
		check(game.wave_cleared and not game.ended, "clearing watch %d unlocks its seal without ending the run" % (wave + 1))
		game.player.hp = 55
		game.player.position = game.World.POINTS[wave] + Vector3(0, 0, 1.65)
		game.command_interact = true
		await ticks(2)
		check(game.seals == wave + 1 and game.player.hp == 85, "interaction kindles seal %d and restores exactly 30 health" % (wave + 1))
		check(game.decoration.fires[wave].visible, "the kindled flame is visible")
		if wave < 2:
			game.toggle_pause()
			var time: float = game.elapsed
			var next: float = game.next_wave_time
			var point: Vector3 = game.player.position
			var motion: float = game.player.visual.animation.current_animation_position
			await ticks(20)
			check(game.elapsed == time and game.next_wave_time == next and game.player.position == point and game.player.visual.animation.current_animation_position == motion, "pause freezes movement, animation, and wave progression")
			game.toggle_pause()
			await ticks(130)
	check(game.seals == 3 and not game.ended, "third seal opens extraction instead of auto-winning")
	game.toggle_pause()
	var gate_height: float = game.decoration.gate.position.y
	await ticks(20)
	check(game.decoration.gate.position.y == gate_height, "pause also freezes the opening gate")
	game.toggle_pause()
	game.player.position = Vector3(0, 0, -10.3)
	game.command_interact = true
	await ticks(2)
	check(game.ended and game.won and game.total_kills == 12 and game.overlay.visible, "gate interaction completes the 12-guardian run and shows the ending")
	game.restart()
	await ticks(5)
	game = current_scene
	game.auto_control = true
	game.record_results = false
	check(not game.ended and game.seals == 0 and game.player.hp == 100, "restart creates a fresh run")
	game.player.take_damage(999)
	await ticks(2)
	check(game.ended and not game.won and game.overlay.visible, "defeat exposes the restart/menu overlay")
	game.return_menu()
	await ticks(4)
	check(current_scene.has_node("MeleeCourtyard") and current_scene.has_node("Controls"), "return menu exposes the game and its controls")
	var menu: Control = current_scene
	check(not menu.get_node("MeleeCourtyard").get_global_rect().intersects(menu.get_node("Controls").get_global_rect()), "title-screen controls do not overlap")
	menu.queue_free()
	game = null
	current_scene = null
	await ticks(3)
	print("EMBER FLOW COMPLETE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
