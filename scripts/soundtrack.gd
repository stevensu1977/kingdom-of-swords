extends Node
## Shared preference and audio bus; each scene owns its actual music stream.

var player: AudioStreamPlayer
var music_enabled := true
var muted := false
var music_bus := -1

func _ready() -> void:
	music_bus = AudioServer.get_bus_index("Music")
	if music_bus < 0:
		AudioServer.add_bus()
		music_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(music_bus, "Music")
		AudioServer.set_bus_send(music_bus, "Master")
	player = AudioStreamPlayer.new()
	player.name = "MusicPlayer"
	player.bus = "Music"
	add_child(player)
	var profile := get_node_or_null("/root/Profile")
	if profile != null:
		music_enabled = profile.music_enabled
	update_mute()

func set_muted(value: bool) -> void:
	muted = value
	update_mute()

func toggle_music() -> void:
	music_enabled = not music_enabled
	var profile := get_node_or_null("/root/Profile")
	if profile != null:
		profile.music_enabled = music_enabled
		profile.save_profile()
	update_mute()

func update_mute() -> void:
	AudioServer.set_bus_mute(music_bus, muted or not music_enabled)

func _exit_tree() -> void:
	player.stop()
	player.stream = null
