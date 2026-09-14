extends "res://scripts/ember_actor.gd"
## Ranged behavior is confined to this enemy; all player/foundation rules stay inherited.

const ArcherVisual = preload("res://scripts/archer_visual.gd")
const LOCK_TIME := 0.85
const DRAW_TIME := 1.2
const MIN_DISTANCE := 4.2
const MAX_DISTANCE := 9.5
const RECOVERY := 1.0

var phase := "ready"
var locked := false
var shot_target := Vector3.ZERO
var shots := 0
var aim_line: MeshInstance3D
var aim_material: StandardMaterial3D
var navigation_side := 1.0

func _ready() -> void:
	hp = int(config.health)
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.8
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.9
	add_child(collider)
	visual = ArcherVisual.new()
	visual.name = "Character"
	add_child(visual)
	visual.prepare(config)
	visual.motion_event.connect(on_motion_event)
	cooldown = float(config.get("initial_delay", 0.8))
	navigation_side = -1.0 if position.x < 0 else 1.0
	set_meta("archetype", "archer")
	aim_material = StandardMaterial3D.new()
	aim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aim_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aim_material.albedo_color = Color(0.94, 0.51, 0.22, 0.4)
	aim_line = MeshInstance3D.new()
	aim_line.name = "ArrowAim"
	var beam := BoxMesh.new()
	beam.size = Vector3(0.035, 0.012, 1)
	aim_line.mesh = beam
	aim_line.material_override = aim_material
	aim_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(aim_line)
	aim_line.top_level = true
	aim_line.hide()

func _physics_process(delta: float) -> void:
	if arena.paused:
		return
	if dead or arena.ended:
		aim_line.hide()
		super._physics_process(delta)
		return
	cooldown = maxf(0, cooldown - delta)
	stagger = maxf(0, stagger - delta)
	attack_requested = false
	desired_move = Vector2.ZERO
	var offset: Vector3 = arena.player.position - position
	offset.y = 0
	var distance := offset.length()
	if phase in ["draw", "shoot"]:
		attack_time += delta
		if phase == "draw" and not locked:
			shot_target = arena.player.position + Vector3.UP
			locked = attack_time >= LOCK_TIME
		rotation.y = Locomotion.facing(global_position, shot_target, rotation.y)
		visual.advance(delta)
	else:
		if stagger <= 0:
			var clear: bool = arena.clear_sight(position, arena.player.position)
			var direction := offset.normalized()
			if distance < MIN_DISTANCE:
				direction = -direction
			elif distance <= MAX_DISTANCE and clear:
				direction = Vector3.ZERO
			if not direction.is_zero_approx():
				desired_move = safe_direction(direction)
			if cooldown <= 0 and distance >= 3.0 and distance <= MAX_DISTANCE and clear:
				begin_draw()
		if phase != "draw":
			visual.set_move_speed(Vector2(velocity.x, velocity.z).length())
			visual.advance(delta)
		if not desired_move.is_zero_approx():
			rotation.y = Locomotion.facing(position, position + Vector3(desired_move.x, 0, desired_move.y), rotation.y)
	var move := desired_move if phase == "ready" and stagger <= 0 else Vector2.ZERO
	velocity = Locomotion.steer(velocity, move * float(config.speed), delta, true)
	velocity.y -= 24 * delta
	move_and_slide()
	update_aim()

func safe_direction(direction: Vector3) -> Vector2:
	for candidate in [direction, Vector3(-direction.z, 0, direction.x) * navigation_side,
			Vector3(direction.z, 0, -direction.x) * navigation_side]:
		if arena.clear_sight(position, position + candidate * 0.9):
			return Vector2(candidate.x, candidate.z)
	return Vector2.ZERO

func begin_draw() -> void:
	phase = "draw"
	attack_time = 0
	locked = false
	hit_sent = false
	attacks += 1
	desired_move = Vector2.ZERO
	shot_target = arena.player.position + Vector3.UP
	rotation.y = Locomotion.facing(position, shot_target, rotation.y)
	visual.play_action("draw")
	acted.emit("bow_draw")

func on_motion_event(action: String, event: String) -> void:
	if dead or arena.ended or arena.paused:
		return
	if action == "draw" and event == "aim_ready" and phase == "draw":
		locked = true
		phase = "shoot"
		visual.play_action("shoot")
	elif action == "shoot" and event == "arrow_release" and phase == "shoot" and not hit_sent:
		hit_sent = true
		var origin: Vector3 = visual.release_origin()
		# Do not spawn a projectile through nearby cover when the bow protrudes.
		var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, origin, 1)
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			arena.launch_arrow(origin, shot_target, int(config.damage))
			shots += 1
			acted.emit("bow_release")
		aim_line.hide()
	elif action == "shoot" and event == "finished" and phase == "shoot":
		phase = "ready"
		attack_time = -1
		cooldown = RECOVERY
		visual.play("rest")

func update_aim() -> void:
	aim_line.visible = phase in ["draw", "shoot"] and not hit_sent and not dead and not arena.ended
	if not aim_line.visible:
		return
	var from := global_position + Vector3.UP * 0.075
	var to := Vector3(shot_target.x, from.y, shot_target.z)
	aim_line.global_position = (from + to) * 0.5
	if from.distance_to(to) > 0.05:
		aim_line.look_at(to, Vector3.UP)
	aim_line.scale = Vector3(1.6 if locked else 1.0, 1.0, maxf(0.05, from.distance_to(to)))
	aim_material.albedo_color = Color(1.0, 0.75, 0.35, 0.9) if locked else Color(0.94, 0.51, 0.22, 0.40)

func take_damage(amount: int) -> bool:
	var applied := super.take_damage(amount)
	if applied:
		phase = "ready"
		attack_time = -1
		aim_line.hide()
		cooldown = maxf(cooldown, 0.7)
	return applied
