extends Control

const HUD = preload("res://scripts/ember_hud.gd")
var preview: Node3D
var clock := 0.0
var serif: Font = preload("res://assets/fonts/Title.ttf")
var body: Font = preload("res://assets/fonts/Body.ttf")
var record := ""

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	preview = load("res://scenes/ember.tscn").instantiate()
	preview.menu_preview = true
	add_child(preview)
	preview.paused = true
	preview.ui.hide()
	preview.player.position = Vector3(2.5, 0, 3.0)
	preview.player.rotation.y = -0.4
	preview.player.scale = Vector3.ONE * 1.45
	preview.camera.position = Vector3(-4.5, 16.5, 13.8)
	preview.camera.size = 16.0
	preview.decoration.kindle(1)
	preview.decoration.kindle(2)
	if has_node("/root/Soundtrack"):
		get_node("/root/Soundtrack").player.stop()
	var enter := Button.new()
	enter.name = "MeleeCourtyard"
	enter.text = "ENTER THE SANCTUM                       →"
	enter.position = Vector2(72, 439)
	enter.size = Vector2(360, 53)
	HUD.button_theme(enter, true)
	enter.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ember.tscn"))
	add_child(enter)
	var practice := Button.new()
	practice.name = "Controls"
	practice.text = "HOW TO PLAY"
	practice.position = Vector2(72, 505)
	practice.size = Vector2(244, 41)
	HUD.button_theme(practice)
	practice.pressed.connect(show_controls)
	add_child(practice)
	var exit := Button.new()
	exit.text = "QUIT"
	exit.position = Vector2(328, 505)
	exit.size = Vector2(104, 41)
	HUD.button_theme(exit)
	exit.pressed.connect(func(): get_tree().quit())
	add_child(exit)
	var music_button: Button = preview.make_music_button()
	music_button.position = Vector2(72, 560)
	music_button.size = Vector2(360, 46)
	add_child(music_button)
	enter.grab_focus()
	var file := ConfigFile.new()
	if file.load("user://ember_record.cfg") == OK:
		var seconds := int(file.get_value("record", "best_time", 0))
		if seconds > 0:
			record = "BEST WATCH    %02d:%02d" % [seconds / 60, seconds % 60]
	print("EMBER MENU READY")

func show_controls() -> void:
	var help := AcceptDialog.new()
	help.title = "The Warden's Oath"
	help.dialog_text = "Defeat each watch, kindle its seal with E, then escape north.\n\nWASD — move    Mouse — aim    Left button — strike\nSpace — evade    Q — Consecration    F — Divine Shield\nE — interact    Escape — pause    N — music    M — all audio\n\nEach cleared seal restores 30 health. Cover stops arrows."
	help.min_size = Vector2i(600, 260)
	help.add_theme_font_override("font", body)
	add_child(help)
	help.popup_centered()
	help.confirmed.connect(help.queue_free)
	help.canceled.connect(help.queue_free)

func _process(delta: float) -> void:
	clock += delta
	scale = get_viewport_rect().size / Vector2(1280, 720)
	for i in range(preview.decoration.fires.size()):
		preview.decoration.fires[i].scale.y = 0.90 + sin(clock * 7 + i) * 0.12
	queue_redraw()

func label(value: String, point: Vector2, size: int, color: Color, font: Font = null) -> void:
	draw_string(body if font == null else font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	for x in range(0, 980, 4):
		var alpha: float = 0.98 * (1.0 - smoothstep(340, 980, x))
		draw_rect(Rect2(x, 0, 4, 720), Color(0.025, 0.060, 0.080, alpha))
	for y in range(160):
		draw_rect(Rect2(0, 720 - y, 1280, 1), Color(0.025, 0.060, 0.080, 0.90 * (1 - y / 160.0)))
	label("A   S O L I T A R Y   A C T I O N   A D V E N T U R E", Vector2(74, 85), 10, HUD.GOLD)
	draw_line(Vector2(72, 111), Vector2(433, 111), Color("#5c604f"), 1)
	var crown := PackedVector2Array([Vector2(80, 166), Vector2(75, 146), Vector2(91, 155), Vector2(101, 137), Vector2(111, 155), Vector2(127, 146), Vector2(122, 166), Vector2(80, 166)])
	draw_polyline(crown, HUD.GOLD, 1.5, true)
	label("KINGDOM", Vector2(68, 230), 58, HUD.IVORY, serif)
	label("of", Vector2(74, 287), 30, HUD.GOLD, serif)
	label("SWORDS", Vector2(125, 291), 58, HUD.IVORY, serif)
	draw_line(Vector2(75, 315), Vector2(121, 315), HUD.GOLD, 1)
	label("T H E   L A S T   E M B E R", Vector2(140, 319), 11, HUD.GOLD)
	label("An ancient oath. A dying flame.", Vector2(74, 368), 18, Color("#d0d6cf"), serif)
	label("Break the watch. Rekindle the three seals.", Vector2(74, 396), 13, HUD.MUTED)
	label("Find your way back to the light.", Vector2(74, 417), 13, HUD.MUTED)
	label(record if not record.is_empty() else "ONE CHAMBER    /    THREE WATCHES    /    ONE WAY OUT", Vector2(74, 624), 9, HUD.GOLD)
	label("I", Vector2(1148, 570), 58, Color("#cfb17c"), serif)
	label("THE SUNKEN", Vector2(1032, 612), 12, HUD.IVORY)
	label("SANCTUM", Vector2(1032, 638), 21, HUD.IVORY, serif)
	draw_line(Vector2(72, 632), Vector2(432, 632), Color("#435454"), 1)
	label("WASD Move   LMB Strike   SPACE Evade   E Interact", Vector2(74, 658), 10, HUD.MUTED)
	label("Q Consecration   F Divine Shield   ESC Pause   N BGM   M Sound", Vector2(74, 680), 10, HUD.MUTED)
	label("01   /   THE WARDEN'S OATH", Vector2(1010, 686), 10, HUD.GOLD)
