extends Node
## How the player's rider looks. Autoloaded as "RiderData" and saved, so the
## game remembers it next time.

const SAVE_PATH := "user://rider.cfg"

var config: Dictionary = {}
var saved := false   ## False until the player has made a rider


func _ready() -> void:
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) == OK:
		config = file.get_value("rider", "config", {})
		saved = true


func save(new_config: Dictionary) -> void:
	config = new_config.duplicate()
	saved = true
	var file := ConfigFile.new()
	file.set_value("rider", "config", config)
	file.save(SAVE_PATH)
