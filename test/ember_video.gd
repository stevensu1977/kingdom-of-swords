extends SceneTree
## Real gameplay, driven deterministically. No stats or rules are altered.

var game: Node3D
var clock := 0.0
var menu: Control
var entered := false
var reported := false
var last_position := Vector3.ZERO
var blocked_time := 0.0
var audio_released := false
var menu_seconds := 1.5

func _initialize() -> void:
	setup.call_deferred()

func setup() -> void:
	menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu

func _physics_process(delta: float) -> bool:
	clock += delta
	if clock > menu_seconds and not entered:
		entered = true
		menu.queue_free()
		game = load("res://scenes/ember.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		game.auto_control = true
		game.record_results = false
	if game == null or not is_instance_valid(game) or game.ended:
		return false
	drive(delta)
	if clock > 17.0 and not audio_released:
		game.ambient.volume_db = game.BGM_VOLUME_DB - 60.0 * clampf((clock - 17.0) / 0.5, 0, 1)
	# Let the audio mixer retire active voices before fixed-frame capture exits.
	if clock > 17.5 and not audio_released:
		audio_released = true
		game.sound_enabled = false
		for voice in game.voices:
			voice.stop()
			voice.stream = null
		game.ambient.stop()
		game.ambient.stream = null
		OS.delay_msec(100)
	if clock >= 17.9 and not reported:
		reported = true
		print("EMBER VIDEO: time=%.2f kills=%d seals=%d hp=%d attacks=%d dodges=%d" % [clock, game.kills, game.seals, game.player.hp, game.player.attacks, game.player.dodges])
	return false

func drive(delta: float) -> void:
	var target := Vector3.ZERO
	game.command_attack = false
	if game.wave_cleared:
		target = game.World.POINTS[game.seals] + Vector3(0, 0, 1.65)
		game.command_interact = true
	elif game.seals == 3:
		target = Vector3(0, 0, -10.3)
		game.command_interact = true
	else:
		var nearest: CharacterBody3D
		var distance := INF
		for enemy in game.enemies:
			if not enemy.dead and game.player.position.distance_to(enemy.position) < distance:
				nearest = enemy
				distance = game.player.position.distance_to(enemy.position)
		if nearest == null:
			game.command_move = Vector2.ZERO
			return
		target = nearest.position
		game.command_aim = target
		game.command_attack = distance < 2.28
		if nearest.attack_time > 0.20 and nearest.attack_time < 0.4 and game.player.attack_time < 0 and distance < 2.5:
			var away: Vector3 = game.player.position - nearest.position
			game.command_move = Vector2(away.x, away.z).normalized()
			game.command_dodge = true
			return
		if distance < 1.92:
			game.command_move = Vector2.ZERO
			return
	var direction: Vector3 = target - game.player.position
	game.command_aim = target
	game.command_move = Vector2(direction.x, direction.z).normalized() if direction.length() > 0.18 else Vector2.ZERO
	# Steer around altar bases using the same collision sight check as enemies.
	if not game.clear_sight(game.player.position, game.player.position + Vector3(game.command_move.x, 0, game.command_move.y) * 0.85):
		game.command_move = Vector2(-game.command_move.y, game.command_move.x)
	if last_position.distance_to(game.player.position) < 0.006 and game.command_move.length() > 0 and game.player.attack_time < 0:
		blocked_time += delta
		if blocked_time > 0.3:
			game.command_move = Vector2(-game.command_move.y, game.command_move.x)
	else:
		blocked_time = 0
	if clock > 2.1 and clock < 2.15:
		game.command_dodge = true
	last_position = game.player.position
