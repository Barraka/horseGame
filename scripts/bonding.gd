extends Node
## Your bond with the horse while you ride: its hearts and mood on screen,
## tricks it has learnt (bow, spin, rear) at a halt, and getting off to
## walk about. Left alone the horse grazes and strolls; whistle and it
## trots over to you; take its head collar and it walks beside you. The
## hearts grow in stable_data.gd.
##
## Keys: B bow, N spin, V rear, G get off or on, F whistle, C lead or let
## go. They sit where they are on French keyboards too.

const KEYS := {KEY_B: "bow", KEY_N: "spin", KEY_V: "rear"}
const MOUNT_REACH := 3.5   ## How close you must be to get back on

@export var horse_path: NodePath
@export var camera_path: NodePath
@export var world_path: NodePath
@export var hud_path: NodePath

var on_foot: Node3D   ## You, while off the horse
var _horse: Node
var _camera: Node
var _world: Node3D
var _hud: Node
var _name: Label
var _hearts: HBoxContainer
var _mood: Label
var _trick_bar: HBoxContainer
var _foot_bar: HBoxContainer
var _trick_buttons := {}
var _mount_button: Button
var _lead_button: Button
var _whistled := false   # The horse is coming because you whistled
var _touch := false


func _ready() -> void:
	_horse = get_node(horse_path)
	_camera = get_node(camera_path)
	_world = get_node(world_path)
	_hud = get_node(hud_path)
	_touch = DisplayServer.is_touchscreen_available()
	_build_ui()
	Stable.bond_changed.connect(_on_bond)
	Stable.care_changed.connect(func(_i): _refresh())
	_horse.came_over.connect(_on_came_over)
	_horse.trick_done.connect(_on_trick_done)
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if KEYS.has(key.physical_keycode):
		do_trick(KEYS[key.physical_keycode])
	elif key.physical_keycode == KEY_G:
		if on_foot:
			get_on()
		else:
			get_off()
	elif key.physical_keycode == KEY_F:
		whistle()
	elif key.physical_keycode == KEY_C:
		toggle_lead()


## Ask the horse for a trick. Returns true if it does it.
func do_trick(trick: String) -> bool:
	var horse_name: String = Stable.horse_name(Stable.selected)
	if on_foot or _horse.trick != "":
		return false
	if not Stable.knows_trick(Stable.selected, trick):
		_say("%s learns %s at %d hearts.\nCare and rides make hearts grow!" % [horse_name, Stable.TRICKS[trick].name.to_lower(), Stable.TRICKS[trick].hearts])
		return false
	if Stable.happiness(Stable.selected) < Stable.UNHAPPY:
		_say("%s isn't in the mood.\nA little care in the stable will help." % horse_name)
		return false
	if absf(_horse.speed) > 0.3 or _horse.jumping:
		_say("Stop first, then ask for a trick")
		return false
	return _horse.perform(trick)


## Get off and walk. Only at a halt.
func get_off() -> bool:
	if on_foot or _horse.trick != "" or absf(_horse.speed) > 0.3 or _horse.jumping:
		return false
	on_foot = preload("res://scripts/on_foot.gd").new()
	on_foot.name = "OnFoot"
	_world.get_parent().add_child(on_foot)
	var rider_data := get_node_or_null("/root/RiderData")
	on_foot.setup(_world, rider_data.config if rider_data else {})
	# Step down on the horse's left side, facing the same way.
	var spot: Vector3 = _horse.global_transform * Vector3(-1.1, 0, 0.2)
	spot.y = _world.height_at(spot.x, spot.z)
	on_foot.global_position = spot
	on_foot.rotation.y = _horse.rotation.y
	_horse.set_rider_visible(false)
	_horse.let_go()
	_camera.follow(on_foot)
	_whistled = false
	_refresh()
	return true


## Get back on, if the horse is close enough.
func get_on() -> bool:
	if not on_foot:
		return false
	if _flat_distance() > MOUNT_REACH:
		_say("Walk up to %s first, or whistle" % Stable.horse_name(Stable.selected))
		return false
	_horse.take_back()
	_horse.set_rider_visible(true)
	_camera.follow(_horse)
	on_foot.queue_free()
	on_foot = null
	_refresh()
	return true


## Take the horse's head collar and lead it, or let go. Returns true if
## you're now leading it.
func toggle_lead() -> bool:
	if not on_foot:
		return false
	if on_foot.leading:
		on_foot.leading = null
		_horse.lead(null)
		_refresh()
		return false
	if _flat_distance() > MOUNT_REACH:
		_say("Walk up to %s first, or whistle" % Stable.horse_name(Stable.selected))
		return false
	on_foot.leading = _horse
	_horse.lead(on_foot)
	_refresh()
	return true


## Call the horse over.
func whistle() -> bool:
	if not on_foot or on_foot.leading:
		return false
	on_foot.waving = 1.2
	if _flat_distance() <= _horse.CALL_STOP + 0.3:
		_say("%s is right here!" % Stable.horse_name(Stable.selected))
		return false
	_horse.call_over(on_foot)
	_whistled = true
	_say("Fweet! Here, %s!" % Stable.horse_name(Stable.selected))
	return true


func _on_came_over() -> void:
	if not _whistled:
		return
	_whistled = false
	Stable.add_bond(Stable.selected, Stable.BOND_CALLED)
	_say("%s came to you!" % Stable.horse_name(Stable.selected))


func _on_trick_done(trick: String) -> void:
	Stable.add_bond(Stable.selected, Stable.BOND_TRICK)
	_say(["Well done, %s!", "Bravo, %s!", "Clever %s!"].pick_random() % Stable.horse_name(Stable.selected))


func _on_bond(index: int, new_heart: bool) -> void:
	if index != Stable.selected:
		return
	_refresh()
	if new_heart:
		var hearts: int = Stable.hearts(index)
		var text := "%s loves you a little more! %d hearts" % [Stable.horse_name(Stable.selected), hearts]
		for trick in Stable.TRICKS:
			if Stable.TRICKS[trick].hearts == hearts:
				text += "\nNew trick: %s!" % Stable.TRICKS[trick].name
		_say(text)


func _flat_distance() -> float:
	var a: Vector3 = on_foot.global_position
	var b: Vector3 = _horse.global_position
	return Vector2(a.x - b.x, a.z - b.z).length()


func _process(_delta: float) -> void:
	var halted: bool = absf(_horse.speed) < 0.3 and not _horse.jumping and _horse.is_on_floor()
	_trick_bar.visible = not on_foot and halted and _horse.trick == ""
	_foot_bar.visible = on_foot != null
	if on_foot:
		var near := _flat_distance() <= MOUNT_REACH
		_mount_button.disabled = not near
		_lead_button.disabled = not near and not on_foot.leading
		var lead_text := "Let go" if on_foot.leading else "Lead"
		_lead_button.text = lead_text if _touch else "%s  C" % lead_text
	if Engine.get_process_frames() % 10 == 0:
		_refresh()


func _refresh() -> void:
	var index: int = Stable.selected
	_name.text = Stable.horse_name(Stable.selected)
	_hearts.show_hearts(index)
	var mood: String = Stable.mood(index)
	if on_foot:
		if _horse.is_led():
			mood = "Walking with you"
		else:
			mood = "Coming over" if _horse.is_coming() else ("Grazing" if _horse.target_gait == 0 else "Strolling about")
	elif _horse.current_gait >= 3 and Stable.happiness(index) > 0.6:
		mood = "Loving the gallop!" if _horse.current_gait == 4 else "Enjoying the canter"
	_mood.text = mood
	for trick in _trick_buttons:
		var button: Button = _trick_buttons[trick]
		var known: bool = Stable.knows_trick(index, trick)
		button.modulate = Color.WHITE if known else Color(1, 1, 1, 0.55)
		button.tooltip_text = "" if known else "Learnt at %d hearts" % Stable.TRICKS[trick].hearts


func _say(text: String) -> void:
	if _hud and _hud.has_method("show_message"):
		_hud.show_message(text)


# --- On screen ------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# The horse's name, hearts and mood, under the coins.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.06, 0.12, 0.45)))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	panel.position = Vector2(20, 214)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	column.add_child(top)
	_name = _label(18)
	top.add_child(_name)
	_hearts = preload("res://scripts/hearts.gd").new()
	top.add_child(_hearts)
	_mood = _label(15)
	_mood.modulate = Color(1, 0.95, 0.85, 0.9)
	column.add_child(_mood)

	# Tricks and getting off, at a halt; whistling and getting on, on foot.
	_trick_bar = _bar(root)
	for trick in Stable.TRICKS:
		var key: String = OS.get_keycode_string(KEYS.find_key(trick))
		_trick_buttons[trick] = _button(_trick_bar, Stable.TRICKS[trick].name, key, do_trick.bind(trick))
	_button(_trick_bar, "Get off", "G", get_off)
	_foot_bar = _bar(root)
	_button(_foot_bar, "Whistle", "F", whistle)
	_lead_button = _button(_foot_bar, "Lead", "C", toggle_lead)
	_mount_button = _button(_foot_bar, "Get on", "G", get_on)
	_foot_bar.visible = false


func _bar(root: Control) -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	root.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.position.y -= 52
	return bar


func _button(bar: HBoxContainer, text: String, key: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text if _touch else "%s  %s" % [text, key]
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(96, 44)
	button.add_theme_font_size_override("font_size", 17)
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, _style(Color(1.0, 0.86, 0.92, 0.88) if state != "hover" else Color(1.0, 0.92, 0.95, 0.95)))
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, Color(0.35, 0.12, 0.25))
	button.add_theme_color_override("font_disabled_color", Color(0.35, 0.12, 0.25, 0.45))
	button.pressed.connect(func(): action.call())
	bar.add_child(button)
	return button


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(14)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
