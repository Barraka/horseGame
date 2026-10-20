extends SceneTree
## Checks the riding controls: U J H L (and the arrows) ride and steer, a
## left click is one gait faster and a right click one gait slower, while a
## drag to look around, or a tap on the tablet's screen, changes nothing.
## Run with: godot --headless --path . -s tests/controls_test.gd

var main: Node
var frames := 0
var ok := true


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(what: String, passed: bool) -> void:
	print("%s: %s" % [what, "ok" if passed else "FAILED"])
	ok = ok and passed


func _has_key(action: String, key: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == key:
			return true
	return false


func _click(horse: Node, button: MouseButton, from: Vector2, to: Vector2, device := 0) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.position = from if pressed else to
		event.device = device
		horse._unhandled_input(event)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 3:
		return false
	var horse: Node = main.get_node("Horse")
	_check("U rides on", _has_key("ride_forward", KEY_U) and _has_key("ride_forward", KEY_UP))
	_check("J slows down", _has_key("ride_back", KEY_J))
	_check("H steers left", _has_key("steer_left", KEY_H))
	_check("L steers right", _has_key("steer_right", KEY_L))
	_check("W A S D are free", not _has_key("ride_forward", KEY_W) and not _has_key("steer_left", KEY_A))

	horse.set_gait(1)
	_click(horse, MOUSE_BUTTON_LEFT, Vector2(400, 300), Vector2(401, 301))
	_check("Left click: walk to trot", horse.target_gait == 2)
	_click(horse, MOUSE_BUTTON_LEFT, Vector2(400, 300), Vector2(400, 300))
	_check("Left click again: canter", horse.target_gait == 3)
	_click(horse, MOUSE_BUTTON_RIGHT, Vector2(400, 300), Vector2(400, 300))
	_check("Right click: back to trot", horse.target_gait == 2)
	_click(horse, MOUSE_BUTTON_LEFT, Vector2(400, 300), Vector2(520, 330))
	_check("Dragging to look around doesn't change gait", horse.target_gait == 2)
	_click(horse, MOUSE_BUTTON_LEFT, Vector2(400, 300), Vector2(400, 300), InputEvent.DEVICE_ID_EMULATION)
	_check("A tap on the tablet doesn't change gait", horse.target_gait == 2)
	print("RESULT: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
	return true
