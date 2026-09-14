extends "res://test/archer_video.gd"
## Demonstrates real UI/keyboard music controls alongside the normal combat driver.

var step := 0

func setup() -> void:
	menu_seconds = 3.0
	super.setup()

func _physics_process(delta: float) -> bool:
	var result := super._physics_process(delta)
	if step == 0 and clock >= 0.65:
		click(menu.get_node("BGMToggle"))
		report_music("title_off")
		step += 1
	elif step == 1 and clock >= 1.7:
		click(menu.get_node("BGMToggle"))
		report_music("title_on")
		step += 1
	elif step == 2 and clock >= 2.45:
		click(menu.get_node("BGMToggle"))
		report_music("title_off_before_enter")
		step += 1
	elif step == 3 and clock >= 3.3:
		report_music("adventure_keeps_off")
		step += 1
	elif step == 4 and clock >= 4.25:
		press(KEY_N)
		report_music("adventure_on")
		step += 1
	elif step == 5 and clock >= 6.2:
		press(KEY_ESCAPE)
		report_music("paused")
		step += 1
	elif step == 6 and clock >= 6.7:
		click(game.overlay.find_child("BGMToggle", true, false))
		report_music("pause_switch_off")
		step += 1
	elif step == 7 and clock >= 8.1:
		press(KEY_ESCAPE)
		report_music("combat_effects_without_bgm")
		step += 1
	elif step == 8 and clock >= 11.5:
		press(KEY_N)
		report_music("combat_bgm_restored")
		step += 1
	return result

func press(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)

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
	motion = InputEventMouseMotion.new()
	motion.position = Vector2(470, 560)
	motion.global_position = motion.position
	root.push_input(motion, true)

func report_music(label: String) -> void:
	var scene: Node3D = game if is_instance_valid(game) else menu.preview
	print("BGM CONTROL VIDEO: %s time=%.2f enabled=%s effects=%s game_paused=%s audio_paused=%s playhead=%.3f" % [label, clock, scene.music_enabled, scene.sound_enabled, scene.paused, scene.ambient.stream_paused, scene.ambient.get_playback_position()])
