extends SceneTree
## Build the leaf game first, then its entry menu.

func _initialize() -> void:
	var game := Node3D.new()
	game.name = "TheLastEmber"
	game.set_script(load("res://scripts/ember_game.gd"))
	if not save_scene(game, "res://scenes/ember.tscn"):
		quit(1)
		return
	var menu := Control.new()
	menu.name = "EmberMenu"
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.set_script(load("res://scripts/ember_menu.gd"))
	if not save_scene(menu, "res://scenes/menu.tscn"):
		quit(1)
		return
	var startup := Control.new()
	startup.name = "Startup"
	startup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	startup.set_script(load("res://scripts/startup.gd"))
	if not save_scene(startup, "res://scenes/startup.tscn"):
		quit(1)
		return
	quit()

func count_nodes(node: Node) -> int:
	var result := 1
	for child in node.get_children():
		result += count_nodes(child)
	return result

func set_owners(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		if child.scene_file_path.is_empty():
			set_owners(child, root)

func save_scene(node: Node, path: String) -> bool:
	set_owners(node, node)
	var expected := count_nodes(node)
	var scene := PackedScene.new()
	if scene.pack(node) != OK:
		node.free()
		return false
	var check: Node = scene.instantiate()
	var got := count_nodes(check)
	check.free()
	node.free()
	if got != expected:
		push_error("Scene serialization dropped nodes")
		return false
	return ResourceSaver.save(scene, path) == OK
