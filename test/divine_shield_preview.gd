extends SceneTree
## Presentation fixture only; the movie uses real combat without stat overrides.

var frames := 0

func _initialize() -> void:
	setup.call_deferred()

func setup() -> void:
	var game: Node3D = load("res://scenes/ember.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.auto_control = true
	game.record_results = false
	game.sound_enabled = false
	game.ambient.stop()
	game.ambient.stream = null
	OS.delay_msec(100)
	game.player.position = Vector3(0, 0, 2.5)
	game.enemies[0].position = Vector3(-1.5, 0, 1.4)
	game.enemies[1].position = Vector3(2.0, 0, 3.0)
	game.enemies[2].position = Vector3(4, 0, 3.0)
	game.camera.position = Vector3(0, 18, 15.5)
	game.banner_time = 0
	game.player.cast_divine_shield()
	game.player.advance_shield(0.6)
	game.player.take_damage(9)
	game.player.shield_visual.animate(0.04, game.player.shielded)
	game.paused = true
	game.effects.process_mode = Node.PROCESS_MODE_DISABLED

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 8:
		root.get_texture().get_image().save_png("res://screenshots/divine_shield/preview.png")
		quit()
	return false
