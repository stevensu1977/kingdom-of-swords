extends Node3D

const Actor = preload("res://scripts/foundation/melee_actor.gd")
const PlayerInput = preload("res://scripts/foundation/player_input.gd")
const FollowCamera = preload("res://scripts/foundation/follow_camera.gd")
const DungeonLayout = preload("res://scripts/foundation/dungeon_layout.gd")

var player: CharacterBody3D
var enemies: Array[CharacterBody3D] = []
var camera: Camera3D
var paused := false
var ended := false
var won := false
var elapsed := 0.0
var camera_shake := 0.0
var kills := 0
var auto_control := false
var command_move := Vector2.ZERO
var command_aim := Vector3.ZERO
var command_attack := false
var command_dodge := false
var health_label: Label
var status_label: Label
var overlay: PanelContainer
var overlay_title: Label
var continue_button: Button
var ui: CanvasLayer
var effects: Node3D
var voices: Array[AudioStreamPlayer] = []
var voice_index := 0
var sound_enabled := true
var dungeon := false
var collection_layout: Node3D

func _ready() -> void:
	PlayerInput.install()
	build_world()
	dungeon = DungeonLayout.available()
	if dungeon:
		collection_layout = DungeonLayout.build(self)
	var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/character.json"))
	player = spawn(settings.hero, Vector3(0, 0, 6), false)
	for point in [Vector3(-4, 0, -2), Vector3(4, 0, -4), Vector3(0, 0, -8)]:
		enemies.append(spawn(settings.enemy, point, true))
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 17
	camera.rotation_degrees = Vector3(-55, 0, 0)
	add_child(camera)
	camera.position = FollowCamera.target(player.position, 4, Vector3(0, 18, 13))
	camera.current = true
	effects = Node3D.new()
	effects.name = "Effects"
	add_child(effects)
	for index in range(6):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -9
		add_child(voice)
		voices.append(voice)
	build_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if has_node("/root/Soundtrack"):
		get_node("/root/Soundtrack").player.stop()
	print("MELEE ARENA READY: " + ("POLYGON Dungeon" if dungeon else "Courtyard"))

func spawn(settings: Dictionary, point: Vector3, hostile: bool) -> CharacterBody3D:
	var actor := Actor.new()
	actor.config = settings
	actor.arena = self
	actor.enemy = hostile
	actor.position = point
	actor.name = "Enemy%d" % enemies.size() if hostile else "Player"
	add_child(actor)
	actor.struck.connect(resolve_attack)
	actor.died.connect(on_death)
	actor.damaged.connect(on_damage)
	actor.acted.connect(play_sound)
	return actor

func _physics_process(delta: float) -> void:
	if paused or ended:
		return
	elapsed += delta
	player.desired_move = command_move if auto_control else PlayerInput.movement(camera)
	player.desired_aim = command_aim if auto_control else FollowCamera.aim(camera, get_viewport().get_mouse_position(), player.position - player.basis.z, 0.9)
	player.attack_requested = command_attack if auto_control else Input.is_action_pressed("fire")
	player.dodge_requested = command_dodge if auto_control else Input.is_action_just_pressed("dodge")
	command_dodge = false
	for enemy in enemies:
		if enemy.dead:
			continue
		var direction: Vector3 = player.position - enemy.position
		var distance: float = Vector2(direction.x, direction.z).length()
		enemy.desired_aim = player.position
		enemy.desired_move = Vector2(direction.x, direction.z).normalized() if distance > 1.65 and distance < 15 else Vector2.ZERO
		if not enemy.desired_move.is_zero_approx():
			var heading := Vector3(enemy.desired_move.x, 0, enemy.desired_move.y)
			if not clear_sight(enemy.position, enemy.position + heading * 1.0):
				var side := Vector3(-heading.z, 0, heading.x)
				if not clear_sight(enemy.position, enemy.position + side):
					side = -side
				enemy.desired_move = Vector2(side.x, side.z)
		enemy.attack_requested = distance < 2.05 and clear_sight(enemy.position, player.position)

func _process(delta: float) -> void:
	if player == null:
		return
	if not paused:
		FollowCamera.follow(camera, FollowCamera.target(player.position, 4, Vector3(0, 18, 13)), delta)
		camera_shake = move_toward(camera_shake, 0, delta * 1.8)
		camera.position.x += sin(elapsed * 75) * camera_shake
	ui.scale = get_viewport().get_visible_rect().size / Vector2(1280, 720)
	health_label.text = "HEALTH  %d / 100" % player.hp
	status_label.text = "%s  /  %d / %d CLEARED" % ["DUNGEON" if dungeon else "COURTYARD", kills, enemies.size()]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if ended:
			return_menu()
		else:
			toggle_pause()
	elif event.is_action_pressed("reload") and ended:
		restart()

func clear_sight(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP, to + Vector3.UP, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func resolve_attack(attacker: CharacterBody3D) -> void:
	var targets: Array = [player] if attacker.enemy else enemies
	for target in targets:
		if target.dead:
			continue
		var direction: Vector3 = target.global_position - attacker.global_position
		direction.y = 0
		if direction.length() > float(attacker.config.range) or (-attacker.basis.z).dot(direction.normalized()) < 0.25:
			continue
		if clear_sight(attacker.global_position, target.global_position):
			target.take_damage(int(attacker.config.damage))

func on_damage(actor: CharacterBody3D, amount: int) -> void:
	play_sound("sword_impact")
	camera_shake = 0.07 if actor.enemy else 0.12
	var color := Color("f0c891") if actor.enemy else Color("e37663")
	for index in range(7):
		var shard := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.035
		mesh.height = 0.07
		mesh.radial_segments = 6
		mesh.rings = 3
		shard.mesh = mesh
		shard.material_override = material(color, true)
		shard.position = actor.position + Vector3(0, 1.1, 0)
		effects.add_child(shard)
		var angle := TAU * index / 7.0
		var tween := shard.create_tween().set_parallel()
		tween.tween_property(shard, "position", shard.position + Vector3(cos(angle), 0.3, sin(angle)) * 0.65, 0.22)
		tween.tween_property(shard, "scale", Vector3.ZERO, 0.22)
		tween.chain().tween_callback(shard.queue_free)
	var label := Label3D.new()
	label.text = str(amount)
	label.font_size = 52
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.position = actor.position + Vector3(0, 2.1, 0)
	effects.add_child(label)
	var fade := label.create_tween()
	fade.tween_property(label, "position:y", label.position.y + 0.65, 0.45)
	fade.tween_callback(label.queue_free)

func on_death(actor: CharacterBody3D) -> void:
	if actor == player:
		finish(false)
	else:
		kills += 1
		if kills == enemies.size():
			finish(true)

func finish(victory: bool) -> void:
	ended = true
	won = victory
	show_overlay(("DUNGEON CLEARED" if dungeon else "COURTYARD CLEARED") if victory else "YOU FELL")
	continue_button.hide()

func toggle_pause() -> void:
	paused = not paused
	for actor in enemies + [player]:
		actor.visual.animation.active = not paused
	effects.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	for voice in voices:
		voice.stream_paused = paused
	if paused:
		show_overlay("PAUSED")
		continue_button.show()
	else:
		overlay.hide()
		Input.action_release("fire")

func show_overlay(title: String) -> void:
	overlay_title.text = title
	overlay.show()

func restart() -> void:
	Input.action_release("fire")
	get_tree().reload_current_scene()

func return_menu() -> void:
	Input.action_release("fire")
	if has_node("/root/Soundtrack") and DisplayServer.get_name() != "headless":
		get_node("/root/Soundtrack").player.play()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func play_sound(cue: String) -> void:
	if not sound_enabled or voices.is_empty():
		return
	var voice := voices[voice_index % voices.size()]
	voice_index += 1
	voice.stream = load("res://assets/audio/%s.wav" % cue)
	voice.play()

func build_world() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("10171e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b0bccc")
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color("d8e1ed")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	box("Ground", Vector3(0, -0.15, 0), Vector3(20, 0.3, 26), Color("343b41"), true)
	for x in range(-10, 11, 2):
		box("Joint", Vector3(x, 0.003, 0), Vector3(0.025, 0.005, 26), Color("20282e"))
	for z in range(-12, 13, 2):
		box("Joint", Vector3(0, 0.003, z), Vector3(20, 0.005, 0.025), Color("20282e"))
	for x in [-10, 10]:
		box("Boundary", Vector3(x, 0.8, 0), Vector3(0.6, 1.6, 26), Color("495057"), true)
	for z in [-13, 13]:
		box("Boundary", Vector3(0, 0.8, z), Vector3(20, 1.6, 0.6), Color("495057"), true)
	for point in [Vector3(-7, 0, -5), Vector3(7, 0, -5), Vector3(-7, 0, 5), Vector3(7, 0, 5)]:
		box("Pillar", point + Vector3.UP, Vector3(1.0, 2, 1.0), Color("687075"), true)
		var light := OmniLight3D.new()
		light.position = point + Vector3(0, 2.4, 0)
		light.light_color = Color("ffc37c")
		light.light_energy = 2
		light.omni_range = 6
		add_child(light)

func box(title: String, point: Vector3, size: Vector3, color: Color, solid := false) -> Node3D:
	var node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	node.name = title
	node.set_meta("courtyard_piece", title)
	node.position = point
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material(color)
	node.add_child(instance)
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.shape = shape
		node.add_child(collider)
	add_child(node)
	return node

func material(color: Color, glowing := false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.85
	if glowing:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result

func build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var top := PanelContainer.new()
	top.position = Vector2(24, 22)
	top.add_theme_stylebox_override("panel", panel_style())
	ui.add_child(top)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	top.add_child(rows)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 20)
	rows.add_child(status_label)
	health_label = Label.new()
	health_label.add_theme_color_override("font_color", Color("ecc39b"))
	rows.add_child(health_label)
	var hint := Label.new()
	hint.text = "WASD  Move   /   Mouse + LMB  Attack   /   Space  Dodge   /   ESC  Pause"
	hint.position = Vector2(24, 676)
	ui.add_child(hint)
	overlay = PanelContainer.new()
	overlay.position = Vector2(460, 230)
	overlay.size = Vector2(360, 260)
	overlay.add_theme_stylebox_override("panel", panel_style())
	ui.add_child(overlay)
	var options := VBoxContainer.new()
	options.add_theme_constant_override("separation", 16)
	overlay.add_child(options)
	overlay_title = Label.new()
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title.add_theme_font_size_override("font_size", 26)
	options.add_child(overlay_title)
	continue_button = Button.new()
	continue_button.text = "Resume"
	continue_button.pressed.connect(toggle_pause)
	options.add_child(continue_button)
	var retry := Button.new()
	retry.text = "Play again"
	retry.pressed.connect(restart)
	options.add_child(retry)
	var leave := Button.new()
	leave.text = "Return to menu"
	leave.pressed.connect(return_menu)
	options.add_child(leave)
	overlay.hide()

func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.11, 0.94)
	style.border_color = Color("72634c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style
