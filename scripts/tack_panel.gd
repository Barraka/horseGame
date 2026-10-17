extends Node
## The stable's tack room: a "Tack" button that opens a panel on the right
## to choose each horse's saddle pad, trim, saddle, bridle and leg wraps.
## Changes show on the horse straight away and are saved for that horse.

const Tack := preload("res://scripts/tack.gd")
## The rows on screen, in order: config key and label.
const ROWS := [
	["pad", "Saddle pad"], ["trim", "Pad trim"], ["saddle", "Saddle"],
	["bridle", "Bridle"], ["wraps", "Leg wraps"],
]

var _horse: Node3D
var _index := 0
var _config: Dictionary
var _panel: PanelContainer
var _values := {}     ## Config key -> the Label showing its choice
var _swatches := {}   ## Config key -> the ColorRect showing its colour


func setup(horse: Node3D, ui_root: Control) -> void:
	_horse = horse
	_build_ui(ui_root)


func show_horse(index: int) -> void:
	_index = index
	_config = Tack.DEFAULT.duplicate()
	_config.merge(Stable.tack[index], true)
	_horse.set_tack(_config)
	_refresh()


func _change(key: String, step: int) -> void:
	_config[key] = wrapi(_config[key] + step, 0, Tack.OPTIONS[key].size())
	Stable.set_tack(_index, _config)
	_horse.set_tack(_config)
	_refresh()


func _toggle() -> void:
	_panel.visible = not _panel.visible


func _refresh() -> void:
	for key in _values:
		var option: Dictionary = Tack.OPTIONS[key][_config[key]]
		_values[key].text = option.name
		var color: Color = option.color
		_swatches[key].visible = color.a > 0.0
		_swatches[key].color = color


func _build_ui(root: Control) -> void:
	var open := _button("Tack", 20, _toggle, Vector2(150, 52))
	root.add_child(open)
	open.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	open.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	open.position += Vector2(-24, 88)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.06, 0.12, 0.5)))
	root.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.position += Vector2(-24, 36)   # Clear of the Tack button above
	_panel.visible = false

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	for row_info in ROWS:
		var key: String = row_info[0]
		var title := _label(row_info[1], 18)
		title.modulate = Color(1, 0.95, 0.85, 0.85)
		column.add_child(title)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		column.add_child(row)
		row.add_child(_button("◀", 26, _change.bind(key, -1), Vector2(56, 52)))
		var value_box := HBoxContainer.new()
		value_box.custom_minimum_size.x = 170
		value_box.alignment = BoxContainer.ALIGNMENT_CENTER
		value_box.add_theme_constant_override("separation", 8)
		row.add_child(value_box)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(20, 20)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		value_box.add_child(swatch)
		_swatches[key] = swatch
		var value := _label("", 22)
		value_box.add_child(value)
		_values[key] = value
		row.add_child(_button("▶", 26, _change.bind(key, 1), Vector2(56, 52)))


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
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style
