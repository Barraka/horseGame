extends Node3D
## The stable: browse your horses, see each one up close, and pick one to ride.

const Horse := preload("res://scripts/horse.gd")
const RIDE_SCENE := "res://scenes/main.tscn"
const CAMERA_POS := Vector3(4.5, 1.8, 5.1)
const CAMERA_TARGET := Vector3(0, 0.55, 0)   ## Below the horse, so it stands above the controls

var _index := 0
var _horse: Node3D
var _turntable: Node3D
var _name_label: Label
var _coat_label: Label
var _ride_button: Button
var _dots: HBoxContainer
var _drag_spin := 0.0
var _idle_time := 10.0


func _ready() -> void:
	_index = Stable.selected
	_build_scene()
	_build_ui()
	_show_horse()


func _process(delta: float) -> void:
	# Turn slowly on its own, unless the player has just turned it by hand.
	_idle_time += delta
	if _idle_time > 2.0:
		_turntable.rotation.y += 0.25 * delta
	_turntable.rotation.y += _drag_spin
	_drag_spin = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_drag_spin += event.relative.x * 0.008
		_idle_time = 0.0
	elif event.is_action_pressed("steer_left") or event.is_action_pressed("ui_left"):
		_browse(-1)
	elif event.is_action_pressed("steer_right") or event.is_action_pressed("ui_right"):
		_browse(1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		_ride()


func _browse(step: int) -> void:
	_index = wrapi(_index + step, 0, Stable.HORSES.size())
	_show_horse()


func _show_horse() -> void:
	var horse: Dictionary = Stable.HORSES[_index]
	_horse.set_coat(horse.body, horse.points, horse.strength)
	_name_label.text = horse.name
	_coat_label.text = horse.coat
	_ride_button.text = "Ride %s" % horse.name
	for i in _dots.get_child_count():
		_dots.get_child(i).modulate.a = 1.0 if i == _index else 0.35


func _ride() -> void:
	Stable.select(_index)
	get_tree().change_scene_to_file(RIDE_SCENE)


# --- 3D scene -----------------------------------------------------------------

func _build_scene() -> void:
	var env := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.35, 0.55, 0.9)
	sky_material.sky_horizon_color = Color(0.85, 0.88, 0.95)
	sky_material.ground_horizon_color = Color(0.6, 0.7, 0.55)
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.8, 0.86, 0.92)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.light_energy = 1.2
	sun.light_color = Color(1, 0.95, 0.85)
	sun.shadow_enabled = true
	add_child(sun)

	# A round paddock of grass with a sandy patch under the horse.
	_disc(80.0, Color(0.24, 0.48, 0.15), 0.0)
	_disc(2.6, Color(0.82, 0.72, 0.55), 0.01)

	# A wooden fence in a half circle behind the horse.
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.38, 0.24)
	wood.roughness = 0.8
	var post := BoxMesh.new()
	post.size = Vector3(0.14, 1.3, 0.14)
	var rail := BoxMesh.new()
	rail.size = Vector3(0.08, 0.1, 1.0)
	var radius := 5.5
	var steps := 12
	var gap := atan2(CAMERA_POS.z, CAMERA_POS.x)   # Open towards the camera
	for i in steps + 1:
		var a := lerpf(PI * 0.15, PI * 1.85, float(i) / steps) + gap
		var p := Vector3(cos(a), 0, sin(a)) * radius
		_mesh(post, wood, p + Vector3.UP * 0.65)
		if i < steps:
			var a2 := lerpf(PI * 0.15, PI * 1.85, float(i + 1) / steps) + gap
			var p2 := Vector3(cos(a2), 0, sin(a2)) * radius
			for h in [0.55, 1.05]:
				var r := _mesh(rail, wood, (p + p2) * 0.5 + Vector3.UP * h)
				r.look_at_from_position(r.position, p2 + Vector3.UP * h)
				r.scale.z = p.distance_to(p2)

	# Rose bushes along the fence.
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.2, 0.45, 0.18)
	var bloom := StandardMaterial3D.new()
	bloom.albedo_color = Color(0.95, 0.35, 0.5)
	bloom.emission_enabled = true
	bloom.emission = Color(0.4, 0.05, 0.15)
	var bush := SphereMesh.new()
	bush.radius = 0.45
	bush.height = 0.7
	var flower := SphereMesh.new()
	flower.radius = 0.08
	flower.height = 0.14
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 9:
		var a := lerpf(PI * 0.25, PI * 1.75, i / 8.0) + gap
		var p := Vector3(cos(a), 0.25, sin(a)) * (radius + 0.6)
		p.y = 0.25
		_mesh(bush, leaf, p)
		for f in 6:
			var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 1), rng.randf_range(-1, 1)).normalized()
			_mesh(flower, bloom, p + d * 0.42)

	_turntable = Node3D.new()
	add_child(_turntable)
	_horse = Horse.new()
	_turntable.add_child(_horse)
	_horse.set_physics_process(false)   # Only a model to look at here, not ridden
	_horse.stand()

	var camera := Camera3D.new()
	camera.fov = 38
	add_child(camera)
	camera.look_at_from_position(CAMERA_POS, CAMERA_TARGET)
	_turntable.rotation.y = deg_to_rad(-70)


func _disc(radius: float, color: Color, height: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.02
	mesh.radial_segments = 64
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	_mesh(mesh, material, Vector3(0, height - 0.01, 0))


func _mesh(mesh: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	add_child(mi)
	return mi


# --- On-screen controls -------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var title := _label("My Stable", 34)
	root.add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.position.y += 24

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.06, 0.12, 0.5)))
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.position.y -= 28

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	row.add_child(_button("◀", 72, _browse.bind(-1), Vector2(84, 84)))

	var info := VBoxContainer.new()
	info.custom_minimum_size.x = 300
	info.add_theme_constant_override("separation", 6)
	row.add_child(info)
	_name_label = _label("", 40)
	_coat_label = _label("", 22)
	_coat_label.modulate = Color(1, 0.95, 0.85, 0.85)
	info.add_child(_name_label)
	info.add_child(_coat_label)
	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in Stable.HORSES.size():
		_dots.add_child(_label("●", 16))
	info.add_child(_dots)
	_ride_button = _button("", 28, _ride, Vector2(260, 64))
	var ride_style := _style(Color(1, 0.97, 0.9, 0.95))
	for state in ["normal", "hover", "pressed"]:
		_ride_button.add_theme_stylebox_override(state, ride_style)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		_ride_button.add_theme_color_override(state, Color(0.2, 0.15, 0.25))
	var centre := CenterContainer.new()
	centre.add_child(_ride_button)
	info.add_child(centre)

	row.add_child(_button("▶", 72, _browse.bind(1), Vector2(84, 84)))


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
