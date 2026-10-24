extends Node3D
## The title screen: your horse and rider standing in a meadow in the
## evening sun, the camera slowly circling them, with Play, Settings and
## (on PC) Quit. The game's name comes from the project settings.

const Horse := preload("res://scripts/horse.gd")
const Trees := preload("res://scripts/trees.gd")
const SkyCycle := preload("res://scripts/sky_cycle.gd")
const Sparkles := preload("res://scripts/sparkles.gd")
const SettingsPanel := preload("res://scripts/settings_panel.gd")
const STABLE_SCENE := "res://scenes/stable.tscn"
const ORBIT_RADIUS := 6.0
const ORBIT_SPEED := 0.06   ## Radians a second

var _camera: Camera3D
var _horse: Node3D
var _angle := 0.6
var _menu: VBoxContainer
var _settings: PanelContainer


func _ready() -> void:
	_build_scene()
	_build_ui()


func _process(delta: float) -> void:
	_angle += ORBIT_SPEED * delta
	var at := Vector3(sin(_angle), 0, cos(_angle)) * ORBIT_RADIUS
	_camera.look_at_from_position(at + Vector3(0, 1.5, 0), Vector3(0, 1.15, 0))


func play() -> void:
	get_tree().change_scene_to_file(STABLE_SCENE)   # Which first asks for a rider, if there isn't one yet


# --- 3D scene -----------------------------------------------------------------

func _build_scene() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.fog_enabled = true
	env.fog_density = 0.004
	env.fog_sky_affect = 0.3
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	add_child(sun)
	# Late afternoon, with the sky and light that go with it.
	var sky := SkyCycle.new()
	sky.sun_path = sun.get_path()
	sky.environment_path = world_env.get_path()
	sky.running = false
	sky.hour = 17.2
	add_child(sky)

	# A round meadow, with hills behind.
	var grass := StandardMaterial3D.new()
	var noise := FastNoiseLite.new()
	noise.frequency = 0.05
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.2, 0.42, 0.12))
	ramp.set_color(1, Color(0.42, 0.62, 0.2))
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.color_ramp = ramp
	texture.seamless = true
	grass.albedo_texture = texture
	grass.uv1_scale = Vector3(30, 30, 30)
	grass.roughness = 0.95
	var ground := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 140.0
	disc.bottom_radius = 140.0
	disc.height = 0.1
	disc.radial_segments = 64
	ground.mesh = disc
	ground.material_override = grass
	ground.position.y = -0.05
	add_child(ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 9:
		var hill := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = rng.randf_range(30, 50)
		sphere.height = sphere.radius * 2.0
		hill.mesh = sphere
		hill.material_override = grass
		var a := TAU * i / 9.0 + rng.randf_range(-0.2, 0.2)
		hill.position = Vector3(sin(a), 0, cos(a)) * rng.randf_range(95, 120)
		hill.scale = Vector3(1, rng.randf_range(0.25, 0.4), 1)
		add_child(hill)

	# Trees and flowering bushes around the meadow.
	var kinds := ["oak", "blossom", "birch", "willow", "pine", "flower_bush", "autumn", "bush", "poplar", "flower_bush"]
	var meshes := {}
	for i in 46:
		var kind: String = kinds[i % kinds.size()]
		var key := "%s%d" % [kind, i % 2]
		if not meshes.has(key):
			meshes[key] = Trees.grow(kind, i % 2 + 3)
		var tree := MeshInstance3D.new()
		tree.mesh = meshes[key]
		var a := rng.randf() * TAU
		var bush := kind.ends_with("bush")
		var r := rng.randf_range(7.5, 14.0) if bush else rng.randf_range(14.0, 48.0)
		tree.position = Vector3(sin(a), 0, cos(a)) * r
		tree.rotation.y = rng.randf() * TAU
		tree.scale = Vector3.ONE * rng.randf_range(0.8, 1.2)
		add_child(tree)

	# Your horse, with you riding it.
	_horse = Horse.new()
	add_child(_horse)
	_horse.set_physics_process(false)
	_horse.stand()

	var sparkles := Sparkles.new()
	sparkles.target_path = _horse.get_path()
	add_child(sparkles)

	_camera = Camera3D.new()
	_camera.fov = 50
	add_child(_camera)
	_camera.current = true
	_process(0.0)


# --- Menu -----------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var title := Label.new()
	title.text = ProjectSettings.get_setting("application/config/name", "Silver Mane")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", Color(1.0, 0.93, 0.75))
	title.add_theme_color_override("font_outline_color", Color(0.35, 0.18, 0.3, 0.85))
	title.add_theme_constant_override("outline_size", 22)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	title.add_theme_constant_override("shadow_offset_y", 6)
	root.add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.position.y += 60

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 16)
	root.add_child(_menu)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	_menu.position.x += 80
	_menu.position.y += 60
	var play_button := _button("Play", 34, play, true)
	_menu.add_child(play_button)
	_menu.add_child(_button("Settings", 24, func():
		_menu.visible = false
		_settings.open()))
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		_menu.add_child(_button("Quit", 24, func(): get_tree().quit()))

	_settings = SettingsPanel.new()
	root.add_child(_settings)
	_settings.closed.connect(func(): _menu.visible = true)


func _unhandled_input(event: InputEvent) -> void:
	if _menu.visible and (event.is_action_pressed("ui_accept") or event.is_action_pressed("jump")):
		play()


func _button(text: String, font_size: int, action: Callable, main := false) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(280, 76 if main else 60)
	button.add_theme_font_size_override("font_size", font_size)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 0.97, 0.9, 0.95) if main else Color(0.08, 0.06, 0.12, 0.55)
	style.set_corner_radius_all(18)
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, style)
	if main:
		for state in ["font_color", "font_hover_color", "font_pressed_color"]:
			button.add_theme_color_override(state, Color(0.2, 0.15, 0.25))
	button.pressed.connect(action)
	return button
