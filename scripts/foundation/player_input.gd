extends RefCounted
## Input and camera-relative movement shared by shooter and melee scenes.

static func install() -> void:
	var keys := {
		"left": KEY_A, "right": KEY_D, "up": KEY_W, "down": KEY_S,
		"reload": KEY_R, "interact": KEY_E, "mute": KEY_M, "music": KEY_N,
		"maps": KEY_TAB, "weapon_1": KEY_1, "weapon_2": KEY_2,
		"weapon_3": KEY_3, "weapon_4": KEY_4, "dodge": KEY_SPACE
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = keys[action]
			InputMap.action_add_event(action, event)
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", event)

static func movement(camera: Camera3D = null) -> Vector2:
	var direction := Input.get_vector("left", "right", "up", "down")
	if camera != null:
		var right := Vector2(camera.basis.x.x, camera.basis.x.z).normalized()
		var backward := Vector2(camera.basis.z.x, camera.basis.z.z).normalized()
		direction = right * direction.x + backward * direction.y
	return direction.limit_length()
