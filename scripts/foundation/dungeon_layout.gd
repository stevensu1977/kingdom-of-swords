extends RefCounted

const Visual = preload("res://scripts/foundation/character_visual.gd")
const CONFIG := "res://assets/template/dungeon.json"

static func settings() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(CONFIG))

static func available() -> bool:
	for path in settings().scenes.values():
		if not ResourceLoader.exists("res://" + str(path)):
			return false
	return true

static func instance(parent: Node3D, scenes: Dictionary, role: String, point: Vector3, size: Vector3, yaw := 0.0, floor_piece := false) -> Node3D:
	var node := Node3D.new()
	node.name = role.capitalize()
	node.position = point
	node.rotation.y = yaw
	parent.add_child(node)
	var model: Node3D = load("res://" + str(scenes[role])).instantiate()
	node.add_child(model)
	var bounds := Visual.measure(model)
	var uniform := size.y / maxf(bounds.size.y, 0.01) if size.y > 0 else size.x / maxf(bounds.size.x, 0.01)
	var factor := Vector3.ONE * uniform
	if size.x > 0:
		factor.x = size.x / maxf(bounds.size.x, 0.01)
	if size.z > 0:
		factor.z = size.z / maxf(bounds.size.z, 0.01)
	model.scale *= factor
	model.position -= Vector3(bounds.get_center().x, bounds.end.y if floor_piece else bounds.position.y, bounds.get_center().z) * factor
	node.set_meta("collection_scene", scenes[role])
	return node

static func build(arena: Node3D) -> Node3D:
	var data := settings()
	var scenes: Dictionary = data.scenes
	var root := Node3D.new()
	root.name = "CollectionDungeon"
	arena.add_child(root)
	# Keep the courtyard's collision perimeter. Native floors and pillars retain their own collision too.
	for child in arena.get_children():
		var piece: String = child.get_meta("courtyard_piece", "")
		if piece == "Joint":
			child.queue_free()
		elif piece in ["Ground", "Boundary", "Pillar"]:
			for part in child.get_children():
				if part is MeshInstance3D:
					part.hide()
	for x in range(-8, 9, 4):
		for z in range(-10, 11, 4):
			instance(root, scenes, "center" if x == 0 and z in [-2, 2] else "floor", Vector3(x, 0.01, z), Vector3(4, 0, 4), 0, true)
	for x in range(-8, 9, 4):
		instance(root, scenes, "doorframe" if x == 0 else "wall", Vector3(x, 0, -12.7), Vector3(4, 4, 0))
		instance(root, scenes, "wall", Vector3(x, 0, 12.7), Vector3(4, 0.65, 0))
	instance(root, scenes, "door", Vector3(0, 0, -12.5), Vector3(0, 2.0, 0))
	for x in [-9.7, 9.7]:
		for z in range(-10, 11, 4):
			instance(root, scenes, "wall", Vector3(x, 0, z), Vector3(4, 3.0, 0), PI * 0.5)
	for x in [-7, 7]:
		for z in [-5, 5]:
			instance(root, scenes, "pillar", Vector3(x, 0, z), Vector3(1.0, 2.3, 1.0))
			instance(root, scenes, "torch", Vector3(x, 1.4, z + 0.53), Vector3(0, 0.8, 0))
	for point in [Vector3(-8.5, 0, -10), Vector3(8.5, 0, -9), Vector3(-8.5, 0, 9), Vector3(8.5, 0, 10)]:
		instance(root, scenes, "crate", point, Vector3(0, 0.95, 0))
		instance(root, scenes, "barrel", point + Vector3(0.8, 0, -0.9), Vector3(0, 1.05, 0))
	return root
