extends SubViewportContainer
## A picture of a person's face for dialogs and results windows: their
## rider.gd model, standing in a little world of its own, seen up close.

const Rider := preload("res://scripts/rider.gd")

var _viewport: SubViewport
var _camera: Camera3D
var _rider: Node3D


func _init() -> void:
	stretch = true
	custom_minimum_size = Vector2(150, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, 30, 0)
	light.light_energy = 1.2
	_viewport.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1.0, 0.95, 0.9)
	env.environment.ambient_light_energy = 0.7
	_viewport.add_child(env)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_viewport.add_child(_camera)


## Show this person (a rider.gd look).
func show_person(look: Dictionary) -> void:
	if _rider:
		_rider.queue_free()
	_rider = Rider.new()
	_viewport.add_child(_rider)
	_rider.build(look)
	_rider.set_pose("stand")
	_rider.rotation.y = 0.35   # Turned a little, facing the camera (+Z)
	# Frame the head, whatever the body's height.
	var head := Vector3(0, 1.6, 0)
	var bone: int = _rider.skeleton.find_bone("Head") if _rider.skeleton else -1
	if bone >= 0:
		head = _rider.skeleton.global_transform * _rider.skeleton.get_bone_global_pose(bone).origin
	var target := head + Vector3.UP * 0.12
	_camera.position = target + Vector3(0, 0.02, 1.25)
	_camera.look_at(target)
