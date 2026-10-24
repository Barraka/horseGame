extends Node
## The stable's "Today" and "Stickers" buttons (top left, beside the coins).
## Today shows the day's three tasks (daily.gd) with how far along each is,
## and the surprise box to open once they're all done. Stickers opens the
## sticker book, with a space for every sticker there is to collect.

signal opened

const Stickers := preload("res://scripts/stickers.gd")
const BOOK_COLUMNS := 6

var _today_button: Button
var _book_button: Button
var _today: PanelContainer
var _book: PanelContainer
var _rows: VBoxContainer
var _box: Control
var _box_button: Button
var _box_note: Label
var _box_sticker := ""
var _box_open := 0.0           # 0 shut, 1 lid off (animated)
var _pages: GridContainer
var _book_count: Label
var _clock := 0.0


func setup(ui_root: Control) -> void:
	_build_ui(ui_root)
	Daily.changed.connect(_refresh)
	_refresh()


func is_open() -> bool:
	return _today.visible or _book.visible


func close() -> void:
	_today.visible = false
	_book.visible = false


func _process(delta: float) -> void:
	_clock += delta
	if _today.visible:
		if _box_sticker != "" or Daily.box_opened:
			_box_open = move_toward(_box_open, 1.0, delta * 2.5)
		_box.queue_redraw()
	if _book.visible:
		for cell in _pages.get_children():
			cell.queue_redraw()


func open_today() -> void:
	var was := _today.visible
	close()
	_today.visible = not was
	Daily.refresh_day()
	_refresh()
	if _today.visible:
		opened.emit()


func open_book() -> void:
	var was := _book.visible
	close()
	_book.visible = not was
	_refresh()
	if _book.visible:
		Daily.new_stickers.clear()
		_refresh_buttons()
		opened.emit()


func _open_box() -> void:
	_box_sticker = Daily.open_box()
	_refresh()


func _refresh() -> void:
	_refresh_buttons()
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for t in Daily.today:
		var info := Daily.task_info(t.id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_rows.add_child(row)
		var tick := _label("✔" if t.done else "○", 26)
		tick.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6) if t.done else Color(1, 1, 1, 0.5))
		tick.custom_minimum_size.x = 30
		row.add_child(tick)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 2)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(column)
		var what := _label(info.text, 19)
		what.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		column.add_child(what)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(300, 10)
		bar.max_value = info.goal
		bar.value = t.progress
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.5, 1.0, 0.6) if t.done else Color(1.0, 0.8, 0.35)
		fill.set_corner_radius_all(5)
		var back := StyleBoxFlat.new()
		back.bg_color = Color(1, 1, 1, 0.15)
		back.set_corner_radius_all(5)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", back)
		column.add_child(bar)
		var reward := _label("+%d coins" % info.coins, 16)
		reward.modulate = Color(1.0, 0.9, 0.6) if not t.done else Color(1, 1, 1, 0.5)
		reward.custom_minimum_size.x = 96
		row.add_child(reward)
	var ready := Daily.box_ready()
	_box_button.visible = ready
	if ready:
		_box_note.text = "All done! Open your surprise!"
	elif Daily.box_opened:
		_box_note.text = ("You found the %s sticker and %d coins!\nNew tasks tomorrow." % [Stickers.sticker_name(_box_sticker), Daily.BOX_COINS]) \
			if _box_sticker != "" else "You opened today's surprise.\nNew tasks tomorrow!"
	else:
		_box_note.text = "Do all three for a surprise!\n%d of %d done" % [Daily.done_count(), Daily.today.size()]
	if not Daily.box_opened:
		_box_open = 0.0
		_box_sticker = ""
	# The sticker book.
	for child in _pages.get_children():
		_pages.remove_child(child)
		child.queue_free()
	for id in Stickers.all_ids():
		_pages.add_child(_sticker_cell(id))
	_book_count.text = "%d of %d stickers" % [Daily.stickers.size(), Stickers.all_ids().size()]


func _refresh_buttons() -> void:
	_today_button.text = "Today  %d/%d" % [Daily.done_count(), Daily.today.size()]
	if Daily.box_ready():
		_today_button.text = "Today  ★"
	_book_button.text = "Stickers" + ("  NEW" if not Daily.new_stickers.is_empty() else "")


func _sticker_cell(id: String) -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(96, 112)
	var have: bool = id in Daily.stickers
	cell.draw.connect(func():
		Stickers.draw(cell, id, Vector2(48, 44), 36.0, have, _clock)
		var font := ThemeDB.fallback_font
		var name_text: String = Stickers.sticker_name(id) if have else "?"
		var width := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		cell.draw_string(font, Vector2(48 - width * 0.5, 104), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color(1, 0.95, 0.85, 0.9 if have else 0.4)))
	return cell


## The surprise box: a present with a ribbon; its lid lifts off and the
## sticker inside pops up when opened.
func _draw_box() -> void:
	var c := _box
	var mid := Vector2(c.size.x * 0.5, c.size.y - 14.0)
	var w := 90.0
	var h := 64.0
	var wobble := sin(_clock * 6.0) * 3.0 if Daily.box_ready() else 0.0
	var base := Rect2(mid + Vector2(-w * 0.5, -h), Vector2(w, h))
	c.draw_rect(base, Color(0.9, 0.35, 0.55))
	c.draw_rect(Rect2(mid + Vector2(-8, -h), Vector2(16, h)), Color(1.0, 0.85, 0.35))
	if _box_open > 0.0 and _box_sticker != "":
		var rise := _box_open * 60.0
		Stickers.draw(c, _box_sticker, mid + Vector2(0, -h - rise + 20.0), 30.0 + 6.0 * _box_open, true, _clock)
	# The lid slides off to the right and lands on the floor beside the box.
	var lid_at := mid + Vector2(-w * 0.5 - 6.0, -h - 18.0 + wobble)
	lid_at = lid_at.lerp(mid + Vector2(w * 0.5 + 14.0, -18.0), _box_open)
	var lid := Rect2(lid_at, Vector2(w + 12.0, 18.0))
	c.draw_rect(lid, Color(0.95, 0.42, 0.62))
	c.draw_rect(Rect2(lid.position + Vector2(lid.size.x * 0.5 - 8.0, 0), Vector2(16, 18)), Color(1.0, 0.85, 0.35))
	var knot := lid.position + Vector2(lid.size.x * 0.5, 0)
	for side in [-1.0, 1.0]:
		c.draw_colored_polygon(PackedVector2Array([knot, knot + Vector2(side * 26.0, -16.0), knot + Vector2(side * 22.0, 4.0)]), Color(1.0, 0.8, 0.3))
	c.draw_circle(knot, 6.0, Color(1.0, 0.75, 0.25))


# --- Building ---------------------------------------------------------------------

func _build_ui(root: Control) -> void:
	_today_button = _button("Today", _open_today_pressed, Vector2(150, 52))
	root.add_child(_today_button)
	_today_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_today_button.position += Vector2(170, 24)
	_book_button = _button("Stickers", open_book, Vector2(150, 52))
	root.add_child(_book_button)
	_book_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_book_button.position += Vector2(330, 24)

	_today = _panel(root, "Today's tasks")
	var column: VBoxContainer = _today.get_child(0)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 12)
	column.add_child(_rows)
	_box = Control.new()
	_box.custom_minimum_size = Vector2(300, 190)
	_box.draw.connect(_draw_box)
	column.add_child(_box)
	_box_note = _label("", 18)
	column.add_child(_box_note)
	_box_button = _button("Open your surprise!", _open_box, Vector2(260, 56))
	_box_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_box_button)
	column.add_child(_close_button())

	_book = _panel(root, "Sticker book")
	column = _book.get_child(0)
	_book_count = _label("", 16)
	_book_count.modulate = Color(1, 0.95, 0.85, 0.75)
	column.add_child(_book_count)
	_pages = GridContainer.new()
	_pages.columns = BOOK_COLUMNS
	_pages.add_theme_constant_override("h_separation", 6)
	_pages.add_theme_constant_override("v_separation", 0)
	column.add_child(_pages)
	var hint := _label("Do the daily tasks to collect stickers. The shiny gold ones come from the surprise box!", 14)
	hint.modulate = Color(1, 1, 1, 0.6)
	column.add_child(hint)
	column.add_child(_close_button())


func _open_today_pressed() -> void:
	open_today()


func _panel(root: Control, heading: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.1, 0.07, 0.14, 0.9)))
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.visible = false
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := _label(heading, 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	column.add_child(title)
	return panel


func _close_button() -> Button:
	var done := _button("Close", close, Vector2(140, 48))
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return done


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	label.add_theme_constant_override("outline_size", 6)
	return label


func _button(text: String, action: Callable, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", 20)
	var style := _style(Color(0.08, 0.06, 0.12, 0.45))
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(action)
	return button


func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(16)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style
