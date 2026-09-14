extends Node3D
## Physical travel with a swept collision segment: no hitscan damage or homing.

const SPEED := 10.0
const MAX_DISTANCE := 16.0
var arena: Node3D
var direction := Vector3.FORWARD
var damage := 8
var traveled := 0.0
var spent := false

func _ready() -> void:
	var model: Node3D = load("res://assets/models/bone_arrow.glb").instantiate()
	add_child(model)
	var tail := MeshInstance3D.new()
	var streak := BoxMesh.new()
	streak.size = Vector3(0.028, 0.028, 0.7)
	tail.mesh = streak
	tail.position.z = 0.65
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.73, 0.32, 0.72)
	tail.material_override = material
	tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tail)
	look_at(global_position + direction, Vector3.UP)

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if spent or arena.paused:
		return
	if arena.ended:
		retire()
		return
	var step := minf(SPEED * delta, MAX_DISTANCE - traveled)
	var next := global_position + direction * step
	var query := PhysicsRayQueryParameters3D.create(global_position, next, 1 | 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position
		if hit.collider == arena.player:
			if arena.player.take_damage(damage):
				arena.arrow_hits += 1
			else:
				arena.arrows_deflected += 1
		else:
			arena.arrows_stopped += 1
			arena.play_sound("arrow_impact")
			arena.burst(global_position, Color("#e4b881"), 4, 0.18)
		retire()
		return
	global_position = next
	traveled += step
	if traveled >= MAX_DISTANCE - 0.00001:
		retire()

func retire() -> void:
	if spent:
		return
	spent = true
	hide()
	queue_free()
