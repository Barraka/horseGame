extends Node
## The stable's trophy shelf: a "Trophies" button that opens a panel on the
## right with the cups won in each competition (see competitions.gd) and
## the rosettes from every result.

signal opened

const Competitions := preload("res://scripts/competitions.gd")

var _panel: PanelContainer
var _cups := {}        ## "event:cup" -> [TextureRect, Label]
var _rosettes: Array[Label] = []
var _cup_won: Array[ImageTexture] = []
var _cup_empty: ImageTexture


func setup(ui_root: Control) -> void:
	for color in Competitions.CUP_COLORS:
		_cup_won.append(cup_texture(color, 56))
	_cup_empty = cup_texture(Color(1, 1, 1, 0.18), 56)
	_build_ui(ui_root)


func is_open() -> bool:
	return _panel.visible


func close() -> void:
	_panel.visible = false


func _toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_refresh()
		opened.emit()


func _refresh() -> void:
	var counts := [0, 0, 0, 0]
	for which in Competitions.EVENTS:
		for i in Competitions.CUPS.size():
			var best: int = Stable.best_place(which, i)
			var row: Array = _cups["%s:%d" % [which, i]]
			row[0].texture = _cup_won[i] if best == 1 else _cup_empty
			if best == 1:
				row[1].text = "Won!"
			elif best > 1:
				row[1].text = "Best: %s" % Competitions.PLACES[best - 1]
			elif Stable.cup_open(which, i):
				row[1].text = "Not tried"
			else:
				row[1].text = "Locked"
			if best > 0:
				counts[best - 1] += 1
	for i in _rosettes.size():
		_rosettes[i].text = "× %d" % counts[i]


## A trophy cup drawn in code: a bowl with handles on a stem and base.
static func cup_texture(color: Color, size: int) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var s := float(size)
	for y in size:
		for x in size:
			var px := (x + 0.5) / s - 0.5   # -0.5 .. 0.5, centre at 0
			var py := (y + 0.5) / s         # 0 at the top
			var inside := false
			# Bowl: the lower half of an ellipse.
			if py > 0.1 and py < 0.55:
				var t := (py - 0.1) / 0.45
				inside = absf(px) < 0.3 * sqrt(maxf(1.0 - t * t, 0.0)) + 0.02
			# Handles: rings either side of the bowl.
			for side in [-1.0, 1.0]:
				var d: float = Vector2(px - side * 0.3, py - 0.27).length()
				if d < 0.12 and d > 0.07:
					inside = true
			if absf(px) < 0.05 and py >= 0.55 and py < 0.78:
				inside = true   # Stem
			if absf(px) < 0.22 and py >= 0.78 and py < 0.9:
				inside = true   # Base
			if inside:
				var shine := clampf(1.0 - absf(px + 0.12) * 5.0, 0.0, 1.0) * 0.45
				var c := color.lerp(Color(1, 1, 0.92, color.a), shine)
				image.set_pixel(x, y, c)
	return ImageTexture.create_from_image(image)


## A rosette drawn in code: a frilled disc with two ribbon tails.
static func rosette_texture(color: Color, size: int) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var s := float(size)
	var centre := Vector2(0.5, 0.4)
	for y in size:
		for x in size:
			var p := Vector2((x + 0.5) / s, (y + 0.5) / s)
			var d := p.distance_to(centre)
			var angle := (p - centre).angle()
			var c := Color.TRANSPARENT
			# Tails behind the disc.
			for side in [-1.0, 1.0]:
				var along := p.y - 0.5
				var across: float = p.x - 0.5 - side * (0.1 + along * 0.25)
				if along > 0.0 and along < 0.48 and absf(across) < 0.09 and not (along > 0.4 and absf(across) < (along - 0.4) * 1.2):
					c = color.darkened(0.15)
			if d < 0.3 + 0.03 * sin(angle * 14.0):
				c = color
			if d < 0.17:
				c = color.lightened(0.35)
			if d < 0.12:
				c = color.darkened(0.05)
			image.set_pixel(x, y, c)
	return ImageTexture.create_from_image(image)


func _build_ui(root: Control) -> void:
	var open := _button("Trophies", Vector2(150, 52))
	open.pressed.connect(_toggle)
	root.add_child(open)
	open.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	open.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	open.position += Vector2(-24, 216)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.06, 0.12, 0.6)))
	root.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.position += Vector2(-24, 92)   # Under the buttons
	_panel.visible = false

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)
	column.add_child(_label("Trophies", 24))
	# The competitions two by two.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 10)
	column.add_child(grid)
	for which in Competitions.EVENTS:
		var event := VBoxContainer.new()
		event.add_theme_constant_override("separation", 4)
		grid.add_child(event)
		var title := _label(Competitions.EVENTS[which], 18)
		title.modulate = Color(1, 0.95, 0.85, 0.8)
		event.add_child(title)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		event.add_child(row)
		for i in Competitions.CUPS.size():
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", 0)
			cell.custom_minimum_size.x = 80
			row.add_child(cell)
			var icon := TextureRect.new()
			icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			icon.custom_minimum_size = Vector2(56, 56)
			cell.add_child(icon)
			cell.add_child(_label(Competitions.CUPS[i].get_slice(" ", 0), 15))
			var state := _label("", 13)
			state.modulate = Color(1, 1, 1, 0.7)
			cell.add_child(state)
			_cups["%s:%d" % [which, i]] = [icon, state]

	column.add_child(_label("Rosettes", 18))
	var rosettes := HBoxContainer.new()
	rosettes.alignment = BoxContainer.ALIGNMENT_CENTER
	rosettes.add_theme_constant_override("separation", 6)
	column.add_child(rosettes)
	for color in Competitions.ROSETTE_COLORS:
		var icon := TextureRect.new()
		icon.texture = rosette_texture(color, 36)
		rosettes.add_child(icon)
		var count := _label("", 16)
		count.custom_minimum_size.x = 36
		rosettes.add_child(count)
		_rosettes.append(count)


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	label.add_theme_constant_override("outline_size", 6)
	return label


func _button(text: String, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", 20)
	var style := _style(Color(0.08, 0.06, 0.12, 0.45))
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, style)
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
