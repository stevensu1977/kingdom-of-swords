extends "res://scripts/foundation/melee_actor.gd"
## Game-specific holy skills; prepared movement, damage response, and rig stay inherited.

const SHIELD_DURATION := 3.0
const SHIELD_COOLDOWN := 24.0
const ShieldVisual = preload("res://scripts/divine_shield_visual.gd")

signal shield_blocked(actor)

var shielded := 0.0
var shield_cooldown := 0.0
var shield_casts := 0
var shield_blocks := 0
var shield_feedback_time := 0.0
var shield_visual: Node3D

func _ready() -> void:
	super._ready()
	if not enemy:
		add_to_group("ember_allies")
		shield_visual = ShieldVisual.new()
		shield_visual.name = "DivineShield"
		add_child(shield_visual)

func _physics_process(delta: float) -> void:
	advance_shield(delta)
	super._physics_process(delta)

func cast_divine_shield() -> bool:
	if enemy or dead or arena.paused or arena.ended or shielded > 0 or shield_cooldown > 0.0001:
		return false
	shielded = SHIELD_DURATION
	shield_cooldown = SHIELD_COOLDOWN
	shield_feedback_time = 0
	shield_casts += 1
	shield_visual.reveal()
	acted.emit("divine_shield")
	return true

func advance_shield(delta: float) -> void:
	if dead or arena.ended:
		cancel_divine_shield()
		return
	if arena.paused:
		return
	shield_cooldown = maxf(0, shield_cooldown - delta)
	shielded = maxf(0, shielded - delta)
	if shielded < 0.00001:
		shielded = 0
	shield_feedback_time = maxf(0, shield_feedback_time - delta)
	if shield_visual != null:
		shield_visual.animate(delta, shielded)

func cancel_divine_shield() -> void:
	shielded = 0
	if shield_visual != null:
		shield_visual.hide()

func register_shield_block(amount: int) -> void:
	if amount <= 0 or dead or arena.ended:
		return
	shield_blocks += 1
	if shield_visual != null:
		shield_visual.impact()
	if shield_feedback_time <= 0:
		shield_feedback_time = 0.25
		shield_blocked.emit(self)
		acted.emit("divine_shield_block")

func take_damage(amount: int) -> bool:
	if shielded > 0:
		register_shield_block(amount)
		return false
	return super.take_damage(amount)

func take_periodic_damage(amount: int) -> bool:
	if shielded > 0:
		register_shield_block(amount)
		return false
	if dead or dodge_time > 0 or arena.ended or amount <= 0:
		return false
	hp = maxi(0, hp - amount)
	hits_taken += 1
	# Burning must not cancel an attack, reset its clip, or apply sword-hit stagger.
	if hp == 0:
		dead = true
		velocity = Vector3.ZERO
		collision_layer = 0
		collision_mask = 0
		visual.animation.pause()
		died.emit(self)
	return true
