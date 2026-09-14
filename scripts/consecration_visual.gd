extends Node3D
## Code-native holy light, translucent ground sigil, and rising sparks.

var radius := 3.0
var age := 0.0
var strength := 0.0
var pulse_strength := 0.0
var soft_gold: StandardMaterial3D
var bright_gold: StandardMaterial3D
var floor_material: StandardMaterial3D
var pillar_material: StandardMaterial3D
var outer: MeshInstance3D
var expanding: MeshInstance3D
var rays: Array[MeshInstance3D] = []
var sparks: Array[MeshInstance3D] = []
var light: OmniLight3D

func _ready() -> void:
	soft_gold = luminous(Color("f3c974"), 0.55)
	bright_gold = luminous(Color("fff0b8"), 0.90)
	floor_material = luminous(Color("e7b650"), 0.10)
	pillar_material = luminous(Color("fff0bb"), 0.08)
	var disk := CylinderMesh.new()
	disk.top_radius = radius
	disk.bottom_radius = radius
	disk.height = 0.008
	disk.radial_segments = 80
	add_mesh(disk, Vector3(0, 0.06, 0), floor_material)
	outer = ring(radius, 0.023, 0.075, bright_gold)
	ring(radius - 0.17, 0.010, 0.078, soft_gold)
	ring(0.67, 0.016, 0.08, soft_gold)
	expanding = ring(radius, 0.023, 0.085, soft_gold)
	for i in range(16):
		var angle := TAU * i / 16.0
		var mark := BoxMesh.new()
		mark.size = Vector3(0.04, 0.014, 0.19 if i % 2 else 0.34)
		var glyph := add_mesh(mark, Vector3(sin(angle), 0, cos(angle)) * (radius - 0.40) + Vector3.UP * 0.08, bright_gold)
		glyph.rotation.y = angle
		# Slender columns suggest falling light without obscuring actors.
		if i % 2 == 0:
			var shaft := CylinderMesh.new()
			shaft.top_radius = 0.009
			shaft.bottom_radius = 0.045
			shaft.height = 2.5
			shaft.radial_segments = 5
			var ray := add_mesh(shaft, Vector3(sin(angle), 0, cos(angle)) * (radius - 0.13) + Vector3.UP * 1.32, pillar_material)
			rays.append(ray)
	for size in [Vector3(0.08, 0.014, 0.9), Vector3(0.65, 0.014, 0.08)]:
		var cross := BoxMesh.new()
		cross.size = size
		add_mesh(cross, Vector3(0, 0.084, -0.10), soft_gold)
	for i in range(24):
		var mote := SphereMesh.new()
		mote.radius = 0.018 if i % 3 else 0.028
		mote.height = mote.radius * 2
		mote.radial_segments = 4
		mote.rings = 2
		sparks.append(add_mesh(mote, Vector3.ZERO, bright_gold))
	light = OmniLight3D.new()
	light.position = Vector3(0, 1.6, 0)
	light.light_color = Color("ffdfa0")
	light.omni_range = radius + 1.0
	light.light_energy = 0
	add_child(light)

func reveal() -> void:
	age = 0
	strength = 0
	pulse_strength = 1
	show()

func pulse() -> void:
	pulse_strength = 1.0

func animate(delta: float, active: bool, elapsed: float) -> void:
	if not visible:
		return
	age += delta
	strength = move_toward(strength, 1.0 if active else 0.0, delta * (5.0 if active else 3.0))
	pulse_strength = maxf(0, pulse_strength - delta * 2.7)
	soft_gold.albedo_color.a = strength * (0.42 + pulse_strength * 0.28)
	bright_gold.albedo_color.a = strength * (0.64 + pulse_strength * 0.31)
	floor_material.albedo_color.a = strength * (0.075 + pulse_strength * 0.075)
	pillar_material.albedo_color.a = strength * (0.06 + pulse_strength * 0.07)
	light.light_energy = strength * (0.45 + pulse_strength * 0.3)
	var growth := smoothstep(0, 0.25, elapsed)
	outer.scale = Vector3.ONE * lerpf(0.82, 1.0, growth)
	expanding.scale = Vector3.ONE * (0.26 + (1.0 - pulse_strength) * 0.74)
	for i in range(rays.size()):
		rays[i].scale.y = 0.85 + sin(age * 2.5 + i * 1.7) * 0.15
	for i in range(sparks.size()):
		var angle := TAU * i / sparks.size() + age * 0.10
		var distance := 0.5 + fmod(i * 0.73, radius - 0.6)
		var height := fmod(age * 0.8 + i * 0.19, 2.3)
		sparks[i].position = Vector3(sin(angle) * distance, height + 0.1, cos(angle) * distance)
		sparks[i].scale = Vector3.ONE * (0.45 + 0.55 * sin(PI * height / 2.3))
	if not active and strength <= 0:
		hide()

func ring(size: float, width: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = size - width
	mesh.outer_radius = size + width
	mesh.rings = 72
	mesh.ring_segments = 4
	return add_mesh(mesh, Vector3(0, height, 0), material)

func add_mesh(mesh: Mesh, point: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = point
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func luminous(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
