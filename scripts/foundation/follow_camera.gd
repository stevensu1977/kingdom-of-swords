extends RefCounted
## Scene owners supply the subject, offset and limits; no raid state is read here.

const SMOOTHING := 9.0

static func target(subject: Vector3, limit: float, offset: Vector3) -> Vector3:
	return Vector3(clampf(subject.x, -limit, limit), 0, clampf(subject.z, -limit, limit)) + offset

static func follow(camera: Camera3D, destination: Vector3, delta: float) -> void:
	camera.position = camera.position.lerp(destination, 1.0 - exp(-SMOOTHING * delta))

static func aim(camera: Camera3D, mouse: Vector2, fallback: Vector3, height := 1.0) -> Vector3:
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	var intersection: Variant = Plane(Vector3.UP, height).intersects_ray(origin, direction)
	return intersection if intersection != null else fallback
