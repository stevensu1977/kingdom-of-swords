extends CharacterBody3D

signal struck(attacker)
signal died(actor)
signal damaged(actor, amount)
signal acted(cue)

const Locomotion = preload("res://scripts/foundation/locomotion.gd")
const CharacterVisual = preload("res://scripts/foundation/character_visual.gd")

var config: Dictionary
var arena: Node3D
var enemy := false
var hp := 100
var visual: Node3D
var desired_move := Vector2.ZERO
var desired_aim := Vector3.ZERO
var attack_requested := false
var dodge_requested := false
var attack_time := -1.0
var hit_sent := false
var cooldown := 0.0
var stagger := 0.0
var dodge_time := 0.0
var dodge_cooldown := 0.0
var dodge_direction := Vector3.ZERO
var dead := false
var death_time := 0.0
var alternate := false
var hits_taken := 0
var attacks := 0
var dodges := 0

func _ready() -> void:
	hp = int(config.health)
	collision_layer = 4 if enemy else 2
	collision_mask = 1 | 2 | 4
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.8
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.9
	add_child(collider)
	visual = CharacterVisual.new()
	visual.name = "Character"
	visual.rotation.y = PI
	add_child(visual)
	visual.prepare(config)

func _physics_process(delta: float) -> void:
	if arena.paused:
		return
	if dead:
		death_time = minf(death_time + delta, 0.6)
		visual.rotation.z = lerpf(0, 1.48, smoothstep(0, 0.6, death_time))
		visual.position.y = sin(visual.rotation.z) * 0.3
		return
	if arena.ended:
		visual.play(config.idle)
		return
	cooldown = maxf(0, cooldown - delta)
	stagger = maxf(0, stagger - delta)
	dodge_cooldown = maxf(0, dodge_cooldown - delta)
	if dodge_requested and not enemy and dodge_cooldown == 0 and stagger == 0:
		dodge_time = 0.24
		dodge_cooldown = 0.9
		dodge_direction = Vector3(desired_move.x, 0, desired_move.y).normalized()
		if dodge_direction.is_zero_approx():
			dodge_direction = -basis.z
		attack_time = -1
		dodges += 1
		acted.emit("dodge")
	if attack_requested and attack_time < 0 and cooldown == 0 and stagger == 0 and dodge_time == 0:
		rotation.y = Locomotion.facing(global_position, desired_aim, rotation.y)
		attack_time = 0
		hit_sent = false
		attacks += 1
		acted.emit("sword_swing")
		var clip: String = config.alternate if alternate and config.has("alternate") else config.attack
		alternate = not alternate
		visual.play(clip)
		visual.animation.seek(0, true)
	attack_requested = false
	dodge_requested = false
	if attack_time >= 0:
		attack_time += delta
		if not hit_sent and attack_time >= float(config.impact):
			hit_sent = true
			struck.emit(self)
		if attack_time >= float(config.duration):
			attack_time = -1
			cooldown = 0.18 if enemy else 0.06
	var motion_scale := 0.0 if stagger > 0 else (0.12 if attack_time >= 0 else 1.0)
	velocity = Locomotion.steer(velocity, desired_move.limit_length() * float(config.speed) * motion_scale, delta, enemy)
	if dodge_time > 0:
		dodge_time = maxf(0, dodge_time - delta)
		velocity.x = dodge_direction.x * 11.0
		velocity.z = dodge_direction.z * 11.0
	if attack_time < 0 and stagger == 0:
		var facing_target := global_position + Vector3(desired_move.x, 0, desired_move.y) * 2.0 if desired_move.length() > 0.01 else desired_aim
		rotation.y = Locomotion.facing(global_position, facing_target, rotation.y)
	velocity.y -= 24 * delta
	var before := position
	move_and_slide()
	var actual_speed := Vector2(position.x - before.x, position.z - before.z).length() / maxf(delta, 0.0001)
	if attack_time < 0:
		var walking := actual_speed > 0.15
		visual.play(config.move if walking else config.idle, clampf(actual_speed / float(config.speed), 0.25, 2.5) if walking else 1.0)
	visual.rotation.x = -0.10 * stagger / 0.2

func take_damage(amount: int) -> bool:
	if dead or dodge_time > 0 or arena.ended:
		return false
	hp = maxi(0, hp - amount)
	hits_taken += 1
	stagger = 0.18
	attack_time = -1
	cooldown = maxf(cooldown, 0.25)
	visual.play(config.idle)
	damaged.emit(self, amount)
	if hp == 0:
		dead = true
		velocity = Vector3.ZERO
		collision_layer = 0
		collision_mask = 0
		visual.animation.pause()
		died.emit(self)
	return true
