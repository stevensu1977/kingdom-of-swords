extends Node3D
## Decoration around the intact Collection room. All collision is primitive.

# Shared by decoration, collision, interaction, and encounter navigation.
const POINTS := [Vector3(-5.8, 0, -6.8), Vector3(5.8, 0, -6.8), Vector3(0, 0, 6.8)]
var altar_nodes: Array[Node3D] = []
var fires: Array[Node3D] = []
var lights: Array[OmniLight3D] = []
var rings: Array[MeshInstance3D] = []
var motes: Array[MeshInstance3D] = []
var gate: Node3D
var gate_light: OmniLight3D
var gate_open_progress := -1.0
var clock := 0.0
var arena: Node3D

func _ready() -> void:
	for i in range(3):
		var altar: Node3D = load("res://assets/models/ember_altar.glb").instantiate()
		altar.position = POINTS[i]
		add_child(altar)
		darken_model(altar)
		altar_nodes.append(altar)
		var body := StaticBody3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.63
		shape.height = 1.2
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position.y = 0.6
		body.add_child(collision)
		altar.add_child(body)
		var flame := make_flame(POINTS[i] + Vector3.UP * 1.38, 0.8)
		flame.visible = false
		fires.append(flame)
		var light := make_light(POINTS[i] + Vector3.UP * 2.1, Color("ffb557"), 0.0, 5.5)
		lights.append(light)
		var ring := make_ring(POINTS[i] + Vector3.UP * 0.055, 1.35, Color("76684a"), 0.035)
		rings.append(ring)
		var number := Label3D.new()
		number.text = ["I", "II", "III"][i]
		number.font = load("res://assets/fonts/Title.ttf")
		number.font_size = 44
		number.pixel_size = 0.007
		number.modulate = Color("e7d3a5")
		number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		number.position = POINTS[i] + Vector3(0, 2.0, 0)
		add_child(number)
	var seal: Node3D = load("res://assets/models/crown_seal.glb").instantiate()
	seal.scale = Vector3(2.3, 1, 2.3)
	seal.position = Vector3(0, 0.045, -0.7)
	add_child(seal)
	darken_model(seal)
	for radius in [2.6, 2.8]:
		make_ring(Vector3(0, 0.055, -0.7), radius, Color("8a7043"), 0.018)
	for x in [-7.0, 7.0]:
		for z in [-5.0, 5.0]:
			make_flame(Vector3(x, 2.0, z + 0.55), 0.5)
	# Processional carpet, brass edges, and small inlaid studs.
	for z in [-9.5, -7.5, 9.5, 11.5]:
		block(Vector3(0, 0.029, z), Vector3(2.4, 0.018, 1.94), Color("3e474b"))
		for x in [-1.2, 1.2]:
			block(Vector3(x, 0.042, z), Vector3(0.025, 0.01, 1.90), Color("9b804d"))
	for x in [-8.9, 8.9]:
		for z in range(-10, 12, 2):
			block(Vector3(x, 0.04, z), Vector3(0.10, 0.015, 0.10), Color("aa8750"))
	# Large hanging standards define the back wall silhouette.
	for x in [-5.9, 5.9]:
		block(Vector3(x, 2.7, -12.22), Vector3(1.45, 2.4, 0.05), Color("203b42"))
		block(Vector3(x, 3.94, -12.20), Vector3(1.65, 0.10, 0.12), Color("91713e"))
		block(Vector3(x, 2.6, -12.18), Vector3(0.05, 1.5, 0.015), Color("c3a465"))
		block(Vector3(x, 2.8, -12.17), Vector3(0.6, 0.05, 0.02), Color("c3a465"))
	gate = Node3D.new()
	add_child(gate)
	for x in [-0.7, -0.35, 0.0, 0.35, 0.7]:
		var bar := block(Vector3(x, 1.7, -12.0), Vector3(0.06, 3.3, 0.08), Color("b9904e"))
		bar.reparent(gate)
	gate_light = make_light(Vector3(0, 2.5, -11.7), Color("77e7d2"), 0.1, 7)
	make_ring(Vector3(0, 0.06, -10.5), 1.35, Color("455f5c"), 0.03)
	var rng := RandomNumberGenerator.new()
	rng.seed = 492
	for index in range(48):
		var mote := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = rng.randf_range(0.013, 0.028)
		mesh.height = mesh.radius * 2
		mesh.radial_segments = 4
		mesh.rings = 2
		mote.mesh = mesh
		mote.material_override = mat(Color("a78b57"), true)
		mote.position = Vector3(rng.randf_range(-9, 9), rng.randf_range(0.4, 4), rng.randf_range(-12, 12))
		add_child(mote)
		motes.append(mote)

func _process(delta: float) -> void:
	if arena != null and arena.paused:
		return
	clock += delta
	if gate_open_progress >= 0.0:
		gate_open_progress = minf(1.5, gate_open_progress + delta)
		gate.position.y = 3.5 * smoothstep(0.0, 1.5, gate_open_progress)
	for i in range(fires.size()):
		fires[i].scale.y = 0.9 + sin(clock * 9 + i * 2) * 0.15
		if lights[i].light_energy > 0:
			lights[i].light_energy = 1.25 + sin(clock * 7.0 + i) * 0.10
	for i in range(motes.size()):
		motes[i].position.y += delta * 0.14
		motes[i].position.x += sin(clock * 0.6 + i) * delta * 0.025
		if motes[i].position.y > 4.0:
			motes[i].position.y = 0.4

func kindle(index: int) -> void:
	fires[index].show()
	lights[index].light_energy = 1.25
	rings[index].material_override = mat(Color("fac67d"), true)

func open_gate() -> void:
	gate_open_progress = 0.0
	gate_light.light_energy = 3
	make_ring(Vector3(0, 0.065, -10.5), 1.35, Color("79e9ce"), 0.07)

func make_light(point: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = point
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	add_child(light)
	return light

func darken_model(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for i in range(node.mesh.get_surface_count()):
			var source: Material = node.get_active_material(i)
			if source is StandardMaterial3D:
				var copy: StandardMaterial3D = source.duplicate()
				copy.albedo_color *= Color(0.60, 0.60, 0.60, 1.0)
				copy.metallic = 0.2
				node.set_surface_override_material(i, copy)
	for child in node.get_children():
		darken_model(child)

func make_flame(point: Vector3, amount: float) -> Node3D:
	var root := Node3D.new()
	root.position = point
	add_child(root)
	for i in range(3):
		var mesh := SphereMesh.new()
		mesh.radius = amount * (0.23 - i * 0.045)
		mesh.height = amount * (0.95 - i * 0.23)
		mesh.radial_segments = 5
		mesh.rings = 3
		var flame := MeshInstance3D.new()
		flame.mesh = mesh
		flame.position.y = amount * 0.22
		flame.rotation.z = (i - 1) * 0.15
		flame.material_override = mat([Color("d76325"), Color("ffb147"), Color("ffe0a0")][i], true)
		root.add_child(flame)
	return root

func block(point: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = point
	node.material_override = mat(color)
	add_child(node)
	return node

static func mat(color: Color, unshaded := false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.85
	if unshaded:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result

func make_ring(point: Vector3, radius: float, color: Color, width := 0.035) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - width
	mesh.outer_radius = radius + width
	mesh.rings = 64
	mesh.ring_segments = 6
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat(color, true)
	instance.position = point
	add_child(instance)
	return instance
