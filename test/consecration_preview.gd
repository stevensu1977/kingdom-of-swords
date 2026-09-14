extends SceneTree
## Still-frame presentation fixture; the video uses unmodified combat stats.

var game: Node3D
var frames := 0

func _initialize() -> void:
	setup.call_deferred()

func setup() -> void:
	game = load("res://scenes/ember.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.auto_control = true
	game.record_results = false
	game.sound_enabled = false
	game.ambient.stop()
	game.ambient.stream = null
	OS.delay_msec(100)
	game.player.position = Vector3(0, 0, 2.5)
	game.player.hp = 70
	game.enemies[0].position = Vector3(-1.5, 0, 1.4)
	game.enemies[1].position = Vector3(2.0, 0, 3.0)
	game.enemies[2].position = Vector3(4, 0, 3.0)
	game.camera.position = Vector3(0, 18, 15.5)
	game.banner_time = 0
	game.consecration.cast()
	game.consecration.advance(1.2)
	game.paused = true
	game.effects.process_mode = Node.PROCESS_MODE_DISABLED

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 8:
		root.get_texture().get_image().save_png("res://screenshots/consecration/preview.png")
		quit()
	return false
