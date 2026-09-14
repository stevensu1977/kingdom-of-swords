extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var arena: Node3D = load("res://scenes/melee.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	arena.paused = true
	var visual: Node3D = arena.player.visual
	var skeleton: Skeleton3D = visual.skeleton
	var right := skeleton.find_bone("mixamorig_RightHand_030")
	var left := skeleton.find_bone("mixamorig_LeftHand_011")
	var worst_grip := 0.0
	var worst_length := 0.0
	var lengths: Dictionary = {}
	var animation: AnimationPlayer = visual.animation
	for clip in ["Ready", "ArmedWalk", "Attack", "Uppercut"]:
		animation.play(clip, 0)
		var duration := animation.get_animation(clip).length
		for sample in range(61):
			animation.seek(duration * sample / 60.0, true)
			animation.advance(0)
			var rig: Transform3D = visual.rig_transform()
			var r: Transform3D = rig * visual.bone_pose(right)
			var l: Transform3D = rig * visual.bone_pose(left)
			var target := r * Vector3(0, 0.11, 0.035) - r.basis.x.normalized() * 0.145
			worst_grip = maxf(worst_grip, (l * Vector3(0, 0.11, 0.035)).distance_to(target))
			for index in range(skeleton.get_bone_count()):
				var name: String = skeleton.get_bone_name(index)
				if not ("Arm_" in name or "ForeArm_" in name or "UpLeg_" in name or "Leg_" in name):
					continue
				var length := skeleton.get_bone_pose_position(index).length()
				if not lengths.has(index):
					lengths[index] = length
				worst_length = maxf(worst_length, absf(length - float(lengths[index])))
	var ok := worst_grip < 0.003 and worst_length < 0.001
	print("CHARACTER CONTRACT: %s grip_error_m=%.6f limb_length_change=%.6f samples=244" % ["PASS" if ok else "FAIL", worst_grip, worst_length])
	quit(0 if ok else 1)
