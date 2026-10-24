extends Node3D
## The stable: browse your horses, see each one up close in the stable
## building's aisle (the others stand in their stalls), look after them,
## choose their tack, see the trophies won, and pick one to ride.

const Horse := preload("res://scripts/horse.gd")
const HorseCare := preload("res://scripts/horse_care.gd")
const TackPanel := preload("res://scripts/tack_panel.gd")
const Shop := preload("res://scripts/shop.gd")
const TrophyShelf := preload("res://scripts/trophy_shelf.gd")
const CoinBadge := preload("res://scripts/coin_badge.gd")
const StableBarn := preload("res://scripts/stable_barn.gd")
const DailyPanel := preload("res://scripts/daily_panel.gd")
const RIDE_SCENE := "res://scenes/main.tscn"
const RIDER_SCENE := "res://scenes/rider_creator.tscn"
const CAMERA_POS := Vector3(4.5, 1.8, 5.1)
const CAMERA_TARGET := Vector3(0, 0.55, 0)   ## Below the horse, so it stands above the controls

var _index := 0
var _horse: Node3D
var _care: Node3D
var _tack: Node
var _salon: Node   ## The grooming salon (another tack_panel.gd)
var _shop: Node
var _trophies: Node
var _daily: Node
var _picker: PanelContainer
var _camera: Camera3D
var _turntable: Node3D
var _barn: Node3D
var _name_label: Label
var _coat_label: Label
var _name_dialog: PanelContainer
var _name_title: Label
var _name_edit: LineEdit
var _naming := -1   ## The horse being named
var _ride_button: Button
var _dots: HBoxContainer
var _drag_spin := 0.0
var _idle_time := 10.0


func _ready() -> void:
	# The first time the game starts, make a rider before anything else.
	if not RiderData.saved:
		set_process(false)
		set_process_unhandled_input(false)
		_open_rider_creator.call_deferred()
		return
	_index = Stable.selected
	_build_scene()
	_build_ui()
	_show_horse()
	# A foal grows a little with each carrot.
	Stable.care_changed.connect(func(i): if i == _index and not _shop.is_open(): _show_growth())
	Stable.grown_up.connect(func(i): if i == _index: _show_horse())


func _process(delta: float) -> void:
	# Turn slowly on its own, unless the player has just turned it by hand.
	_idle_time += delta
	if _idle_time > 2.0:
		_turntable.rotation.y += 0.25 * delta
	_turntable.rotation.y += _drag_spin
	_drag_spin = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if _care.brushing or _name_dialog.visible:
		return   # Dragging brushes the horse instead
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
	if _shop.is_open():
		return
	var owned: Array[int] = Stable.owned_horses()
	_index = owned[wrapi(owned.find(_index) + step, 0, owned.size())]
	_show_horse()


func _show_horse() -> void:
	var horse: Dictionary = Stable.HORSES[_index]
	_horse.show_coat(horse)
	_name_label.text = Stable.horse_name(_index)
	_show_growth()
	_horse.set_dirt(1.0 - Stable.care[_index].clean)
	_care.show_horse(_index)
	_tack.show_horse(_index)
	_salon.show_horse(_index)
	_barn.fill_stalls(_index)
	var owned: Array[int] = Stable.owned_horses()
	for i in _dots.get_child_count():
		_dots.get_child(i).visible = i < owned.size()
		_dots.get_child(i).modulate.a = 1.0 if i < owned.size() and owned[i] == _index else 0.35


## The horse's size, and whether it's old enough to ride yet.
func _show_growth() -> void:
	var horse: Dictionary = Stable.HORSES[_index]
	_horse.set_body_shape(Stable.body_shape(_index))
	_horse.set_tack_visible(not Stable.is_foal(_index))
	_coat_label.text = "%s%s · %s" % [horse.breed, " foal" if Stable.is_foal(_index) else "", horse.coat]
	_ride_button.disabled = not Stable.can_ride(_index)
	if Stable.can_ride(_index):
		_ride_button.text = "Ride %s" % Stable.horse_name(_index)
	else:
		_ride_button.text = "Growing up: %d%%" % int(Stable.grown(_index) * 100.0)


# --- Trying things on from the shop -------------------------------------------

## Show a horse from the shop on the stand, in its own tack if it has some.
func preview_horse(index: int) -> void:
	_horse.show_coat(Stable.HORSES[index])
	_horse.set_body_shape(Stable.body_shape(index))
	_horse.set_tack_visible(not Stable.is_foal(index))
	_horse.set_tack(Stable.tack[index] if Stable.owns(index) else {})


## Try a tack colour on the horse in the stable, without keeping it.
func preview_tack(key: String, option: int) -> void:
	_horse.show_coat(Stable.HORSES[_index])
	var config: Dictionary = Stable.tack[_index].duplicate()
	config[key] = option
	_horse.set_tack(config)


## Put a bought tack colour on the horse in the stable for good.
func keep_tack(key: String, option: int) -> void:
	var config: Dictionary = Stable.tack[_index].duplicate()
	config[key] = option
	Stable.set_tack(_index, config)


## A horse just bought: it's the one shown when the shop closes.
func adopt(index: int) -> void:
	_index = index


func end_preview() -> void:
	_show_horse()


func horse_name() -> String:
	return Stable.horse_name(_index)


# --- Naming a horse -------------------------------------------------------------

## Open the box for giving a horse a name. `new_horse` is for one just
## bought, which gets a welcome instead.
func ask_name(index: int, new_horse := false) -> void:
	_naming = index
	var horse: Dictionary = Stable.HORSES[index]
	if new_horse:
		_name_title.text = "Welcome home! What will you call your new %s?" % ("foal" if horse.get("foal", false) else "horse")
	else:
		_name_title.text = "A new name for %s?" % Stable.horse_name(index)
	_name_edit.text = Stable.horse_name(index)
	_name_dialog.visible = true
	_name_edit.grab_focus()
	_name_edit.select_all()


func _keep_name(_text := "") -> void:
	if _naming < 0:
		return
	Stable.rename(_naming, _name_edit.text)
	_naming = -1
	_name_dialog.visible = false
	_name_edit.release_focus()
	_show_horse()


func _build_name_dialog(root: Control) -> void:
	_name_dialog = PanelContainer.new()
	_name_dialog.add_theme_stylebox_override("panel", _style(Color(0.1, 0.07, 0.14, 0.92)))
	root.add_child(_name_dialog)
	_name_dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_name_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_name_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	_name_dialog.visible = false
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_name_dialog.add_child(column)
	_name_title = _label("", 24)
	_name_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	_name_title.custom_minimum_size.x = 420
	column.add_child(_name_title)
	_name_edit = LineEdit.new()
	_name_edit.max_length = Stable.MAX_NAME
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.custom_minimum_size = Vector2(320, 60)
	_name_edit.add_theme_font_size_override("font_size", 32)
	_name_edit.text_submitted.connect(_keep_name)
	var middle := CenterContainer.new()
	middle.add_child(_name_edit)
	column.add_child(middle)
	var ok := _button("That's the name!", 22, _keep_name, Vector2(260, 60))
	var centre := CenterContainer.new()
	centre.add_child(ok)
	column.add_child(centre)


func _open_rider_creator() -> void:
	get_tree().change_scene_to_file(RIDER_SCENE)


func _ride() -> void:
	if _shop.is_open() or not Stable.can_ride(_index):
		return
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

	# The stable building, turned so the camera looks down its aisle.
	_barn = StableBarn.new()
	_barn.rotation.y = atan2(CAMERA_POS.x, CAMERA_POS.z)
	add_child(_barn)

	_turntable = Node3D.new()
	add_child(_turntable)
	_horse = Horse.new()
	_horse.with_rider = false   # Just the horse to admire here
	_turntable.add_child(_horse)
	_horse.set_physics_process(false)   # Only a model to look at here, not ridden
	_horse.stand()

	_camera = Camera3D.new()
	_camera.fov = 38
	add_child(_camera)
	_camera.look_at_from_position(CAMERA_POS, CAMERA_TARGET)
	_turntable.rotation.y = deg_to_rad(-70)


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

	var coins := CoinBadge.new()
	root.add_child(coins)
	coins.position = Vector2(24, 28)

	var rider := _button("My Rider", 20, _open_rider_creator, Vector2(150, 52))
	root.add_child(rider)
	rider.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	rider.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	rider.position += Vector2(-24, 24)

	var panel := PanelContainer.new()
	_picker = panel
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
	# The name, with a small button beside it to change it.
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 10)
	name_row.add_child(_name_label)
	var rename := _button("Rename", 16, func(): ask_name(_index), Vector2(0, 36))
	rename.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(rename)
	info.add_child(name_row)
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
	_ride_button.add_theme_stylebox_override("disabled", _style(Color(1, 0.97, 0.9, 0.45)))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		_ride_button.add_theme_color_override(state, Color(0.2, 0.15, 0.25))
	var centre := CenterContainer.new()
	centre.add_child(_ride_button)
	info.add_child(centre)

	row.add_child(_button("▶", 72, _browse.bind(1), Vector2(84, 84)))

	_care = HorseCare.new()
	add_child(_care)
	_care.setup(_horse, _camera, root)
	_tack = TackPanel.new()
	add_child(_tack)
	_tack.setup(_horse, root)
	_salon = TackPanel.new()
	_salon.rows = TackPanel.SALON_ROWS
	_salon.title = "Salon"
	_salon.button_y = 280.0
	add_child(_salon)
	_salon.setup(_horse, root)
	_shop = Shop.new()
	add_child(_shop)
	_shop.setup(self, root)
	_trophies = TrophyShelf.new()
	add_child(_trophies)
	_trophies.setup(root)
	# One panel on the right at a time; the shop takes the whole stand.
	_daily = DailyPanel.new()
	add_child(_daily)
	_daily.setup(root)
	_tack.opened.connect(func():
		_shop.close()
		_salon.close()
		_trophies.close()
		_daily.close())
	_salon.opened.connect(func():
		_shop.close()
		_tack.close()
		_trophies.close()
		_daily.close()
		_picker.visible = false)   # The salon reaches down over the horse picker
	_salon.closed.connect(func(): _picker.visible = not _shop.is_open())
	_trophies.opened.connect(func():
		_shop.close()
		_salon.close()
		_tack.close()
		_daily.close())
	_daily.opened.connect(func():
		_shop.close()
		_salon.close()
		_tack.close()
		_trophies.close())
	_shop.opened.connect(func():
		_tack.close()
		_salon.close()
		_trophies.close()
		_daily.close()
		_care.set_panel_visible(false)
		_picker.visible = false)
	var settings := preload("res://scripts/settings_panel.gd").new()
	root.add_child(settings)
	var settings_button := _button("Settings", 18, settings.open, Vector2(140, 48))
	root.add_child(settings_button)
	settings_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	settings_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	settings_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	settings_button.position += Vector2(-24, -24)
	root.move_child(settings, -1)   # Opens over everything
	_shop.closed.connect(func():
		_care.set_panel_visible(true)
		_picker.visible = true
		_show_horse())
	_build_name_dialog(root)   # Last, so it opens on top of everything


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
