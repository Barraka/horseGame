extends Node3D
## Design your rider: body, skin, hair, outfit and helmet, with the rider
## turning on a little stage beside the choices. Done saves and goes back
## to the stable.

const Rider := preload("res://scripts/rider.gd")
const STABLE_SCENE := "res://scenes/stable.tscn"
## Skin tones are tints on the model's own skin; this is roughly that skin,
## so the swatches look like the result.
const SKIN_SWATCH := Color(0.88, 0.66, 0.54)
## The rows on screen, in order: config key and label.
const ROWS := [
	["body", "Rider"], ["skin", "Skin"], ["hair", "Hair"],
	["hair_color", "Hair colour"], ["outfit", "Outfit"], ["helmet", "Helmet"],
]

var _config: Dictionary
var _rider: Node3D
var _turntable: Node3D
var _values := {}     ## Config key -> the Label showing its choice
var _swatches := {}   ## Config key -> the ColorRect showing its colour
var _drag_spin := 0.0
var _idle_time := 10.0


func _ready() -> void:
	_config = Rider.DEFAULT.duplicate()
	_config.merge(RiderData.config, true)
	_build_scene()
	_build_ui()
	_rebuild()


func _process(delta: float) -> void:
	_idle_time += delta
	if _idle_time > 2.0:
		_turntable.rotation.y += 0.3 * delta
	_turntable.rotation.y += _drag_spin
	_drag_spin = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_drag_spin += event.relative.x * 0.01
		_idle_time = 0.0


func _change(key: String, step: int) -> void:
	_config[key] = wrapi(_config[key] + step, 0, Rider.OPTIONS[key].size())
	_rebuild()


func _rebuild() -> void:
	_rider.build(_config)
	for key in _values:
		var option: Dictionary = Rider.OPTIONS[key][_config[key]]
		_values[key].text = option.name
		if _swatches.has(key):
			var color: Color = option.color
			if key == "skin":
				color *= SKIN_SWATCH
			_swatches[key].visible = color.a > 0.0
			_swatches[key].color = Color(color.r, color.g, color.b).clamp()


func _done() -> void:
	RiderData.save(_config)
	get_tree().change_scene_to_file(STABLE_SCENE)


# --- 3D scene -----------------------------------------------------------------

func _build_scene() -> void:
	var env := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.4, 0.55, 0.9)
	sky_material.sky_horizon_color = Color(0.92, 0.86, 0.95)
	sky_material.ground_horizon_color = Color(0.7, 0.75, 0.6)
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.8, 0.86, 0.92)
	env.fog_density = 0.01
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	sun.light_energy = 1.2
	sun.light_color = Color(1, 0.95, 0.88)
	sun.shadow_enabled = true
	add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1.5, 1.6, 2.5)
	fill.light_energy = 0.6
	fill.omni_range = 8.0
	add_child(fill)

	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.2, 0.42, 0.13)
	grass.roughness = 0.95
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	(ground.mesh as PlaneMesh).size = Vector2(400, 400)
	ground.material_override = grass
	add_child(ground)

	# A round wooden stage for the rider to turn on.
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.3, 0.19)
	wood.roughness = 0.7
	var disc := CylinderMesh.new()
	disc.top_radius = 0.7
	disc.bottom_radius = 0.75
	disc.height = 0.12
	disc.radial_segments = 48
	_turntable = Node3D.new()
	_turntable.position = Vector3(-0.55, 0.0, 0.0)
	add_child(_turntable)
	var stage := MeshInstance3D.new()
	stage.mesh = disc
	stage.material_override = wood
	stage.position.y = 0.06
	_turntable.add_child(stage)
	_rider = Rider.new()
	_rider.position.y = 0.12
	_turntable.add_child(_rider)
	_turntable.rotation.y = deg_to_rad(20)

	var camera := Camera3D.new()
	camera.fov = 40
	add_child(camera)
	camera.look_at_from_position(Vector3(0.35, 1.25, 3.6), Vector3(0.35, 0.95, 0))


# --- On-screen controls -------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.06, 0.12, 0.5)))
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.position.x -= 32

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(_label("My Rider", 34))

	for row_info in ROWS:
		var key: String = row_info[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		column.add_child(row)
		var title := _label(row_info[1], 20)
		title.custom_minimum_size.x = 130
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title.modulate = Color(1, 0.95, 0.85, 0.85)
		row.add_child(title)
		row.add_child(_button("◀", 30, _change.bind(key, -1), Vector2(60, 56)))
		var value_box := HBoxContainer.new()
		value_box.custom_minimum_size.x = 190
		value_box.alignment = BoxContainer.ALIGNMENT_CENTER
		value_box.add_theme_constant_override("separation", 8)
		row.add_child(value_box)
		if Rider.OPTIONS[key][0].has("color"):
			var swatch := ColorRect.new()
			swatch.custom_minimum_size = Vector2(22, 22)
			swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			value_box.add_child(swatch)
			_swatches[key] = swatch
		var value := _label("", 24)
		value_box.add_child(value)
		_values[key] = value
		row.add_child(_button("▶", 30, _change.bind(key, 1), Vector2(60, 56)))

	var done := _button("Done", 28, _done, Vector2(260, 64))
	var done_style := _style(Color(1, 0.97, 0.9, 0.95))
	for state in ["normal", "hover", "pressed"]:
		done.add_theme_stylebox_override(state, done_style)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		done.add_theme_color_override(state, Color(0.2, 0.15, 0.25))
	var centre := CenterContainer.new()
	centre.add_child(done)
	column.add_child(centre)


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	label.add_theme_constant_override("outline_size", 6)
	return label


func _button(text: String, font_size: int, action: Callable, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", font_size)
	var style := _style(Color(0.08, 0.06, 0.12, 0.45))
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(action)
	return button


func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(16)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style
