extends SceneTree
## Visual fixture only: inspect the supplied bow pose and a real projectile.

var game: Node3D
var archer: CharacterBody3D
var frames := 0

func _initialize() -> void:
	setup.call_deferred()

func setup() -> void:
	game = load("res://scenes/ember.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	game.record_results = false
	game.sound_enabled = false
	game.ambient.stop()
	game.ambient.stream = null
	OS.delay_msec(100)
	game.player.set_physics_process(false)
	game.player.position = Vector3(-1.5, 0, 4.0)
	for enemy in game.enemies:
		enemy.set_physics_process(false)
		enemy.position = Vector3(-4.5, 0, -6)
	archer = game.enemies[2]
	archer.position = Vector3(4.5, 0, 1)
	game.camera.position = Vector3(0, 18, 15.5)
	game.banner_time = 0
	archer.begin_draw()
	archer.visual.advance(0.95)
	archer.attack_time = 0.95
	archer.locked = true
	archer.update_aim()
	game.paused = true

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 8:
		root.get_texture().get_image().save_png("res://screenshots/archer/draw.png")
		game.paused = false
		archer.visual.advance(0.25)
		archer.visual.advance(4.0 / 30.0)
		for arrow in game.projectiles.get_children():
			arrow.set_physics_process(false)
			arrow.advance(0.24)
		archer.visual.advance(0.24)
		archer.update_aim()
		game.paused = true
	if frames == 16:
		root.get_texture().get_image().save_png("res://screenshots/archer/arrow.png")
		print("ARCHER PREVIEW: bones=%d arrows=%d origin=%s" % [archer.visual.skeleton.get_bone_count(), game.arrows_fired, archer.visual.release_origin()])
		quit()
	return false
