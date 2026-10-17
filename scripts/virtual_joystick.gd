extends Control
## On-screen joystick for tablets. Push up to ride on, down to slow down
## and back up, sideways to steer. Presses the same actions as the keyboard.

@export var radius := 110.0
@export var dead_zone := 0.2

var _touch_index := -1
var _value := Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2.ONE * radius * 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1 and get_global_rect().has_point(event.position):
			_touch_index = event.index
			_update(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_update_value(Vector2.ZERO)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update(event.position)
		get_viewport().set_input_as_handled()


func _update(touch_pos: Vector2) -> void:
	var center := global_position + size * 0.5
	_update_value(((touch_pos - center) / radius).limit_length(1.0))


func _update_value(value: Vector2) -> void:
	_value = value
	_set_action("steer_left", -value.x)
	_set_action("steer_right", value.x)
	_set_action("ride_forward", 1.0 if value.y < -0.3 else 0.0)
	_set_action("ride_back", 1.0 if value.y > 0.5 else 0.0)
	queue_redraw()


func _set_action(action: String, strength: float) -> void:
	if strength > dead_zone:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, radius, Color(1, 1, 1, 0.16))
	draw_arc(center, radius, 0, TAU, 48, Color(1, 1, 1, 0.5), 3.0, true)
	draw_circle(center + _value * radius * 0.6, radius * 0.38, Color(1, 1, 1, 0.75))
