extends SceneTree
## A public checkout must explain missing artwork without instantiating it.

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var startup: Control = load("res://scenes/startup.tscn").instantiate()
	root.add_child(startup)
	current_scene = startup
	await process_frame
	await process_frame
	if not is_instance_valid(startup) or startup.missing_assets.is_empty():
		push_error("This check needs a source-only checkout without external assets.")
		quit(1)
		return
	assert(startup.find_child("MissingAssets", true, false) != null)
	assert(current_scene == startup, "A source-only checkout must not load incomplete gameplay")
	print("SOURCE CHECKOUT: PASS — missing dependencies are explained without loading the game")
	startup.queue_free()
	current_scene = null
	await process_frame
	quit(0)
