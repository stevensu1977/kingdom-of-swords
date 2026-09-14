extends SceneTree

var ticks := 0
var game: Node
var mode := "game"

func _initialize() -> void:
	if "--menu" in OS.get_cmdline_user_args():
		mode = "menu"
	elif "--ending" in OS.get_cmdline_user_args():
		mode = "ending"
	setup.call_deferred()

func setup() -> void:
	game = load("res://scenes/menu.tscn" if mode == "menu" else "res://scenes/ember.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var audio_game: Node3D = game.preview if mode == "menu" else game
	audio_game.ambient.stop()
	audio_game.ambient.stream = null
	OS.delay_msec(100)
	if mode != "menu":
		game.auto_control = true
		game.record_results = false
		game.sound_enabled = false
		game.player.position = Vector3(0, 0, 2.5)
		game.camera.position = Vector3(0, 18, 15.5)
		game.banner_time = 0
		game.paused = true
		if mode == "ending":
			# Presentation fixture; test/ember_combat.gd proves real completion.
			game.seals = 3
			game.total_kills = 12
			game.elapsed = 52.78
			for i in range(3):
				game.decoration.kindle(i)
			for enemy in game.enemies:
				enemy.hide()
			game.finish(true)

func _process(_delta: float) -> bool:
	ticks += 1
	if ticks == 8:
		root.get_texture().get_image().save_png("res://screenshots/ember/" + mode + ".png")
		quit()
	return false
