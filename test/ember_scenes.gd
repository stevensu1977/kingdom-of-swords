extends SceneTree
## Instantiate every playable scene and all selected Collection leaves.

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var paths: Array[String] = [
		"res://scenes/ember.tscn", "res://scenes/menu.tscn",
		"res://scenes/melee.tscn"
	]
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/template/dungeon.json"))
	for path in data.scenes.values():
		paths.append("res://" + str(path))
	for path in paths:
		var packed: PackedScene = load(path)
		assert(packed != null, "Scene failed to load: " + path)
		var node: Node = packed.instantiate()
		root.add_child(node)
		await process_frame
		assert(node.is_node_ready(), "Scene failed ready: " + path)
		print("SCENE PASS: " + path)
		node.queue_free()
		await process_frame
	print("ALL %d SCENES: PASS" % paths.size())
	quit()
