extends "res://scripts/melee_arena.gd"
## Three encounters, three seals, one escape; foundation simulation is inherited.

signal music_changed

const World = preload("res://scripts/ember_world.gd")
const HUD = preload("res://scripts/ember_hud.gd")
const CombatActor = preload("res://scripts/ember_actor.gd")
const Consecration = preload("res://scripts/consecration.gd")
const Archer = preload("res://scripts/skeleton_archer.gd")
const Arrow = preload("res://scripts/arrow_projectile.gd")
const BGM_VOLUME_DB := -8.0
const PUBLIC_BGM := "res://assets/audio/ember_ambience.ogg"
const LOCAL_BGM := "res://assets/models/Chambre Maudite.ogg"
var archer_settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/archer.json"))
var projectiles: Node3D
var arrows_fired := 0
var arrow_hits := 0
var arrows_deflected := 0
var arrows_stopped := 0
var decoration: Node3D
var seals := 0
var wave := 1
var wave_cleared := false
var next_wave_time := -1.0
var interaction_hint := ""
var banner_title := ""
var banner_subtitle := ""
var banner_time := 0.0
var hurt_flash := 0.0
var command_interact := false
var hud: Control
var ambient: AudioStreamPlayer
var settings: Dictionary
var tells: Dictionary = {}
var overlay_detail: Label
var total_kills := 0
var best_time := 0.0
var record_results := true
var material_cache: Dictionary = {}
var consecration: Node3D
var command_consecrate := false
var command_shield := false
var music_enabled := true
var menu_preview := false

func _ready() -> void:
	var soundtrack := get_node_or_null("/root/Soundtrack")
	if soundtrack != null:
		music_enabled = soundtrack.music_enabled
	super._ready()
	if not InputMap.has_action("consecrate"):
		InputMap.add_action("consecrate")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_Q
		InputMap.action_add_event("consecrate", key)
	if not InputMap.has_action("divine_shield"):
		InputMap.add_action("divine_shield")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_F
		InputMap.action_add_event("divine_shield", key)
	tone_collection(collection_layout)
	settings = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/character.json"))
	projectiles = Node3D.new()
	projectiles.name = "Arrows"
	add_child(projectiles)
	player.position = Vector3(-6.2, 0, 9.2)
	camera.position = FollowCamera.target(player.position, 4, Vector3(0, 18, 13))
	decoration = World.new()
	decoration.arena = self
	add_child(decoration)
	consecration = Consecration.new()
	consecration.name = "Consecration"
	consecration.arena = self
	add_child(consecration)
	consecration.healed.connect(on_consecration_heal)
	consecration.burned.connect(on_consecration_burn)
	var rim := OmniLight3D.new()
	rim.name = "WardenRim"
	rim.position = Vector3(0, 2.8, 0.8)
	rim.light_color = Color("#d3e6e7")
	rim.light_energy = 1.2
	rim.omni_range = 3.2
	player.add_child(rim)
	for i in range(enemies.size()):
		enemies[i].position = [Vector3(-3.3, 0, 1.2), Vector3(3.3, 0, -1.0), Vector3(5.5, 0, 1.0)][i]
		add_tell(enemies[i])
	var mark: MeshInstance3D = decoration.make_ring(Vector3(0, 0.03, 0), 0.59, Color("e4cc92"), 0.018)
	mark.reparent(player, false)
	ambient = AudioStreamPlayer.new()
	var music_path := LOCAL_BGM if ResourceLoader.exists(LOCAL_BGM) else PUBLIC_BGM
	var track: AudioStreamOggVorbis = load(music_path)
	track.loop = true
	ambient.stream = track
	ambient.volume_db = BGM_VOLUME_DB
	add_child(ambient)
	ambient.stream_paused = true
	if DisplayServer.get_name() != "headless":
		ambient.play()
	update_music_state()
	show_banner("The First Watch", "Two blades. One bow. Break the watch, then kindle its seal.")
	print("EMBER READY: collection=%s, prepared paladin, wave=1" % dungeon)

func spawn(actor_settings: Dictionary, point: Vector3, hostile: bool) -> CharacterBody3D:
	var ranged: bool = actor_settings.get("archetype", "") == "archer" or (hostile and wave == 1 and enemies.size() == 2)
	var actor: CharacterBody3D = Archer.new() if ranged else CombatActor.new()
	actor.config = archer_settings.duplicate(true) if ranged else actor_settings
	if ranged:
		actor.config.initial_delay = 0.8 + enemies.size() * 0.17
	actor.arena = self
	actor.enemy = hostile
	actor.position = point
	actor.name = "Enemy%d" % enemies.size() if hostile else "Player"
	add_child(actor)
	actor.struck.connect(resolve_attack)
	actor.died.connect(on_death)
	actor.damaged.connect(on_damage)
	actor.acted.connect(play_sound)
	actor.shield_blocked.connect(on_shield_blocked)
	return actor

func build_world() -> void:
	super.build_world()
	for child in get_children():
		if child is WorldEnvironment:
			child.environment.background_color = Color("#14252e")
			child.environment.ambient_light_color = Color("#8daebb")
			child.environment.ambient_light_energy = 0.35
			child.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		elif child is DirectionalLight3D:
			child.light_color = Color("#c3d9dd")
			child.light_energy = 0.85
			child.rotation_degrees = Vector3(-58, -32, 0)
		elif child is OmniLight3D:
			child.light_energy = 1.15
			child.light_color = Color("#ffac58")

func tone_collection(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for i in range(node.mesh.get_surface_count()):
			var source: Material = node.get_active_material(i)
			if source is StandardMaterial3D:
				if not material_cache.has(source):
					var material: StandardMaterial3D = source.duplicate()
					material.albedo_color = Color("#6f8386")
					material.emission_enabled = false
					material.roughness = 0.92
					material_cache[source] = material
				node.set_surface_override_material(i, material_cache[source])
	for child in node.get_children():
		tone_collection(child)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if paused or ended:
		command_consecrate = false
		command_shield = false
		return
	if command_shield or (not auto_control and Input.is_action_just_pressed("divine_shield")):
		player.cast_divine_shield()
	command_shield = false
	consecration.advance(delta)
	if command_consecrate or (not auto_control and Input.is_action_just_pressed("consecrate")):
		consecration.cast()
	command_consecrate = false
	banner_time = maxf(0, banner_time - delta)
	hurt_flash = maxf(0, hurt_flash - delta * 2)
	if next_wave_time >= 0:
		next_wave_time -= delta
		if next_wave_time <= 0:
			next_wave_time = -1
			start_wave()
	interaction_hint = ""
	if wave_cleared and seals < 3:
		if player.position.distance_to(World.POINTS[seals]) < 2.3:
			interaction_hint = "Kindle seal %s  ·  restore 30 vitality" % ["I", "II", "III"][seals]
			if command_interact or Input.is_action_just_pressed("interact"):
				kindle()
	elif seals == 3 and player.position.distance_to(Vector3(0, 0, -10.5)) < 2.4:
		interaction_hint = "Leave the sanctum"
		if command_interact or Input.is_action_just_pressed("interact"):
			finish(true)
	command_interact = false
	for enemy in enemies:
		var tell: Node3D = tells.get(enemy)
		if is_instance_valid(tell):
			tell.visible = not enemy.dead and enemy.attack_time >= 0 and enemy.attack_time < float(enemy.config.impact)
			if tell.visible:
				var progress: float = enemy.attack_time / float(enemy.config.impact)
				tell.scale = Vector3.ONE * (0.7 + progress * 0.3)
	if decoration != null and wave_cleared and seals < 3:
		decoration.rings[seals].material_override = World.mat(Color("#dabe7c") * (0.8 + 0.2 * sin(elapsed * 4)), true)

func _process(delta: float) -> void:
	super._process(delta)
	if hud != null:
		hud.scale = Vector2.ONE

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("music"):
		toggle_music()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("mute"):
		sound_enabled = not sound_enabled
		update_music_state()
		get_viewport().set_input_as_handled()
	elif not menu_preview:
		super._unhandled_input(event)

func toggle_music() -> void:
	var soundtrack := get_node_or_null("/root/Soundtrack")
	if soundtrack != null:
		soundtrack.toggle_music()
		music_enabled = soundtrack.music_enabled
	else:
		music_enabled = not music_enabled
	update_music_state()

func update_music_state() -> void:
	if ambient != null:
		ambient.stream_paused = not music_enabled or not sound_enabled or (paused and not menu_preview)
	music_changed.emit()

func make_music_button() -> Button:
	var button := Button.new()
	button.name = "BGMToggle"
	button.toggle_mode = true
	HUD.button_theme(button)
	button.pressed.connect(toggle_music)
	music_changed.connect(func(): update_music_button(button))
	update_music_button(button)
	return button

func update_music_button(button: Button) -> void:
	button.text = "BGM: %s  /  N" % ("ON" if music_enabled else "OFF")
	button.set_pressed_no_signal(music_enabled)
	button.tooltip_text = "Background music only. Press N to toggle.\nSound-effect settings are unchanged."
	if not sound_enabled:
		button.tooltip_text += "\nAll audio is currently muted with M."

func add_tell(enemy: CharacterBody3D) -> void:
	if enemy.get_meta("archetype", "") == "archer":
		return
	var mesh := TorusMesh.new()
	mesh.inner_radius = 1.65
	mesh.outer_radius = 1.70
	mesh.rings = 48
	mesh.ring_segments = 4
	var tell := MeshInstance3D.new()
	tell.mesh = mesh
	tell.material_override = World.mat(Color("#d57950"), true)
	tell.position.y = 0.045
	enemy.add_child(tell)
	tell.hide()
	tells[enemy] = tell

func start_wave() -> void:
	wave = seals + 1
	wave_cleared = false
	var points: Array[Vector3] = [Vector3(-4, 0, -7), Vector3(4, 0, -7), Vector3(-3, 0, 4), Vector3(3, 0, 4), Vector3(0, 0, -9)]
	for i in range(wave + 2):
		var ranged := (wave == 2 and i == 1) or (wave == 3 and i < 2)
		var config: Dictionary = archer_settings.duplicate(true) if ranged else settings.enemy.duplicate(true)
		var elite := wave == 3 and i == 4
		if elite:
			config.health = 100
			config.damage = 14
			config.height = 2.5
			config.speed = 1.6
		var enemy := spawn(config, points[i], true)
		enemy.set_meta("elite", elite)
		enemies.append(enemy)
		add_tell(enemy)
		burst(points[i] + Vector3.UP * 0.2, Color("#98c4bc"), 16, 0.7)
	show_banner(["", "The First Watch", "Ashes Stir", "The Oathbreaker"][wave], "WATCH %s  /  %d guardians remain" % [["", "I", "II", "III"][wave], wave + 2])

func on_death(actor: CharacterBody3D) -> void:
	if actor == player:
		finish(false)
		return
	if not actor.enemy:
		return
	kills += 1
	total_kills += 1
	if alive_count() == 0:
		clear_arrows()
		wave_cleared = true
		show_banner("The watch is broken", "Approach seal %s and press E to kindle it." % ["I", "II", "III"][seals])
		burst(World.POINTS[seals] + Vector3.UP * 1.3, Color("#ebbd77"), 20, 1.0)

func kindle() -> void:
	if not wave_cleared or seals >= 3:
		return
	decoration.kindle(seals)
	burst(World.POINTS[seals] + Vector3.UP * 1.5, Color("#ffcf89"), 28, 1.7)
	player.hp = mini(100, player.hp + 30)
	play_sound("dodge")
	seals += 1
	wave_cleared = false
	if seals == 3:
		decoration.open_gate()
		show_banner("The way is open", "All three seals burn. Reach the northern gate and press E.")
		for child in collection_layout.get_children():
			if child.get_meta("collection_scene", "") == DungeonLayout.settings().scenes.door:
				child.hide()
				remove_collision(child)
	else:
		next_wave_time = 2.0
		show_banner("An ember rekindled", "Vitality restored. Another watch approaches.")

func remove_collision(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
	for child in node.get_children():
		remove_collision(child)

func alive_count() -> int:
	var count := 0
	for enemy in enemies:
		if not enemy.dead:
			count += 1
	return count

func objective_title() -> String:
	if seals == 3:
		return "Return to the light"
	if wave_cleared:
		return "Kindle seal " + ["I", "II", "III"][seals]
	if next_wave_time >= 0:
		return "Hold your ground"
	return "Break the " + ["first", "second", "final"][wave - 1] + " watch"

func objective_detail() -> String:
	if seals == 3:
		return "Northern gate  ·  E to leave"
	if wave_cleared:
		return ["West altar", "East altar", "South altar"][seals] + "  ·  E to interact"
	return "%02d guardians remaining  /  watch %s" % [alive_count(), ["I", "II", "III"][wave - 1]]

func show_banner(title: String, subtitle: String) -> void:
	banner_title = title
	banner_subtitle = subtitle
	banner_time = 4.5

func resolve_attack(attacker: CharacterBody3D) -> void:
	if attacker.get_meta("archetype", "") == "archer":
		return
	super.resolve_attack(attacker)
	if attacker.enemy:
		return
	var arc := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var forward: float = attacker.rotation.y + PI
	for i in range(18):
		var a := forward - 1.10 + float(i) / 18 * 2.2
		var b := forward - 1.10 + float(i + 1) / 18 * 2.2
		var p1 := Vector3(sin(a), 0, cos(a))
		var p2 := Vector3(sin(b), 0, cos(b))
		for p in [p1 * 1.5, p1 * 2.4, p2 * 2.4, p1 * 1.5, p2 * 2.4, p2 * 1.5]:
			mesh.surface_add_vertex(p)
	mesh.surface_end()
	arc.mesh = mesh
	var mat := World.mat(Color("#eac58b"), true)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	arc.material_override = mat
	arc.position = attacker.position + Vector3.UP * 0.5
	effects.add_child(arc)
	var tween := arc.create_tween().set_parallel()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.23)
	tween.tween_property(arc, "scale", Vector3.ONE * 1.12, 0.23)
	tween.chain().tween_callback(arc.queue_free)

func on_damage(actor: CharacterBody3D, amount: int) -> void:
	super.on_damage(actor, amount)
	if actor == player:
		hurt_flash = 0.5

func launch_arrow(origin: Vector3, target: Vector3, damage := 8) -> Node3D:
	if paused or ended or origin.distance_squared_to(target) < 0.01:
		return null
	var arrow := Arrow.new()
	arrow.arena = self
	arrow.damage = damage
	arrow.direction = (target - origin).normalized()
	arrow.position = projectiles.to_local(origin)
	projectiles.add_child(arrow)
	arrows_fired += 1
	return arrow

func clear_arrows() -> void:
	if projectiles == null:
		return
	for arrow in projectiles.get_children():
		arrow.retire()

func on_consecration_heal(actor: CharacterBody3D, amount: int) -> void:
	spell_number(actor, "+%d" % amount, Color("a9efd0"), 2.4)

func on_shield_blocked(actor: CharacterBody3D) -> void:
	spell_number(actor, "IMMUNE", Color("fff0b5"), 2.5)

func on_consecration_burn(actor: CharacterBody3D, amount: int, lucky: bool) -> void:
	spell_number(actor, "%d!" % amount if lucky else str(amount), Color("fff1ae") if lucky else Color("e7bd68"), 2.0)
	if lucky:
		burst(actor.position + Vector3.UP, Color("fff2c6"), 5, 0.30)

func spell_number(actor: CharacterBody3D, value: String, color: Color, height: float) -> void:
	var label := Label3D.new()
	label.text = value
	label.font_size = 44
	label.pixel_size = 0.009
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.position = actor.position + Vector3(0, height, 0)
	effects.add_child(label)
	var fade := label.create_tween().set_parallel()
	fade.tween_property(label, "position:y", label.position.y + 0.5, 0.7)
	fade.tween_property(label, "modulate:a", 0.0, 0.7)
	fade.chain().tween_callback(label.queue_free)

func burst(point: Vector3, color: Color, count: int, radius: float) -> void:
	for i in range(count):
		var shard := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.035, 0.09, 0.035)
		shard.mesh = mesh
		shard.material_override = World.mat(color, true)
		shard.position = point
		effects.add_child(shard)
		var angle := i * TAU / count
		var target := point + Vector3(cos(angle) * radius, 0.4 + sin(i * 13.0) * 0.6, sin(angle) * radius)
		var tween := shard.create_tween().set_parallel()
		tween.tween_property(shard, "position", target, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(shard, "scale", Vector3.ZERO, 0.8)
		tween.chain().tween_callback(shard.queue_free)

func finish(victory: bool) -> void:
	ended = true
	won = victory
	if consecration != null:
		consecration.cancel()
	player.cancel_divine_shield()
	clear_arrows()
	show_overlay("Oath fulfilled" if victory else "The ember fades")
	overlay_detail.text = ("The three seals burn. The sanctum remembers.\n\n" if victory else "Rise again, Warden. Your watch is not yet over.\n\n") + "%d guardians defeated   ·   %d / 3 seals\n%02d:%02d in the sanctum" % [total_kills, seals, int(elapsed) / 60, int(elapsed) % 60]
	continue_button.hide()
	print("EMBER FINISH: won=%s kills=%d seals=%d hp=%d seconds=%.2f" % [won, total_kills, seals, player.hp, elapsed])
	if victory and record_results:
		var file := ConfigFile.new()
		file.load("user://ember_record.cfg")
		var previous: float = file.get_value("record", "best_time", 0.0)
		if previous == 0 or elapsed < previous:
			file.set_value("record", "best_time", elapsed)
			file.save("user://ember_record.cfg")

func toggle_pause() -> void:
	super.toggle_pause()
	update_music_state()
	overlay_detail.text = "Your watch can wait.\n\nWASD  Move   ·   Mouse  Aim   ·   LMB  Strike\nQ  Consecration   ·   F  Divine Shield\nSpace  Evade   ·   E  Interact   ·   N  BGM   ·   M  Sound"

func show_overlay(title: String) -> void:
	super.show_overlay(title.capitalize())
	if continue_button.visible:
		continue_button.grab_focus()

func _exit_tree() -> void:
	# Dictionary keys hold dead actors; release them with the scene.
	tells.clear()
	material_cache.clear()
	for voice in voices:
		voice.stop()
		voice.stream = null
	voices.clear()
	if ambient != null:
		ambient.stop()
		ambient.stream = null

func build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	hud = HUD.new()
	hud.game = self
	ui.add_child(hud)
	# Kept for the foundation's reporting interface.
	health_label = Label.new()
	status_label = Label.new()
	health_label.hide()
	status_label.hide()
	ui.add_child(health_label)
	ui.add_child(status_label)
	overlay = PanelContainer.new()
	overlay.position = Vector2(416, 178)
	overlay.custom_minimum_size = Vector2(448, 365)
	overlay.add_theme_stylebox_override("panel", HUD.style(Color(0.035, 0.07, 0.09, 0.98)))
	ui.add_child(overlay)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	overlay.add_child(rows)
	var small := Label.new()
	small.text = "K I N G D O M   O F   S W O R D S"
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	small.add_theme_color_override("font_color", HUD.GOLD)
	small.add_theme_font_size_override("font_size", 10)
	rows.add_child(small)
	overlay_title = Label.new()
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title.add_theme_font_override("font", load("res://assets/fonts/Title.ttf"))
	overlay_title.add_theme_font_size_override("font_size", 32)
	rows.add_child(overlay_title)
	overlay_detail = Label.new()
	overlay_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_detail.add_theme_font_size_override("font_size", 12)
	overlay_detail.add_theme_color_override("font_color", HUD.MUTED)
	overlay_detail.custom_minimum_size.y = 78
	rows.add_child(overlay_detail)
	var play_options := HBoxContainer.new()
	play_options.add_theme_constant_override("separation", 12)
	rows.add_child(play_options)
	continue_button = Button.new()
	continue_button.text = "RESUME WATCH"
	continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HUD.button_theme(continue_button, true)
	continue_button.pressed.connect(toggle_pause)
	play_options.add_child(continue_button)
	var music_button := make_music_button()
	music_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_options.add_child(music_button)
	var retry := Button.new()
	retry.text = "RISE AGAIN    /    R"
	HUD.button_theme(retry)
	retry.pressed.connect(restart)
	rows.add_child(retry)
	var leave := Button.new()
	leave.text = "RETURN TO MENU"
	HUD.button_theme(leave)
	leave.pressed.connect(return_menu)
	rows.add_child(leave)
	overlay.hide()
