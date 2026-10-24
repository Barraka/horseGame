extends Node
## The stable's shop: a "Shop" button that opens a panel on the right with
## new horses and fancy tack colours to buy with coins. Tapping a horse
## shows it on the stand; tapping tack tries it on the horse in the stable.

signal opened
signal closed

const Tack := preload("res://scripts/tack.gd")
const CoinBadge := preload("res://scripts/coin_badge.gd")
const TACK_NAMES := {"pad": "Saddle pad", "trim": "Pad trim", "saddle": "Saddle", "bridle": "Bridle", "wraps": "Leg wraps"}

var _stable: Node3D   ## stable.gd: shows horses and tack while browsing
var _panel: PanelContainer
var _list: VBoxContainer
var _tabs: Array[Button] = []
var _tab := 0
var _message: Label
var _coin: ImageTexture


func setup(stable: Node3D, ui_root: Control) -> void:
	_stable = stable
	_coin = CoinBadge.coin_texture(11)
	_build_ui(ui_root)
	Stable.coins_changed.connect(func(_c, _g): if _panel.visible: _fill())


func is_open() -> bool:
	return _panel.visible


func close() -> void:
	if _panel.visible:
		_panel.visible = false
		closed.emit()


func _toggle() -> void:
	if _panel.visible:
		close()
	else:
		_panel.visible = true
		_message.text = "Tap something to try it"
		_fill()
		opened.emit()


func _show_tab(tab: int) -> void:
	_tab = tab
	_message.text = "Tap something to try it"
	_stable.end_preview()
	_fill()


# --- The list -----------------------------------------------------------------

func _fill() -> void:
	for child in _list.get_children():
		child.queue_free()
	for i in _tabs.size():
		_tabs[i].modulate.a = 1.0 if i == _tab else 0.5
	if _tab == 0:
		for i in Stable.HORSES.size():
			var horse: Dictionary = Stable.HORSES[i]
			if horse.has("price"):
				var kind := "%s%s · %s" % [horse.breed, " foal" if horse.get("foal", false) else "", horse.coat]
				_add_row(horse.name, kind, [horse.body, horse.get("pattern_color", horse.points)],
					horse.price, Stable.owns(i), _preview_horse.bind(i), _buy_horse.bind(i))
	else:
		for key in Tack.OPTIONS:
			var options: Array = Tack.OPTIONS[key]
			for i in options.size():
				if options[i].has("price"):
					_add_row(options[i].name, TACK_NAMES[key], [options[i].color], options[i].price,
						Stable.owns_tack(key, i, Tack.OPTIONS), _preview_tack.bind(key, i), _buy_tack.bind(key, i))


func _add_row(title: String, kind: String, colors: Array, price: int, owned: bool, preview: Callable, buy: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_list.add_child(row)
	# The colours, then the name: both try the item on when tapped.
	var look := Button.new()
	look.focus_mode = Control.FOCUS_NONE
	look.custom_minimum_size = Vector2(230, 56)
	look.alignment = HORIZONTAL_ALIGNMENT_LEFT
	look.add_theme_stylebox_override("normal", _style(Color(1, 1, 1, 0.06)))
	look.add_theme_stylebox_override("hover", _style(Color(1, 1, 1, 0.12)))
	look.add_theme_stylebox_override("pressed", _style(Color(1, 1, 1, 0.2)))
	look.pressed.connect(preview)
	row.add_child(look)
	var inside := HBoxContainer.new()
	inside.add_theme_constant_override("separation", 8)
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inside.offset_left = 12
	look.add_child(inside)
	for color: Color in colors:
		var swatch := ColorRect.new()
		swatch.color = color
		swatch.custom_minimum_size = Vector2(16, 28)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inside.add_child(swatch)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -4)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inside.add_child(words)
	words.add_child(_label(title, 20, HORIZONTAL_ALIGNMENT_LEFT))
	var small := _label(kind, 14, HORIZONTAL_ALIGNMENT_LEFT)
	small.modulate = Color(1, 0.95, 0.85, 0.75)
	words.add_child(small)

	if owned:
		var have := _label("Yours", 18, HORIZONTAL_ALIGNMENT_CENTER)
		have.custom_minimum_size = Vector2(110, 52)
		have.modulate = Color(0.75, 1.0, 0.75)
		row.add_child(have)
		return
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(110, 52)
	button.text = str(price)
	button.icon = _coin
	button.add_theme_font_size_override("font_size", 20)
	var affordable := Stable.coins >= price
	var style := _style(Color(1, 0.97, 0.9, 0.95) if affordable else Color(0.08, 0.06, 0.12, 0.45))
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, Color(0.2, 0.15, 0.25) if affordable else Color(1, 1, 1, 0.6))
	button.pressed.connect(buy)
	row.add_child(button)


# --- Trying and buying ----------------------------------------------------------

func _preview_horse(index: int) -> void:
	var horse: Dictionary = Stable.HORSES[index]
	_stable.preview_horse(index)
	_message.text = "%s, %s" % [horse.name, horse.coat.to_lower()] if Stable.owns(index) else "%s costs %d coins" % [horse.name, horse.price]


func _preview_tack(key: String, index: int) -> void:
	_stable.preview_tack(key, index)
	_message.text = "%s on %s" % [Tack.OPTIONS[key][index].name, _stable.horse_name()]


func _buy_horse(index: int) -> void:
	var horse: Dictionary = Stable.HORSES[index]
	_stable.preview_horse(index)
	if Stable.buy_horse(index):
		_stable.adopt(index)
		_message.text = "%s is yours and waiting in the stable!" % horse.name
		_fill()
	else:
		_message.text = "You need %d more coins for %s" % [horse.price - Stable.coins, horse.name]


func _buy_tack(key: String, index: int) -> void:
	var option: Dictionary = Tack.OPTIONS[key][index]
	_stable.preview_tack(key, index)
	if Stable.buy_tack(key, index, Tack.OPTIONS):
		_stable.keep_tack(key, index)
		_message.text = "%s %s is yours!" % [option.name, TACK_NAMES[key].to_lower()]
		_fill()
	else:
		_message.text = "You need %d more coins" % (option.price - Stable.coins)


# --- Building the panel ---------------------------------------------------------

func _build_ui(root: Control) -> void:
	var open := _button("Shop", 20, _toggle, Vector2(150, 52))
	root.add_child(open)
	open.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	open.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	open.position += Vector2(-24, 152)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.06, 0.12, 0.6)))
	root.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.position += Vector2(-24, 60)   # Under the buttons
	_panel.visible = false

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	column.add_child(tabs)
	for i in 2:
		var tab := _button(["Horses", "Tack"][i], 20, _show_tab.bind(i), Vector2(150, 48))
		tabs.add_child(tab)
		_tabs.append(tab)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(370, 320)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	_message = _label("", 18, HORIZONTAL_ALIGNMENT_CENTER)
	_message.custom_minimum_size.x = 370
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD
	column.add_child(_message)


func _label(text: String, font_size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	style.set_corner_radius_all(14)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
