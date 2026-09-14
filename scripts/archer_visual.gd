extends Node3D
## Adapter for the supplied GLB clips/events. Never changes bones, skin, or sockets.

const Prepared = preload("res://scripts/foundation/character_visual.gd")
signal motion_event(action: String, event: String)

var model: Node3D
var skeleton: Skeleton3D
var animation: AnimationPlayer
var current_clip := ""
var action_time := 0.0
var clip_data: Dictionary
var event_index := 0
var playback_speed := 1.0
var arrow_bone := -1

func prepare(config: Dictionary) -> void:
	model = load(config.model).instantiate()
	model.name = "Model"
	add_child(model)
	# Supplied source faces +Z, matching the existing Character visual convention.
	rotation.y = PI
	var box := Prepared.measure(model)
	var factor := float(config.height) / maxf(box.size.y, 0.01)
	model.scale *= factor
	model.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z) * factor
	skeleton = Prepared.find_kind(model, "Skeleton3D") as Skeleton3D
	animation = Prepared.find_kind(model, "AnimationPlayer") as AnimationPlayer
	assert(skeleton != null and animation != null, "Archer needs its prepared skeleton and clips")
	# Godot disambiguates the source's arrow mesh and arrow bone as arrow / arrow_2.
	arrow_bone = skeleton.find_bone("arrow")
	if arrow_bone < 0:
		arrow_bone = skeleton.find_bone("arrow_2")
	assert(arrow_bone >= 0, "The supplied arrow bone is required")
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for item in config.clips:
		clip_data[item.name] = item
		assert(animation.has_animation(item.name), "Missing supplied archer clip: " + str(item.name))
	play("rest")

func play(action: String, speed := 1.0) -> void:
	playback_speed = speed
	if current_clip == action:
		return
	current_clip = action
	action_time = 0
	event_index = 0
	animation.play("draw" if action == "rest" else action)
	animation.seek(0, true)
	animation.advance(0)
	if action == "rest":
		animation.pause()

func play_action(action: String) -> void:
	# Called only on state transitions; each action starts at its first frame.
	current_clip = ""
	play(action)

func set_move_speed(speed: float) -> void:
	play("run" if speed > 0.15 else "rest", clampf(speed / 2.1, 0.35, 1.4))

func advance(delta: float) -> void:
	if current_clip == "rest" or current_clip.is_empty():
		return
	var action := current_clip
	var data: Dictionary = clip_data[action]
	var duration := float(data.duration)
	action_time = minf(duration, action_time + delta * playback_speed)
	animation.seek(action_time, true)
	animation.advance(0)
	var events: Array = data.events
	while event_index < events.size() and action_time + 0.00001 >= float(events[event_index].time):
		var event: String = events[event_index].name
		event_index += 1
		motion_event.emit(action, event)
		if current_clip != action:
			return
	if action_time + 0.00001 >= duration:
		if bool(data.loop):
			action_time = 0
			event_index = 0
			animation.seek(0, true)
		else:
			motion_event.emit(action, "finished")

func release_origin() -> Vector3:
	return (skeleton.global_transform * skeleton.get_bone_global_pose(arrow_bone)).origin
