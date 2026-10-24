extends Node
## The player's settings: music and sound volume, graphics quality, the
## keyboard help while riding, and full screen on PC. Autoloaded as
## "Settings" and saved, so the game remembers them next time.

signal changed

const SAVE_PATH := "user://settings.cfg"
const QUALITIES := ["Low", "Medium", "High"]   ## Graphics quality, 0 to 2

var music := 0.7          ## Music volume, 0 to 1
var sounds := 0.8         ## Sound effects volume, 0 to 1
var quality := 2          ## 0 low, 1 medium, 2 high
var show_help := true     ## The keyboard help in the corner while riding
var fullscreen := false   ## PC only


func _ready() -> void:
	# Tablets start on medium graphics, PCs on high.
	quality = 1 if OS.has_feature("mobile") else 2
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		music = config.get_value("audio", "music", music)
		sounds = config.get_value("audio", "sounds", sounds)
		quality = clampi(config.get_value("graphics", "quality", quality), 0, QUALITIES.size() - 1)
		show_help = config.get_value("controls", "show_help", show_help)
		fullscreen = config.get_value("graphics", "fullscreen", fullscreen)
	for bus in ["Music", "Sounds"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	_apply()


## Change a setting by name ("music", "sounds", "quality", "show_help",
## "fullscreen"), put it into effect and save it.
func change(key: String, value: Variant) -> void:
	set(key, value)
	_apply()
	_save()
	changed.emit()


## How many grass tufts to grow in a square, and how far away grass is drawn.
func grass_amount() -> int:
	return [300, 550, 900][quality]


func grass_reach() -> float:
	return [26.0, 34.0, 44.0][quality]


## How many leaf cards trees grow, as a share of the most.
func tree_detail() -> float:
	return [0.55, 0.75, 1.0][quality]


## Turn an Environment's costlier effects on or off to suit the quality.
func apply_environment(env: Environment) -> void:
	env.ssao_enabled = quality >= 2
	env.glow_enabled = quality >= 1
	env.sdfgi_enabled = false


## Shadows from the sun: how far they reach, or none on low.
func apply_sun(sun: DirectionalLight3D) -> void:
	sun.shadow_enabled = quality >= 1
	sun.directional_shadow_max_distance = [0.0, 50.0, 80.0][quality]


func _apply() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music, 0.0001)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), music <= 0.001)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Sounds"), linear_to_db(maxf(sounds, 0.0001)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Sounds"), sounds <= 0.001)
	var viewport := get_tree().root
	viewport.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_2X][quality]
	viewport.scaling_3d_scale = [0.75, 0.9, 1.0][quality]
	if not OS.has_feature("mobile") and DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode and (fullscreen or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN):
			DisplayServer.window_set_mode(mode)


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music)
	config.set_value("audio", "sounds", sounds)
	config.set_value("graphics", "quality", quality)
	config.set_value("graphics", "fullscreen", fullscreen)
	config.set_value("controls", "show_help", show_help)
	config.save(SAVE_PATH)
