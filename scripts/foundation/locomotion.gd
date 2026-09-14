extends RefCounted
## Duckov movement tuning, independent of the visual rig and game rules.

const PLAYER_SPEED := 7.5
const PLAYER_ACCELERATION := 42.0
const PLAYER_BRAKING := 58.0
const PLAYER_REVERSAL := 68.0

static func steer(velocity: Vector3, target: Vector2, delta: float, enemy := false) -> Vector3:
	var planar := Vector2(velocity.x, velocity.z)
	var rate := 12.0 if enemy else PLAYER_ACCELERATION
	if target.is_zero_approx() or target.length_squared() < planar.length_squared():
		rate = 22.0 if enemy else PLAYER_BRAKING
	if planar.dot(target) < 0:
		rate = 24.0 if enemy else PLAYER_REVERSAL
	planar = planar.move_toward(target, rate * delta)
	return Vector3(planar.x, velocity.y, planar.y)

static func facing(origin: Vector3, target: Vector3, previous: float) -> float:
	var direction := target - origin
	return atan2(-direction.x, -direction.z) if Vector2(direction.x, direction.z).length() > 0.1 else previous
