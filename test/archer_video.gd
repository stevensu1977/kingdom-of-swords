extends "res://test/ember_video.gd"
## Uses only normal movement/attack/skill commands against the real mixed waves.

var archer_reported := false
var seeded := false

func drive(delta: float) -> void:
	super.drive(delta)
	if not seeded:
		game.consecration.rng.seed = 2026
		seeded = true
	var nearby := 0
	var melee_threat: CharacterBody3D
	for enemy in game.enemies:
		if enemy.dead:
			continue
		var distance: float = enemy.position.distance_to(game.player.position)
		if distance < 3.0:
			nearby += 1
		if enemy.get_meta("archetype", "") != "archer" and distance < 2.6 and enemy.attack_time > 0.16 and enemy.attack_time < 0.45:
			melee_threat = enemy
	if game.consecration.cooldown_remaining <= 0 and (nearby >= 2 or game.player.hp <= 78):
		game.command_consecrate = true
	var incoming: Node3D
	for arrow in game.projectiles.get_children():
		if arrow.spent:
			continue
		var offset: Vector3 = game.player.global_position + Vector3.UP - arrow.global_position
		if offset.length() < 3.2 and offset.normalized().dot(arrow.direction) > 0.7:
			incoming = arrow
			break
	if incoming != null and game.player.shield_cooldown <= 0:
		game.command_shield = true
	elif game.player.shielded <= 0 and game.player.dodge_cooldown <= 0:
		if incoming != null:
			game.command_move = Vector2(-incoming.direction.z, incoming.direction.x).normalized()
			game.command_dodge = true
		elif melee_threat != null and game.player.attack_time < 0:
			var away: Vector3 = game.player.position - melee_threat.position
			game.command_move = Vector2(away.x, away.z).normalized()
			game.command_dodge = true
	if game.player.shielded > 0:
		game.command_dodge = false
	if clock >= 17.85 and not archer_reported:
		archer_reported = true
		print("ARCHER VIDEO: fired=%d hit=%d deflected=%d cover=%d shield_blocks=%d consecrations=%d" % [game.arrows_fired, game.arrow_hits, game.arrows_deflected, game.arrows_stopped, game.player.shield_blocks, game.consecration.casts])
