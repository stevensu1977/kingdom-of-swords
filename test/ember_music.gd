extends SceneTree
## User input, pause/master-mute precedence, and persisted music preference.

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	print("%s: %s" % ["PASS" if value else "FAIL", message])
	if not value:
		failures += 1

func ticks(count := 3) -> void:
	for i in range(count):
		await physics_frame

func prepare_audio(game: Node3D) -> void:
	# Ordinary accelerated fixtures skip playback; this fixture inspects its pause state.
	if DisplayServer.get_name() == "headless":
		game.ambient.play()
		game.update_music_state()
	await ticks()

func press(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await ticks(2)

func click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await ticks(2)

func run() -> void:
	var profile: Node = root.get_node("Profile")
	var soundtrack: Node = root.get_node("Soundtrack")
	var old_path: String = profile.storage_path
	var old_storage: bool = profile.storage_enabled
	var old_music: bool = soundtrack.music_enabled
	var old_muted: bool = soundtrack.muted
	profile.storage_path = "user://ember_music_test_%d.json" % OS.get_process_id()
	profile.storage_enabled = true
	profile.music_enabled = true
	soundtrack.music_enabled = true
	soundtrack.muted = false
	soundtrack.update_mute()
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await ticks()
	var game: Node3D = menu.preview
	await prepare_audio(game)
	var menu_button: Button = menu.get_node("BGMToggle")
	check(menu_button.button_pressed and menu_button.text.contains("ON"), "title has a visible BGM ON button")
	check(game.paused and game.menu_preview and not game.ambient.stream_paused, "title preview stays frozen while enabled BGM is unpaused")
	check(not menu_button.get_global_rect().intersects(menu.get_node("Controls").get_global_rect()) and menu_button.get_global_rect().end.y < 632, "title switch fits below the main actions and above the footer")
	await click(menu_button)
	check(not game.music_enabled and game.ambient.stream_paused and not menu_button.button_pressed, "clicking the title switch turns only BGM off")
	check(game.sound_enabled and not soundtrack.music_enabled and not profile.music_enabled, "BGM off preserves sound effects and updates the shared preference")
	var loaded: Node = load("res://scripts/profile.gd").new()
	loaded.storage_path = profile.storage_path
	loaded.load_profile()
	check(not loaded.music_enabled, "BGM OFF survives a fresh load of the saved profile")
	loaded.free()
	await press(KEY_N)
	check(game.music_enabled and menu_button.button_pressed and not game.ambient.stream_paused and game.paused, "N restores title music without unfreezing the preview")
	var held := InputEventKey.new()
	held.physical_keycode = KEY_N
	held.keycode = KEY_N
	held.pressed = true
	held.echo = true
	Input.parse_input_event(held)
	await ticks()
	check(game.music_enabled, "keyboard auto-repeat does not repeatedly toggle music")
	held.pressed = false
	held.echo = false
	Input.parse_input_event(held)
	await press(KEY_M)
	check(not game.sound_enabled and game.music_enabled and game.ambient.stream_paused, "M temporarily mutes an enabled title BGM")
	await press(KEY_M)
	check(game.sound_enabled and not game.ambient.stream_paused, "M restores title BGM while the preview remains frozen")
	await press(KEY_ESCAPE)
	check(game.paused and not game.overlay.visible, "title audio controls do not expose the hidden gameplay pause overlay")
	await click(menu_button)
	await click(menu.get_node("MeleeCourtyard"))
	await ticks(6)
	game = current_scene
	await prepare_audio(game)
	game.auto_control = true
	game.record_results = false
	for enemy in game.enemies:
		enemy.set_physics_process(false)
	check(not game.music_enabled and game.ambient.stream_paused and not game.menu_preview, "entering the adventure preserves BGM OFF")
	check(game.ambient.stream.resource_path in [game.LOCAL_BGM, game.PUBLIC_BGM] and game.ambient.stream.loop and game.ambient.volume_db == -8, "a supported looping track and the louder mix are retained")
	check(not soundtrack.player.playing, "the foundation soundtrack is not layered under the sanctuary")
	var track: AudioStream = game.ambient.stream
	game.command_aim = game.player.position + Vector3.FORWARD * 2
	game.command_attack = true
	await ticks(12)
	game.command_attack = false
	var has_effect := false
	for voice in game.voices:
		has_effect = has_effect or voice.stream != null
	check(game.sound_enabled and game.player.attacks > 0 and has_effect, "attacking and its sound effects still work with BGM OFF")
	await press(KEY_N)
	check(game.music_enabled and not game.ambient.stream_paused, "N restores music during gameplay")
	await press(KEY_ESCAPE)
	check(game.paused and game.ambient.stream_paused, "Escape pauses the BGM with the game")
	var pause_button: Button = game.overlay.find_child("BGMToggle", true, false)
	check(pause_button.is_visible_in_tree() and pause_button.button_pressed, "pause panel exposes the same BGM preference")
	check(not pause_button.get_global_rect().intersects(game.continue_button.get_global_rect()), "pause BGM switch does not overlap Resume")
	await click(pause_button)
	check(not game.music_enabled and game.paused and game.sound_enabled, "pause switch can turn BGM off without changing pause or sound effects")
	await click(pause_button)
	check(game.music_enabled and game.ambient.stream_paused and game.paused, "enabling BGM while paused does not start playback early")
	await press(KEY_M)
	await press(KEY_ESCAPE)
	check(not game.paused and not game.sound_enabled and game.ambient.stream_paused, "resuming honors the master mute")
	await press(KEY_N)
	await press(KEY_N)
	check(game.music_enabled and game.ambient.stream_paused, "BGM ON cannot override master mute")
	await press(KEY_N)
	await press(KEY_M)
	check(game.sound_enabled and not game.music_enabled and game.ambient.stream_paused, "master unmute preserves a separately disabled BGM")
	await press(KEY_N)
	check(not game.ambient.stream_paused and game.ambient.stream == track and game.ambient.volume_db == -8, "re-enabling BGM keeps its stream and volume")
	await press(KEY_N)
	game.restart()
	await ticks(6)
	game = current_scene
	await prepare_audio(game)
	check(not game.music_enabled and game.ambient.stream_paused and game.player.hp == 100, "restart preserves BGM OFF while resetting gameplay")
	game.return_menu()
	await ticks(6)
	menu = current_scene
	await prepare_audio(menu.preview)
	check(not menu.preview.music_enabled and not menu.get_node("BGMToggle").button_pressed, "returning to the title preserves OFF and its button state")
	await click(menu.get_node("BGMToggle"))
	check(menu.preview.music_enabled and not menu.preview.ambient.stream_paused, "title music can be restored after returning from gameplay")
	menu.queue_free()
	current_scene = null
	await ticks()
	track = null
	OS.delay_msec(200)
	DirAccess.remove_absolute(profile.storage_path)
	DirAccess.remove_absolute(profile.storage_path + ".tmp")
	profile.storage_path = old_path
	profile.storage_enabled = old_storage
	profile.music_enabled = old_music
	soundtrack.music_enabled = old_music
	soundtrack.muted = old_muted
	soundtrack.update_mute()
	print("EMBER MUSIC COMPLETE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
