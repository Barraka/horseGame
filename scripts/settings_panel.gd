extends PanelContainer
## The settings window: music and sound volume, graphics quality, keyboard
## help and full screen. Changes are kept straight away (see settings.gd).
## Add it to a full-screen Control and call open().

signal closed

var _rows: VBoxContainer
var _quality_buttons: Array[Button] = []


func _ready() -> void:
	visible = false
	add_theme_stylebox_override("panel", _style(Color(0.1, 0.07, 0.14, 0.92)))
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 16)
	add_child(_rows)

	var title := _label("Settings", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_rows.add_child(title)
	_slider_row("Music", Settings.music, func(v): Settings.change("music", v))
	_slider_row("Sounds", Settings.sounds, func(v): Settings.change("sounds", v))

	var quality := _row("Graphics")
	for i in Settings.QUALITIES.size():
		var button := _button(Settings.QUALITIES[i], func(): _pick_quality(i))
		button.custom_minimum_size = Vector2(96, 48)
		quality.add_child(button)
		_quality_buttons.append(button)
	var hint := _label("Lower is smoother on a tablet. The countryside changes the next time it loads.", 15)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.custom_minimum_size.x = 440
	hint.modulate = Color(1, 1, 1, 0.7)
	_rows.add_child(hint)

	if not DisplayServer.is_touchscreen_available():
		_check_row("Keyboard help while riding", Settings.show_help, func(on): Settings.change("show_help", on))
	if not OS.has_feature("mobile"):
		_check_row("Full screen", Settings.fullscreen, func(on): Settings.change("fullscreen", on))

	var done := _button("Done", close)
	done.custom_minimum_size = Vector2(200, 56)
	var centre := CenterContainer.new()
	centre.add_child(done)
	_rows.add_child(centre)
	_show_quality()


func open() -> void:
	visible = true
	_show_quality()


func close() -> void:
	visible = false
	closed.emit()


func _pick_quality(i: int) -> void:
	Settings.change("quality", i)
	_show_quality()


func _show_quality() -> void:
	for i in _quality_buttons.size():
		_quality_buttons[i].modulate.a = 1.0 if i == Settings.quality else 0.45


# --- Building -------------------------------------------------------------------

func _row(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := _label(text, 22)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.custom_minimum_size.x = 150
	row.add_child(name_label)
	_rows.add_child(row)
	return row


func _slider_row(text: String, value: float, on_change: Callable) -> void:
	var row := _row(text)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(290, 40)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(on_change)
	row.add_child(slider)


func _check_row(text: String, on: bool, on_change: Callable) -> void:
	var check := CheckButton.new()
	check.text = text
	check.button_pressed = on
	check.focus_mode = Control.FOCUS_NONE
	check.add_theme_font_size_override("font_size", 20)
	check.toggled.connect(on_change)
	_rows.add_child(check)


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
	button.add_theme_font_size_override("font_size", 20)
	var style := _style(Color(1, 1, 1, 0.15))
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(action)
	return button


func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(16)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style
