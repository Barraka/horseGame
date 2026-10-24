extends Node3D
## You, off the horse: walk about with the same keys or joystick as for
## riding (forward, back, steer), and wave when you whistle. Made by
## bonding.gd. Faces -Z like the horse, so the camera follows it the same way.

const WALK := 1.7       ## Metres a second
const TURN := 2.4       ## Radians a second

var speed := 0.0         ## Read by the camera, like the horse's
var current_gait := 0
var waving := 0.0        ## Seconds left of the whistle wave
var world: Node3D
var rider: Node3D
var _phase := 0.0
var _stride := 0.0


func setup(owner_world: Node3D, look: Dictionary) -> void:
	world = owner_world
	rider = preload("res://scripts/rider.gd").new()
	add_child(rider)
	rider.build(look)
	rider.rotation.y = PI   # The model faces +Z
	rider.set_pose("stand")


func _process(delta: float) -> void:
	var forward := Input.get_axis("ride_back", "ride_forward")
	var steer := Input.get_axis("steer_left", "steer_right")
	rotation.y -= steer * TURN * delta
	speed = move_toward(speed, forward * WALK * (0.6 if forward < 0.0 else 1.0), 6.0 * delta)
	var step := -global_basis.z * speed * delta
	var next := global_position + step
	if world and world.has_method("height_at"):
		var edge: float = world.size * 0.5 - 6.0
		next.x = clampf(next.x, -edge, edge)
		next.z = clampf(next.z, -edge, edge)
		next.y = world.height_at(next.x, next.z)
	global_position = next
	waving = maxf(waving - delta, 0.0)
	var moving := absf(speed) > 0.05 or absf(steer) > 0.1
	_stride = move_toward(_stride, 1.0 if moving else 0.0, delta * 4.0)
	if moving:
		_phase = fmod(_phase + delta * (5.5 if absf(speed) > 0.05 else 3.5), TAU)
	rider.walk_pose(_phase, _stride, clampf(waving * 2.0, 0.0, 1.0))
