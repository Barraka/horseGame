extends Node3D
## You, off the horse: walk about with the same keys or joystick as for
## riding (forward, back, steer), wave when you whistle, and lead the horse
## by its head collar on a rope. Made by bonding.gd. Faces -Z like the
## horse, so the camera follows it the same way.

const WALK := 1.7       ## Metres a second
const TURN := 2.4       ## Radians a second
const ROPE_POINTS := 12
const ROPE_RADIUS := 0.012

var speed := 0.0         ## Read by the camera, like the horse's
var current_gait := 0
var waving := 0.0        ## Seconds left of the whistle wave
var world: Node3D
var rider: Node3D
var leading: Node3D      ## The horse being led, if any
var _rope: MeshInstance3D
var _lead := 0.0         # From 0 to 1 as the hand goes out to hold the rope
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
	_lead = move_toward(_lead, 1.0 if leading else 0.0, delta * 4.0)
	rider.walk_pose(_phase, _stride, clampf(waving * 2.0, 0.0, 1.0), _lead)
	_draw_rope()


## The lead rope, hanging in a loop from your right hand to the horse's chin.
func _draw_rope() -> void:
	if not leading or _lead < 1.0:
		if _rope:
			_rope.visible = false
		return
	if not _rope:
		_rope = MeshInstance3D.new()
		_rope.name = "LeadRope"
		_rope.mesh = ImmediateMesh.new()
		_rope.top_level = true
		_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.2, 0.32, 0.7)
		material.roughness = 0.8
		_rope.material_override = material
		add_child(_rope)
	_rope.visible = true
	var skeleton: Skeleton3D = rider.skeleton
	var hand := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("hand_r")).origin
	var ring: Vector3 = leading.lead_ring()
	var points: Array[Vector3] = []
	var sag := clampf(0.5 - hand.distance_to(ring) * 0.25, 0.05, 0.35)
	for i in ROPE_POINTS + 1:
		var t := float(i) / ROPE_POINTS
		points.append(hand.lerp(ring, t) + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0))
	var mesh := _rope.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in ROPE_POINTS:
		var along := (points[i + 1] - points[i]).normalized()
		var side := along.cross(Vector3.UP).normalized() * ROPE_RADIUS
		var up := side.cross(along).normalized() * ROPE_RADIUS
		var next_along := (points[mini(i + 2, ROPE_POINTS)] - points[i + 1]).normalized()
		var next_side := next_along.cross(Vector3.UP).normalized() * ROPE_RADIUS
		var next_up := next_side.cross(next_along).normalized() * ROPE_RADIUS
		var ring_a := [side, up, -side, -up]
		var ring_b := [next_side, next_up, -next_side, -next_up]
		for k in 4:
			var a: Vector3 = points[i] + ring_a[k]
			var b: Vector3 = points[i] + ring_a[(k + 1) % 4]
			var c: Vector3 = points[i + 1] + ring_b[k]
			var d: Vector3 = points[i + 1] + ring_b[(k + 1) % 4]
			var normal := ((ring_a[k] + ring_a[(k + 1) % 4]) as Vector3).normalized()
			for p in [a, c, b, b, c, d]:
				mesh.surface_set_normal(normal)
				mesh.surface_add_vertex(p)
	mesh.surface_end()
