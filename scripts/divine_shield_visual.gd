extends Node3D
## A translucent golden shell follows the actor without changing its rig or collision.

var age := 0.0
var flash := 0.0
var shell: ShaderMaterial
var gold: StandardMaterial3D
var orbit: MeshInstance3D
var light: OmniLight3D
var sparks: Array[MeshInstance3D] = []

func _ready() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;
uniform float strength = 1.0;
uniform float flash = 0.0;
void fragment() {
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 2.8);
	ALBEDO = mix(vec3(0.94, 0.64, 0.20), vec3(1.0, 0.96, 0.72), rim + flash * 0.2);
	ALPHA = (0.035 + rim * 0.55 + flash * 0.12) * strength;
}
"""
	shell = ShaderMaterial.new()
	shell.shader = shader
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	var bubble := add_mesh(sphere, Vector3(0, 1.29, 0), shell)
	bubble.scale = Vector3(1.10, 1.27, 1.10)
	gold = StandardMaterial3D.new()
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gold.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gold.albedo_color = Color("ffe5a0")
	ring(0.93, 0.014, Vector3(0, 0.06, 0))
	ring(0.64, 0.012, Vector3(0, 2.27, 0))
	orbit = ring(1.13, 0.011, Vector3(0, 1.29, 0))
	orbit.rotation = Vector3(PI * 0.5, 0, 0.35)
	orbit.scale.z = 1.12
	var mote := SphereMesh.new()
	mote.radius = 0.022
	mote.height = 0.044
	mote.radial_segments = 4
	mote.rings = 2
	for i in range(12):
		sparks.append(add_mesh(mote, Vector3.ZERO, gold))
	light = OmniLight3D.new()
	light.name = "HolyRim"
	light.position = Vector3(0, 1.7, 0)
	light.light_color = Color("ffdd8b")
	light.omni_range = 3.3
	light.light_energy = 0.8
	add_child(light)
	hide()

func reveal() -> void:
	age = 0
	flash = 0.8
	show()
	animate(0, 3.0)

func impact() -> void:
	flash = 1.0

func animate(delta: float, remaining: float) -> void:
	if remaining <= 0:
		hide()
		return
	if not visible:
		show()
	age += delta
	flash = maxf(0, flash - delta * 4)
	var strength := minf(1.0, remaining / 0.25)
	shell.set_shader_parameter("strength", strength)
	shell.set_shader_parameter("flash", flash)
	gold.albedo_color.a = strength * (0.68 + flash * 0.3)
	light.light_energy = strength * (0.70 + flash * 0.5)
	orbit.rotation.y = age * 0.55
	for i in range(sparks.size()):
		var angle := TAU * i / sparks.size() + age * 0.7
		var height := fmod(i * 0.21 + age * 0.65, 2.3)
		var radius := 1.08 * sqrt(maxf(0.05, 1.0 - pow((height - 1.15) / 1.3, 2)))
		sparks[i].position = Vector3(sin(angle) * radius, height + 0.1, cos(angle) * radius)
		sparks[i].scale = Vector3.ONE * (0.65 + 0.35 * sin(age * 3 + i))

func ring(radius: float, width: float, point: Vector3) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - width
	mesh.outer_radius = radius + width
	mesh.rings = 64
	mesh.ring_segments = 4
	return add_mesh(mesh, point, gold)

func add_mesh(mesh: Mesh, point: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = point
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node
