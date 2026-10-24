extends Node3D
## Third-person camera that follows the horse and swings in behind it
## while riding. Drag (mouse or one finger on the open screen) to look
## around; scroll to zoom.

@export var target_path: NodePath
@export var height := 1.8
@export var distance_by_gait := [6.0, 6.5, 7.0, 8.0, 9.5]
@export var pitch_limits := Vector2(-55.0, 10.0)   ## Degrees
@export var follow_speed := 2.5

var _target: Node3D
var _yaw := 0.0
var _pitch := -18.0
var _zoom := 1.0
var _drag_index := -1
var _drag_idle := 0.0

@onready var _arm: SpringArm3D = $SpringArm3D


func _ready() -> void:
	_target = get_node(target_path)
	top_level = true
	_yaw = _target.rotation.y
	global_position = _target.global_position + Vector3.UP * height


## Follow someone else (you on foot, or back to the horse).
func follow(target: Node3D) -> void:
	_target = target


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom - 0.1, 0.5, 1.8)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom + 0.1, 0.5, 1.8)
	elif event is InputEventScreenTouch:
		# Touches on buttons and the joystick are handled by them first.
		if event.pressed and _drag_index == -1:
			_drag_index = event.index
		elif not event.pressed and event.index == _drag_index:
			_drag_index = -1
	elif event is InputEventScreenDrag and event.index == _drag_index:
		_look(event.relative)
	elif event is InputEventMouseMotion and event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT):
		if not DisplayServer.is_touchscreen_available():
			_look(event.relative)


func _look(relative: Vector2) -> void:
	_yaw -= relative.x * 0.006
	_pitch = clampf(_pitch - relative.y * 0.25, pitch_limits.x, pitch_limits.y)
	_drag_idle = 1.5


func _process(delta: float) -> void:
	var pos := _target.global_position + Vector3.UP * height
	global_position = global_position.lerp(pos, 1.0 - exp(-10.0 * delta))

	# Swing behind the horse while riding, unless the player just looked around.
	_drag_idle = maxf(0.0, _drag_idle - delta)
	var horse_speed: float = _target.get("speed")
	if _drag_idle == 0.0 and absf(horse_speed) > 0.5:
		_yaw = lerp_angle(_yaw, _target.rotation.y, 1.0 - exp(-follow_speed * delta))

	rotation = Vector3(deg_to_rad(_pitch), _yaw, 0)
	var gait: int = _target.get("current_gait")
	var wanted: float = distance_by_gait[gait] * _zoom
	_arm.spring_length = lerpf(_arm.spring_length, wanted, 1.0 - exp(-2.0 * delta))
