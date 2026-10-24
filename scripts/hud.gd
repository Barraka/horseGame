extends CanvasLayer
## On-screen display: gait buttons, course status, messages, and the
## touch controls (joystick, Faster, Slower, Jump) on touch screens, and a
## breath bar while the horse is galloping or getting its breath back.

@export var horse_path: NodePath
@export var course_path: NodePath

var _horse: Node
var _gait_buttons: Array[Button] = []
var _status: Label
var _explore: Label
var _toast: Label
var _toast_tween: Tween
var _breath: ProgressBar


func _ready() -> void:
	_horse = get_node(horse_path)
	var course := get_node(course_path)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_gait_bar(root)
	_status = _panel_label(root, Control.PRESET_TOP_LEFT, Vector2(20, 20), 20)
	_explore = _panel_label(root, Control.PRESET_TOP_LEFT, Vector2(20, 112), 18)
	var coins := preload("res://scripts/coin_badge.gd").new()
	root.add_child(coins)
	coins.position = Vector2(20, 164)
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BOTH
	_toast.position.y -= 120
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 40)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_toast.add_theme_constant_override("outline_size", 10)
	_toast.modulate.a = 0.0
	root.add_child(_toast)

	if DisplayServer.is_touchscreen_available():
		_build_touch_controls(root)
	else:
		var help := _panel_label(root, Control.PRESET_TOP_RIGHT, Vector2(-20, 20), 15)
		help.text = "U / J  ride on / slow down\nH / K  steer\nLeft click  faster\nRight click  slower\nSpace  jump\nDrag  look around"

	var stable := Button.new()
	stable.text = "Stable"
	stable.focus_mode = Control.FOCUS_NONE
	stable.custom_minimum_size = Vector2(120, 48)
	stable.add_theme_font_size_override("font_size", 18)
	for state in ["normal", "hover", "pressed"]:
		stable.add_theme_stylebox_override(state, _panel_style())
	stable.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/stable.tscn"))
	root.add_child(stable)
	stable.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	stable.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stable.position.y += 20

	_horse.gait_changed.connect(_on_gait_changed)
	_horse.jump_refused.connect(func(): show_message("Trot or faster to jump!"))
	_horse.out_of_breath.connect(func(): show_message("%s is out of breath!\nCanter or trot for a bit" % Stable.horse_name(Stable.selected)))
	Stable.level_up.connect(func(_i, skill, level): show_message("%s's %s is now level %d!" % [Stable.horse_name(Stable.selected), Stable.SKILL_NAMES[skill].to_lower(), level]))
	course.status_changed.connect(func(text): _status.text = text)
	course.announce.connect(show_message)
	_on_gait_changed(0)


func _process(_delta: float) -> void:
	_breath.value = _horse.energy * 100.0
	_breath.visible = _horse.energy < 0.999
	_breath.modulate = Color(1, 0.55, 0.45) if _horse.energy < _horse.GALLOP_AGAIN else Color.WHITE


## The explore line under the course status, e.g. "Places found: 2 of 6".
func set_explore_text(text: String) -> void:
	_explore.text = text


func show_message(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(1.3)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _panel_style(alpha := 0.45) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.12, alpha)
	style.set_corner_radius_all(14)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _panel_label(root: Control, preset: int, offset: Vector2, font_size: int) -> Label:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(preset)
	if preset == Control.PRESET_TOP_RIGHT:
		panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.position += offset
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	panel.add_child(label)
	return label


func _build_gait_bar(root: Control) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	root.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.position.y -= 24
	for i in _horse.GAITS.size():
		var button := Button.new()
		button.text = ("■ " if i == 0 else "%d " % i) + _horse.GAITS[i].name
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(110, 48)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(_horse.set_gait.bind(i))
		bar.add_child(button)
		_gait_buttons.append(button)

	# Breath, just above the gait buttons.
	_breath = ProgressBar.new()
	_breath.show_percentage = false
	_breath.custom_minimum_size = Vector2(300, 14)
	_breath.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := _panel_style()
	var fill := _panel_style(1.0)
	fill.bg_color = Color(0.55, 0.85, 1.0)
	for style in [back, fill]:
		style.set_corner_radius_all(7)
		style.content_margin_top = 0
		style.content_margin_bottom = 0
	_breath.add_theme_stylebox_override("background", back)
	_breath.add_theme_stylebox_override("fill", fill)
	root.add_child(_breath)
	_breath.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_breath.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_breath.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_breath.position.y -= 86
	_breath.visible = false


func _on_gait_changed(gait: int) -> void:
	for i in _gait_buttons.size():
		var selected := i == gait
		var style := _panel_style(0.92 if selected else 0.45)
		if selected:
			style.bg_color = Color(1, 0.97, 0.9, 0.95)
		for state in ["normal", "hover", "pressed"]:
			_gait_buttons[i].add_theme_stylebox_override(state, style)
		var color := Color(0.2, 0.15, 0.25) if selected else Color.WHITE
		for state in ["font_color", "font_hover_color", "font_pressed_color"]:
			_gait_buttons[i].add_theme_color_override(state, color)


func _build_touch_controls(root: Control) -> void:
	var stick: Control = preload("res://scripts/virtual_joystick.gd").new()
	root.add_child(stick)
	stick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	stick.size = stick.custom_minimum_size
	stick.position += Vector2(40, -40 - stick.size.y)

	_touch_button(root, "Jump", "jump", 70.0, Vector2(-120, -130))
	_touch_button(root, "Faster", "gait_up", 52.0, Vector2(-290, -200))
	_touch_button(root, "Slower", "gait_down", 52.0, Vector2(-290, -80))


## A round on-screen button that presses an input action (multi-touch safe).
func _touch_button(root: Control, text: String, action: String, radius: float, offset_from_corner: Vector2) -> void:
	var anchor := Control.new()
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(anchor)
	anchor.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)

	var button := TouchScreenButton.new()
	button.texture_normal = _circle_texture(radius, Color(0.08, 0.06, 0.12, 0.45))
	button.texture_pressed = _circle_texture(radius, Color(1, 1, 1, 0.55))
	button.action = action
	button.position = offset_from_corner - Vector2.ONE * radius
	anchor.add_child(button)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2.ONE * radius * 2.0
	button.add_child(label)


func _circle_texture(radius: float, color: Color) -> ImageTexture:
	var d := int(radius * 2.0)
	var image := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var center := Vector2(radius, radius)
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if dist <= radius:
				var edge := dist > radius - 3.0
				image.set_pixel(x, y, Color(1, 1, 1, 0.7) if edge else color)
	return ImageTexture.create_from_image(image)
