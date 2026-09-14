extends Node3D
## Prepared clips and grip settings belong to this character, not the game rules.

var config: Dictionary
var model: Node3D
var skeleton: Skeleton3D
var animation: AnimationPlayer
var grip: BoneAttachment3D
var current_clip := ""

func prepare(settings: Dictionary) -> void:
	config = settings
	model = load(config.model).instantiate()
	model.name = "Model"
	add_child(model)
	var box := measure(model)
	var factor: float = float(config.height) / maxf(box.size.y, 0.01)
	model.scale *= factor
	model.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z) * factor
	skeleton = find_kind(model, "Skeleton3D") as Skeleton3D
	var source := find_kind(model, "AnimationPlayer") as AnimationPlayer
	assert(source != null and skeleton != null, "Prepared character requires a skeleton and clips")
	var library := AnimationLibrary.new()
	for clip_name in source.get_animation_list():
		if clip_name == "RESET":
			continue
		var clip: Animation = source.get_animation(clip_name).duplicate()
		clip.loop_mode = Animation.LOOP_LINEAR if clip_name in [config.idle, config.move] else Animation.LOOP_NONE
		library.add_animation(clip_name, clip)
	source.stop()
	source.active = false
	animation = AnimationPlayer.new()
	animation.name = "Playback"
	animation.root_node = NodePath("../Model")
	animation.add_animation_library("", library)
	add_child(animation)
	if config.has("weapon"):
		grip = BoneAttachment3D.new()
		grip.name = "WeaponHand"
		grip.bone_name = config.handBone
		skeleton.add_child(grip)
		var mount := Node3D.new()
		mount.position = Vector3(0, 0.11, 0.035)
		mount.scale = Vector3.ONE / rig_transform().basis.get_scale().x
		grip.add_child(mount)
		var weapon: Node3D = load(config.weapon).instantiate()
		mount.add_child(weapon)
		animation.mixer_applied.connect(constrain_grip)
	play(config.idle)
	animation.advance(0)

func play(clip: String, speed := 1.0) -> void:
	if clip != current_clip:
		assert(animation.has_animation(clip), "Missing prepared clip: " + clip)
		animation.play(clip, 0.10)
		current_clip = clip
	animation.speed_scale = speed

func rig_transform() -> Transform3D:
	return global_transform.affine_inverse() * skeleton.global_transform

func bone_pose(index: int) -> Transform3D:
	if index < 0:
		return Transform3D.IDENTITY
	var local := Transform3D(Basis(skeleton.get_bone_pose_rotation(index)).scaled(skeleton.get_bone_pose_scale(index)), skeleton.get_bone_pose_position(index))
	return bone_pose(skeleton.get_bone_parent(index)) * local

func set_bone_rotation(index: int, rotation: Basis) -> void:
	var parent := bone_pose(skeleton.get_bone_parent(index)).basis.orthonormalized()
	skeleton.set_bone_pose_rotation(index, (parent.inverse() * rotation).get_rotation_quaternion().normalized())

func aim_bone(index: int, child: int, target: Vector3) -> void:
	var pose := bone_pose(index)
	var current := (bone_pose(child).origin - pose.origin).normalized()
	var desired := (target - pose.origin).normalized()
	set_bone_rotation(index, Basis(Quaternion(current, desired)) * pose.basis.orthonormalized())

func constrain_grip() -> void:
	var right := skeleton.find_bone(config.handBone)
	var upper := skeleton.find_bone("mixamorig_LeftArm_09")
	var lower := skeleton.find_bone("mixamorig_LeftForeArm_010")
	var hand := skeleton.find_bone("mixamorig_LeftHand_011")
	if mini(mini(right, upper), mini(lower, hand)) < 0:
		return
	var rig := rig_transform()
	var right_pose := rig * bone_pose(right)
	var blade := right_pose.basis.x.normalized()
	var palm := right_pose * Vector3(0, 0.11, 0.035) - blade * 0.145
	var rotation := Basis(-blade, right_pose.basis.y.normalized(), -right_pose.basis.z.normalized())
	var local_rotation := rig.basis.orthonormalized().inverse() * rotation
	var target := rig.affine_inverse() * palm - local_rotation * Vector3(0, 0.11, 0.035)
	var shoulder := bone_pose(upper).origin
	var elbow := bone_pose(lower).origin
	var wrist := bone_pose(hand).origin
	var a := shoulder.distance_to(elbow)
	var b := elbow.distance_to(wrist)
	var distance := shoulder.distance_to(target)
	if distance < 0.001 or distance >= a + b:
		return
	var direction := (target - shoulder).normalized()
	var pole := rig.basis.inverse() * Vector3(1, -0.35, -0.15)
	pole = (pole - direction * pole.dot(direction)).normalized()
	var along := (a * a - b * b + distance * distance) / (2.0 * distance)
	var joint := shoulder + direction * along + pole * sqrt(maxf(0, a * a - along * along))
	aim_bone(upper, lower, joint)
	aim_bone(lower, hand, target)
	set_bone_rotation(hand, local_rotation)
	grip.on_skeleton_update()

static func find_kind(node: Node, kind: String) -> Node:
	if node.is_class(kind):
		return node
	for child in node.get_children():
		var result := find_kind(child, kind)
		if result != null:
			return result
	return null

static func measure(node: Node, transform := Transform3D.IDENTITY) -> AABB:
	if node is Node3D:
		transform *= node.transform
	var box := AABB()
	var found := false
	if node is MeshInstance3D and node.mesh != null:
		box = transform * node.get_aabb()
		found = true
	for child in node.get_children():
		var other := measure(child, transform)
		if other.size.length_squared() > 0:
			box = box.merge(other) if found else other
			found = true
	return box
