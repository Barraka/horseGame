extends SceneTree
## Settings and the title screen: the title screen opens with Play, changing
## settings is saved and takes effect (volume buses, graphics quality for the
## grass and the sun's shadows, keyboard help), and Play goes to the stable.
## Puts the saved settings back afterwards. Run with:
## godot --headless --path . -s tests/settings_test.gd

var ok := true
var frames := 0
var title: Node
var saved := {}


func _check(what: String, passed: bool) -> void:
	print("%s: %s" % [what, "ok" if passed else "FAILED"])
	ok = ok and passed


func _process(_delta: float) -> bool:
	frames += 1
	var settings := root.get_node("Settings")
	if frames == 2:
		saved = {"music": settings.music, "sounds": settings.sounds, "quality": settings.quality, "show_help": settings.show_help}
		title = load("res://scenes/title.tscn").instantiate()
		root.add_child(title)
		return false
	if frames != 4:
		return false
	_check("The title screen has a Play button", title._menu.get_child(0).text == "Play")
	_check("Music and sound buses exist", AudioServer.get_bus_index("Music") > 0 and AudioServer.get_bus_index("Sounds") > 0)

	settings.change("music", 0.25)
	_check("Music volume is applied", absf(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))) - 0.25) < 0.01)
	settings.change("sounds", 0.0)
	_check("Sounds can be turned off", AudioServer.is_bus_mute(AudioServer.get_bus_index("Sounds")))
	settings.change("quality", 0)
	var config := ConfigFile.new()
	config.load(settings.SAVE_PATH)
	_check("Settings are saved", config.get_value("graphics", "quality", -1) == 0 and is_equal_approx(config.get_value("audio", "music", 0.0), 0.25))
	var sun := DirectionalLight3D.new()
	settings.apply_sun(sun)
	_check("Low graphics turns off shadows", not sun.shadow_enabled)
	var low: int = settings.grass_amount()
	settings.change("quality", 2)
	settings.apply_sun(sun)
	_check("High graphics has shadows and more grass", sun.shadow_enabled and settings.grass_amount() > low)

	settings.change("show_help", false)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var help_shown := false
	for label in main.get_node("HUD").find_children("*", "Label", true, false):
		if "steer" in label.text:
			help_shown = true
	_check("Keyboard help can be hidden", not help_shown)
	main.queue_free()

	for key in saved:
		settings.change(key, saved[key])
	print("RESULT: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
	return true
