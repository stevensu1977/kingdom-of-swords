extends Node
## Save the sanctuary's music preference independently of a game run.

var music_enabled := true
var storage_path := "user://settings.json"
var storage_enabled := true
var save_error := ""

func _ready() -> void:
	storage_enabled = DisplayServer.get_name() != "headless" and not OS.get_cmdline_args().has("--script")
	if storage_enabled:
		load_profile()

func load_profile() -> void:
	if not FileAccess.file_exists(storage_path):
		return
	var file := FileAccess.open(storage_path, FileAccess.READ)
	if file == null or file.get_length() > 4096:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data is Dictionary and data.get("version") == 1 and data.get("music") is bool:
		music_enabled = data.music

func save_profile() -> void:
	if not storage_enabled:
		return
	var file := FileAccess.open(storage_path + ".tmp", FileAccess.WRITE)
	if file == null:
		save_error = "LOCAL SAVE UNAVAILABLE"
		return
	file.store_string(JSON.stringify({"version": 1, "music": music_enabled}))
	file.flush()
	var error := file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(storage_path + ".tmp", storage_path)
	save_error = "" if error == OK else "LOCAL SAVE UNAVAILABLE"
