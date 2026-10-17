extends Node3D
## Looking after a horse in the stable: feed it a carrot, brush the mud off
## and give it a pat. Shows how full, clean and loved the horse is, using
## the care levels kept by the Stable autoload. Added by stable.gd.

const CLEAN_PER_PIXEL := 0.0009   ## How much a brush stroke cleans per pixel dragged
const PET_COOLDOWN := 0.6

var brushing := false   ## While true, dragging brushes instead of turning the horse

var _horse: Node3D
var _camera: Camera3D
var _index := 0
var _bars := {}           ## Care key -> ProgressBar
var _mood: Label
var _panel: PanelContainer
var _toast: Label
var _brush_button: Button
var _brush: Node3D
var _brush_dust := 0.0    ## Pixels brushed since the last puff of dust
var _pet_wait := 0.0
var _heart_texture: Texture2D
var _box := AABB()        ## The standing horse's body, in its own space


func setup(horse: Node3D, camera: Camera3D, ui_root: Control) -> void:
	_horse = horse
	_camera = camera
	_heart_texture = _make_heart_texture()
	_build_ui(ui_root)
	_build_brush()
	Stable.care_changed.connect(func(i): if i == _index: _refresh())


func show_horse(index: int) -> void:
	_index = index
	_set_brushing(false)
	_refresh()


## Hide the care panel (while the shop is open) or bring it back.
func set_panel_visible(on: bool) -> void:
	_panel.visible = on
	if not on:
		_set_brushing(false)


func _process(delta: float) -> void:
	_pet_wait -= delta
	if _toast.modulate.a > 0.0:
		_toast.modulate.a = maxf(_toast.modulate.a - delta * 0.5, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if not brushing:
		return
	var drag: bool = event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT)
	if event is InputEventMouseMotion or event is InputEventScreenDrag or event is InputEventScreenTouch:
		var spot := _point_on_horse(event.position)
		_brush.visible = spot != Vector3.INF or not drag
		if spot != Vector3.INF:
			_brush.global_position = spot
		if drag and spot != Vector3.INF:
			_brush.rotation.z = sin(Time.get_ticks_msec() * 0.03) * 0.3
			var pixels: float = event.relative.length()
			Stable.brush(_index, pixels * CLEAN_PER_PIXEL)
			_horse.set_dirt(1.0 - Stable.care[_index].clean)
			_brush_dust += pixels
			if _brush_dust > 60.0:
				_brush_dust = 0.0
				if Stable.care[_index].clean < 0.99:
					_puff(spot, Color(0.62, 0.53, 0.42, 0.8), 6, null)
				else:
					_puff(spot, Color(1.0, 0.95, 0.6, 1.0), 4, null)
			get_viewport().set_input_as_handled()


# --- Actions ------------------------------------------------------------------

func _feed() -> void:
	_set_brushing(false)
	var horse_name: String = Stable.HORSES[_index].name
	if not Stable.feed(_index):
		_say("%s is full!" % horse_name)
		return
	_say("Crunch! %s loves carrots." % horse_name)
	var carrot := _make_carrot()
	add_child(carrot)
	var mouth := _mouth()
	var start := _camera.global_position.lerp(mouth, 0.55) + Vector3.DOWN * 0.4
	carrot.global_position = start
	carrot.look_at(mouth, Vector3.UP)
	var tween := create_tween()
	tween.tween_property(carrot, "global_position", mouth, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(carrot, "scale", Vector3.ONE * 0.05, 0.5)
	tween.tween_callback(func():
		_puff(mouth, Color(1.0, 0.55, 0.15), 8, null)
		carrot.queue_free())


func _pet() -> void:
	_set_brushing(false)
	if _pet_wait > 0.0:
		return
	_pet_wait = PET_COOLDOWN
	Stable.pet(_index)
	var horse_name: String = Stable.HORSES[_index].name
	_say(["%s nuzzles you." % horse_name, "%s loves a pat." % horse_name, "Good horse, %s!" % horse_name].pick_random())
	_puff(_neck(), Color(1.0, 0.4, 0.6), 5, _heart_texture)


func _set_brushing(on: bool) -> void:
	brushing = on
	if _brush:
		_brush.visible = false
	if _brush_button:
		_brush_button.text = "Done" if on else "Brush"
	if on:
		_say("Rub the brush over %s." % Stable.HORSES[_index].name)


# --- Where things are on the horse --------------------------------------------

## The standing horse's body box, in the horse's own space (it faces -Z).
func _body_box() -> AABB:
	if _box.size == Vector3.ZERO:
		var to_horse: Transform3D = _horse.global_transform.affine_inverse()
		var first := true
		for node in _horse.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.is_visible_in_tree() and mi.mesh and mi.mesh.get_blend_shape_count() > 0:
				var aabb: AABB = to_horse * mi.global_transform * mi.get_aabb()
				_box = aabb if first else _box.merge(aabb)
				first = false
	return _box


func _mouth() -> Vector3:
	var box := _body_box()
	return _horse.global_transform * Vector3(0, box.end.y - 0.45, box.position.z + 0.12)


func _neck() -> Vector3:
	var box := _body_box()
	return _horse.global_transform * Vector3(0, box.end.y - 0.1, box.position.z + 0.6)


## The point under the screen position on a plane through the horse facing
## the camera, or Vector3.INF if that's not on the horse.
func _point_on_horse(screen: Vector2) -> Vector3:
	var origin := _camera.project_ray_origin(screen)
	var dir := _camera.project_ray_normal(screen)
	var centre := _horse.global_position + Vector3.UP * 1.0
	var normal := (_camera.global_position - centre) * Vector3(1, 0, 1)
	var hit = Plane(normal.normalized(), centre).intersects_ray(origin, dir)
	if hit == null:
		return Vector3.INF
	var local: Vector3 = _horse.global_transform.affine_inverse() * hit
	var box := _body_box().grow(0.05)
	# Only the body and legs, not the empty space above the back.
	if not box.has_point(local) or local.y > box.end.y - 0.1:
		return Vector3.INF
	return hit + normal.normalized() * 0.35


# --- Effects ------------------------------------------------------------------

## A little burst of dust, crumbs, sparkles or hearts.
func _puff(where: Vector3, color: Color, amount: int, texture: Texture2D) -> void:
	var particles := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * (0.16 if texture else 0.06)
	var material := StandardMaterial3D.new()
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	if texture:
		material.albedo_texture = texture
	quad.material = material
	particles.mesh = quad
	particles.amount = amount
	particles.one_shot = true
	particles.explosiveness = 0.8 if not texture else 0.3
	particles.lifetime = 1.2 if texture else 0.7
	particles.direction = Vector3.UP
	particles.spread = 50.0
	particles.initial_velocity_min = 0.2 if texture else 0.3
	particles.initial_velocity_max = 0.5 if texture else 0.9
	particles.gravity = Vector3.UP * (0.15 if texture else -0.8)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, color)
	fade.set_color(1, Color(color, 0.0))
	particles.color_ramp = fade
	particles.position = where   # This node sits at the world origin
	add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


func _make_carrot() -> Node3D:
	var carrot := Node3D.new()
	var root := CylinderMesh.new()
	root.top_radius = 0.035
	root.bottom_radius = 0.004
	root.height = 0.22
	var orange := StandardMaterial3D.new()
	orange.albedo_color = Color(1.0, 0.45, 0.08)
	var body := MeshInstance3D.new()
	body.mesh = root
	body.material_override = orange
	body.rotation.x = -PI / 2   # Point down -Z, towards where it is looking
	carrot.add_child(body)
	var leaves := CylinderMesh.new()
	leaves.top_radius = 0.03
	leaves.bottom_radius = 0.008
	leaves.height = 0.08
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.25, 0.6, 0.15)
	var top := MeshInstance3D.new()
	top.mesh = leaves
	top.material_override = green
	top.rotation.x = -PI / 2
	top.position.z = 0.14
	carrot.add_child(top)
	return carrot


func _build_brush() -> void:
	_brush = Node3D.new()
	_brush.visible = false
	add_child(_brush)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.32, 0.18)
	var back := BoxMesh.new()
	back.size = Vector3(0.34, 0.07, 0.15)
	var handle := MeshInstance3D.new()
	handle.mesh = back
	handle.material_override = wood
	handle.position.y = 0.06
	_brush.add_child(handle)
	var hair := StandardMaterial3D.new()
	hair.albedo_color = Color(0.95, 0.85, 0.6)
	hair.roughness = 1.0
	var bristle_mesh := BoxMesh.new()
	bristle_mesh.size = Vector3(0.31, 0.06, 0.12)
	var bristles := MeshInstance3D.new()
	bristles.mesh = bristle_mesh
	bristles.material_override = hair
	_brush.add_child(bristles)


func _make_heart_texture() -> Texture2D:
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			# The classic heart curve, (x² + y² - 1)³ - x²y³ <= 0.
			var px := (x - size * 0.5) / (size * 0.38)
			var py := (size * 0.55 - y) / (size * 0.38)
			var v := pow(px * px + py * py - 1.0, 3.0) - px * px * py * py * py
			image.set_pixel(x, y, Color(1, 1, 1, clampf(-v * 40.0, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


# --- On-screen controls -------------------------------------------------------

func _refresh() -> void:
	var care: Dictionary = Stable.care[_index]
	for key in _bars:
		_bars[key].value = care[key] * 100.0
	var horse_name: String = Stable.HORSES[_index].name
	var happy: float = Stable.happiness(_index)
	if care.food < 0.25:
		_mood.text = "%s is hungry" % horse_name
	elif care.clean < 0.25:
		_mood.text = "%s needs a brush" % horse_name
	elif care.love < 0.25:
		_mood.text = "%s wants a pat" % horse_name
	elif happy > 0.85:
		_mood.text = "%s is very happy" % horse_name
	else:
		_mood.text = "%s is happy" % horse_name
	_horse.set_dirt(1.0 - care.clean)


func _say(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 2.0   # Stays fully visible for a moment before fading


func _build_ui(root: Control) -> void:
	var panel := PanelContainer.new()
	_panel = panel
	panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.06, 0.12, 0.5)))
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.position.x += 24

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	_mood = _label("", 24)
	_mood.custom_minimum_size.x = 280
	column.add_child(_mood)
	for row in [["food", "Food", Color(1.0, 0.6, 0.2)], ["clean", "Clean", Color(0.45, 0.75, 1.0)], ["love", "Love", Color(1.0, 0.45, 0.65)]]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		column.add_child(line)
		var title := _label(row[1], 20)
		title.custom_minimum_size.x = 70
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		line.add_child(title)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(180, 20)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var back := _style(Color(0, 0, 0, 0.35))
		back.content_margin_top = 0
		back.content_margin_bottom = 0
		var fill := _style(row[2])
		fill.content_margin_top = 0
		fill.content_margin_bottom = 0
		bar.add_theme_stylebox_override("background", back)
		bar.add_theme_stylebox_override("fill", fill)
		line.add_child(bar)
		_bars[row[0]] = bar

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	column.add_child(buttons)
	buttons.add_child(_button("Feed", _feed))
	_brush_button = _button("Brush", func(): _set_brushing(not brushing))
	buttons.add_child(_brush_button)
	buttons.add_child(_button("Pet", _pet))

	_toast = _label("", 28)
	_toast.modulate.a = 0.0
	_toast.add_theme_stylebox_override("normal", _style(Color(0.08, 0.06, 0.12, 0.55)))
	root.add_child(_toast)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.position.y += 84


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	label.add_theme_constant_override("outline_size", 6)
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(88, 60)
	button.add_theme_font_size_override("font_size", 22)
	var style := _style(Color(1, 0.97, 0.9, 0.9))
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, Color(0.2, 0.15, 0.25))
	button.pressed.connect(action)
	return button


func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(14)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style
