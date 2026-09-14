extends "res://test/archer_video.gd"

func _physics_process(delta: float) -> bool:
	super._physics_process(delta)
	if game != null and is_instance_valid(game):
		if game.ended:
			print("ARCHER COMBAT: won=%s kills=%d seals=%d hp=%d time=%.2f arrows=%d hits=%d deflected=%d attacks=%d dodges=%d" % [game.won, game.kills, game.seals, game.player.hp, game.elapsed, game.arrows_fired, game.arrow_hits, game.arrows_deflected, game.player.attacks, game.player.dodges])
			quit(0 if game.won else 1)
		elif clock > 150:
			print("ARCHER COMBAT TIMEOUT: kills=%d seals=%d hp=%d position=%s" % [game.kills, game.seals, game.player.hp, game.player.position])
			quit(2)
	return false
