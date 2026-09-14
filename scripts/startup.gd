extends Control
## Explain external dependencies before instantiating any character or level.

const REQUIREMENTS := "res://assets/external.json"
var missing_assets: Array[String] = []

func _ready() -> void:
	var requirements: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REQUIREMENTS))
	for group in requirements.groups:
		if not group.required:
			continue
		for path in group.files:
			if not ResourceLoader.exists("res://" + str(path)):
				missing_assets.append(str(path))
	if missing_assets.is_empty():
		get_tree().change_scene_to_file.call_deferred("res://scenes/menu.tscn")
		return
	show_missing_assets()

func show_missing_assets() -> void:
	var background := ColorRect.new()
	background.color = Color("#10232c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 96
	panel.offset_top = 110
	panel.offset_right = -96
	panel.offset_bottom = -90
	panel.add_theme_constant_override("separation", 24)
	add_child(panel)
	var title := Label.new()
	title.text = "KINGDOM OF SWORDS"
	title.add_theme_font_override("font", load("res://assets/fonts/Title.ttf"))
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("#dcc392"))
	panel.add_child(title)
	var message := Label.new()
	message.name = "MissingAssets"
	message.text = "The source project is ready. Some game artwork must be supplied separately.\n\nRead docs/ASSETS.md for the required characters and dungeon files.\nRun python3 tools/check_assets.py to list missing dependencies.\n\nMissing required files: %d\n\nNo assets are downloaded automatically." % missing_assets.size()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_override("font", load("res://assets/fonts/Body.ttf"))
	message.add_theme_font_size_override("font_size", 20)
	panel.add_child(message)
	var exit := Button.new()
	exit.text = "Quit"
	exit.custom_minimum_size = Vector2(160, 48)
	exit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	exit.pressed.connect(func(): get_tree().quit())
	panel.add_child(exit)
	exit.grab_focus()
	print("ASSET SETUP REQUIRED: %d files. See docs/ASSETS.md." % missing_assets.size())
