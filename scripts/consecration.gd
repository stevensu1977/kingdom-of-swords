extends Node3D
## Fixed ground field. Simulation is advanced by the arena's paused-aware tick.

const COOLDOWN := 18.0
const DURATION := 6.0
const RADIUS := 3.0
const HEAL_FRACTION := 0.04
const DAMAGE := 6
const LUCKY_CHANCE := 0.12
const LUCKY_BONUS := 2
const PULSES := 6
const Visual = preload("res://scripts/consecration_visual.gd")

signal cast_started
signal pulsed(index: int)
signal healed(actor: CharacterBody3D, amount: int)
signal burned(actor: CharacterBody3D, amount: int, lucky: bool)

var arena: Node3D
var cooldown_remaining := 0.0
var active_remaining := 0.0
var active_elapsed := 0.0
var pulse_count := 0
var casts := 0
var total_healing := 0
var total_damage := 0
var lucky_hits := 0
var center := Vector3.ZERO
var rng := RandomNumberGenerator.new()
var field: Node3D
var healing_remainders: Dictionary = {}

func _ready() -> void:
	rng.randomize()
	field = Visual.new()
	field.radius = RADIUS
	add_child(field)
	field.hide()

func cast() -> bool:
	if arena.paused or arena.ended or arena.player.dead or cooldown_remaining > 0.0001 or active_remaining > 0:
		return false
	center = arena.player.global_position
	global_position = center
	cooldown_remaining = COOLDOWN
	active_remaining = DURATION
	active_elapsed = 0
	pulse_count = 0
	healing_remainders.clear()
	casts += 1
	field.reveal()
	arena.play_sound("consecration")
	cast_started.emit()
	return true

func advance(delta: float) -> void:
	if arena.paused or arena.ended:
		return
	cooldown_remaining = maxf(0, cooldown_remaining - delta)
	if active_remaining > 0:
		active_elapsed = minf(DURATION, active_elapsed + delta)
		active_remaining = maxf(0, DURATION - active_elapsed)
		# Exactly six pulses, at seconds 1 through 6; no free instant/seventh tick.
		while pulse_count < PULSES and active_elapsed + 0.00001 >= float(pulse_count + 1):
			pulse_count += 1
			apply_pulse()
		if active_remaining <= 0.00001:
			active_remaining = 0
			healing_remainders.clear()
	field.animate(delta, active_remaining > 0, active_elapsed)

func affects(actor: CharacterBody3D) -> bool:
	if not is_instance_valid(actor) or actor.dead:
		return false
	var offset: Vector3 = actor.global_position - center
	if Vector2(offset.x, offset.z).length_squared() > RADIUS * RADIUS or absf(offset.y) > 1.8:
		return false
	return arena.clear_sight(center, actor.global_position)

func apply_pulse() -> void:
	for ally in get_tree().get_nodes_in_group("ember_allies"):
		if not ally is CharacterBody3D or ally.arena != arena or ally.enemy or not affects(ally):
			continue
		var maximum := int(ally.config.health)
		if ally.hp >= maximum:
			healing_remainders[ally] = 0.0
			continue
		var healing: float = float(healing_remainders.get(ally, 0.0)) + maximum * HEAL_FRACTION
		var whole := floori(healing + 0.00001)
		healing_remainders[ally] = healing - whole
		var restored: int = mini(whole, maximum - int(ally.hp))
		ally.hp += restored
		if restored > 0:
			total_healing += restored
			healed.emit(ally, restored)
	for enemy in arena.enemies:
		if not affects(enemy):
			continue
		var lucky := rng.randf() < LUCKY_CHANCE
		var amount := DAMAGE + (LUCKY_BONUS if lucky else 0)
		var applied: int = mini(amount, int(enemy.hp))
		if enemy.take_periodic_damage(amount):
			total_damage += applied
			if lucky:
				lucky_hits += 1
			burned.emit(enemy, applied, lucky)
	field.pulse()
	arena.play_sound("consecration_tick")
	pulsed.emit(pulse_count)

func cancel() -> void:
	active_remaining = 0
	healing_remainders.clear()
	if field != null:
		field.hide()

func _exit_tree() -> void:
	healing_remainders.clear()
