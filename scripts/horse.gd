extends CharacterBody3D
## The player's horse: gaits, steering, jumping, and its look.
## If a horse model exists at model_path it is used (with its animations);
## otherwise a simple placeholder horse is built.

signal gait_changed(target_gait: int)
signal jump_refused

const GAITS := [
	{"name": "Halt",   "speed": 0.0,  "accel": 0.0, "turn": 1.8, "jump": 0.0},
	{"name": "Walk",   "speed": 2.2,  "accel": 2.0, "turn": 1.8, "jump": 0.0},
	{"name": "Trot",   "speed": 4.5,  "accel": 3.0, "turn": 1.5, "jump": 4.4},
	{"name": "Canter", "speed": 7.5,  "accel": 3.5, "turn": 1.2, "jump": 5.2},
	{"name": "Gallop", "speed": 12.0, "accel": 4.0, "turn": 0.8, "jump": 5.6},
]
const GRAVITY := 14.0
const BRAKE := 4.0

## Animation clips are matched by keyword, so most horse packs work as-is.
const GAIT_CLIPS := [
	["idle", "eat", "stand"],
	["walk"],
	["trot", "walk"],
	["canter", "gallop", "run"],
	["gallop", "run", "canter"],
]
const JUMP_CLIPS := ["jump"]

@export_file("*.glb", "*.gltf") var model_path := "res://assets/horse/horse.glb"
@export var model_length := 2.6        ## Nose-to-tail length in metres
@export var model_yaw_offset := 0.0    ## Degrees; try 180 if the model rides backwards
@export var coat_color := Color(0.5, 0.26, 0.12)   ## Bay
@export var points_color := Color(0.08, 0.06, 0.05) ## Mane, tail and lower legs

var target_gait := 0
var current_gait := 0
var speed := 0.0
var jumping := false

var _visual: Node3D
var _anim: AnimationPlayer
var _gait_anims: Array = []
var _jump_anim := ""
var _placeholder: Dictionary = {}
var _phase := 0.0


func _ready() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	if ResourceLoader.exists(model_path):
		_build_from_model(load(model_path))
	else:
		_build_placeholder()
	_build_rider()


func set_gait(index: int) -> void:
	target_gait = clampi(index, 0, GAITS.size() - 1)
	gait_changed.emit(target_gait)


func jump() -> bool:
	if jumping or not is_on_floor():
		return false
	if GAITS[current_gait].jump <= 0.0:
		jump_refused.emit()
		return false
	velocity.y = GAITS[current_gait].jump
	jumping = true
	return true


## Height of the hooves above the ground under the horse.
func height_above_ground() -> float:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, global_position + Vector3.DOWN * 10.0)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	return global_position.y - hit.position.y if hit else 0.0


func _read_buttons() -> void:
	# Polled (not event-based) so on-screen touch buttons work the same as keys.
	for i in GAITS.size():
		if Input.is_action_just_pressed("gait_%d" % i):
			set_gait(i)
	if Input.is_action_just_pressed("gait_up"):
		set_gait(target_gait + 1)
	if Input.is_action_just_pressed("gait_down"):
		set_gait(target_gait - 1)
	if Input.is_action_just_pressed("jump"):
		jump()


func _physics_process(delta: float) -> void:
	_read_buttons()
	var forward := Input.is_action_pressed("ride_forward")
	var back := Input.is_action_pressed("ride_back")
	var steer := Input.get_axis("steer_left", "steer_right")

	# Pressing forward at a halt starts a walk.
	if forward and target_gait == 0:
		set_gait(1)

	var gait: Dictionary = GAITS[target_gait]
	if not is_on_floor():
		pass  # keep momentum in the air
	elif back:
		speed = move_toward(speed, -1.0, BRAKE * 2.0 * delta)
	elif speed < gait.speed:
		speed = move_toward(speed, gait.speed, gait.accel * (1.0 if forward else 0.6) * delta)
	else:
		speed = move_toward(speed, gait.speed, BRAKE * delta)

	# The gait the horse is actually moving in follows its speed.
	current_gait = 0
	for i in range(GAITS.size() - 1, 0, -1):
		if speed >= (GAITS[i - 1].speed + GAITS[i].speed) * 0.5:
			current_gait = i
			break

	if is_on_floor():
		var turn: float = GAITS[current_gait].turn
		rotation.y -= steer * turn * delta

	var dir := -global_transform.basis.z
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if is_on_floor() and not jumping:
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if jumping and is_on_floor() and velocity.y <= 0.0:
		jumping = false

	_animate(delta)


func _animate(delta: float) -> void:
	var gait_speed: float = GAITS[current_gait].speed
	var ratio := speed / gait_speed if gait_speed > 0.0 else 1.0
	if _anim:
		var clip: String = _jump_anim if jumping and _jump_anim else _gait_anims[current_gait]
		if clip and _anim.current_animation != clip:
			_anim.play(clip, 0.25)
		_anim.speed_scale = clampf(ratio, 0.6, 1.4) if current_gait > 0 and not jumping else 1.0
	elif not _placeholder.is_empty():
		_animate_placeholder(delta, ratio)


# --- Real model -------------------------------------------------------------

func _build_from_model(scene: PackedScene) -> void:
	var model := scene.instantiate() as Node3D
	_visual.add_child(model)

	var box := _visual_bounds(model)
	var scale_factor := model_length / maxf(box.size.x, box.size.z)
	model.scale = Vector3.ONE * scale_factor
	model.rotation.y = deg_to_rad(model_yaw_offset)
	model.position.y = -box.position.y * scale_factor

	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not _anim:
		return
	var names := _anim.get_animation_list()
	for keywords in GAIT_CLIPS:
		_gait_anims.append(_find_clip(names, keywords))
	_jump_anim = _find_clip(names, JUMP_CLIPS)
	for clip in _gait_anims:
		if clip:
			_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	print("Horse model animations: ", names)


func _find_clip(names: PackedStringArray, keywords: Array) -> String:
	for keyword in keywords:
		for clip_name in names:
			if keyword in clip_name.to_lower():
				return clip_name
	return ""


func _visual_bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for node in root.find_children("*", "VisualInstance3D", true, false):
		var vi := node as VisualInstance3D
		var aabb := root.global_transform.affine_inverse() * vi.global_transform * vi.get_aabb()
		box = aabb if first else box.merge(aabb)
		first = false
	return box


# --- Placeholder horse --------------------------------------------------------

func _part(mesh: Mesh, mat: Material, parent: Node3D, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 12
	m.rings = 4
	return m


func _build_placeholder() -> void:
	# A glossy coat with a soft rim of light, like a groomed horse.
	var coat := StandardMaterial3D.new()
	coat.albedo_color = coat_color
	coat.roughness = 0.38
	coat.rim_enabled = true
	coat.rim = 0.35
	coat.rim_tint = 0.6
	var dark := StandardMaterial3D.new()
	dark.albedo_color = points_color
	dark.roughness = 0.5

	# The horse faces -Z (Godot's forward).
	var body := Node3D.new()
	body.position.y = 1.35
	_visual.add_child(body)
	_part(_capsule(0.42, 1.9), coat, body, Vector3.ZERO, Vector3(PI / 2, 0, 0))

	var neck := Node3D.new()
	neck.position = Vector3(0, 0.2, -0.75)
	neck.rotation.x = 0.75
	body.add_child(neck)
	_part(_capsule(0.25, 1.0), coat, neck, Vector3(0, 0.0, -0.35), Vector3(PI / 2, 0, 0))
	var mane := BoxMesh.new()
	mane.size = Vector3(0.08, 0.14, 0.9)
	_part(mane, dark, neck, Vector3(0, 0.2, -0.35))
	var head := _part(_capsule(0.19, 0.8), coat, neck, Vector3(0, -0.1, -0.95), Vector3(PI / 2 - 0.9, 0, 0))
	var ear := CylinderMesh.new()
	ear.top_radius = 0.0
	ear.bottom_radius = 0.05
	ear.height = 0.16
	for x in [-0.08, 0.08]:
		_part(ear, coat, head, Vector3(x, -0.25, -0.15), Vector3(-0.6, 0, 0))

	var tail := Node3D.new()
	tail.position = Vector3(0, 0.25, 0.95)
	body.add_child(tail)
	_part(_capsule(0.1, 0.95), dark, tail, Vector3(0, -0.42, 0.18), Vector3(-0.4, 0, 0))

	var legs: Array[Node3D] = []
	var upper_leg := _capsule(0.1, 0.6)
	var lower_leg := _capsule(0.075, 0.6)
	var hoof := CylinderMesh.new()
	hoof.top_radius = 0.09
	hoof.bottom_radius = 0.11
	hoof.height = 0.12
	for p in [Vector2(-0.2, -0.65), Vector2(0.2, -0.65), Vector2(-0.2, 0.65), Vector2(0.2, 0.65)]:
		var pivot := Node3D.new()
		pivot.position = Vector3(p.x, -0.25, p.y)
		body.add_child(pivot)
		_part(upper_leg, coat, pivot, Vector3(0, -0.28, 0))
		_part(lower_leg, dark, pivot, Vector3(0, -0.72, 0))
		_part(hoof, dark, pivot, Vector3(0, -1.04, 0))
		legs.append(pivot)

	_placeholder = {"body": body, "neck": neck, "tail": tail, "legs": legs}


# Leg phase offsets per gait (front-left, front-right, back-left, back-right).
const LEG_PATTERN := [
	[0.0, 0.0, 0.0, 0.0],
	[0.0, PI, PI * 1.5, PI * 0.5],
	[0.0, PI, PI, 0.0],
	[0.0, 0.6, PI, PI + 0.6],
	[0.0, 0.4, PI, PI + 0.4],
]
const LEG_SWING := [0.0, 0.3, 0.45, 0.6, 0.75]
const STRIDE_RATE := [0.0, 5.0, 8.0, 9.0, 11.0]


func _animate_placeholder(delta: float, ratio: float) -> void:
	var legs: Array[Node3D] = _placeholder.legs
	var neck: Node3D = _placeholder.neck
	var body: Node3D = _placeholder.body
	var tail: Node3D = _placeholder.tail
	var w := 1.0 - exp(-12.0 * delta)
	if jumping:
		# Tuck the legs over the fence.
		for i in legs.size():
			legs[i].rotation.x = lerpf(legs[i].rotation.x, 1.1 if i < 2 else -0.9, w)
		neck.rotation.x = lerpf(neck.rotation.x, 0.4, w)
		return
	_phase += STRIDE_RATE[current_gait] * maxf(0.5, ratio) * delta
	for i in legs.size():
		var target: float = sin(_phase + LEG_PATTERN[current_gait][i]) * LEG_SWING[current_gait]
		legs[i].rotation.x = lerpf(legs[i].rotation.x, target, w)
	neck.rotation.x = lerpf(neck.rotation.x, 0.75 + current_gait * 0.06, w * 0.3)
	body.position.y = 1.35 + absf(sin(_phase)) * 0.025 * current_gait
	tail.rotation.x = -0.15 * current_gait + sin(_phase * 0.5) * 0.08


# --- Rider (placeholder until character creation exists) ---------------------

func _build_rider() -> void:
	var height := 1.78
	if _anim or _placeholder.is_empty():
		height = _visual_bounds(_visual).end.y * 0.62
	var shirt := StandardMaterial3D.new()
	shirt.albedo_color = Color(0.25, 0.45, 0.8)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.96, 0.8, 0.68)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.12, 0.16)
	var cream := StandardMaterial3D.new()
	cream.albedo_color = Color(0.92, 0.9, 0.84)

	var rider := Node3D.new()
	rider.name = "Rider"
	rider.position = Vector3(0, height, 0.05)
	_visual.add_child(rider)
	_part(_capsule(0.19, 0.7), shirt, rider, Vector3(0, 0.42, 0))
	var head := SphereMesh.new()
	head.radius = 0.14
	head.height = 0.28
	_part(head, skin, rider, Vector3(0, 0.9, 0))
	var helmet := SphereMesh.new()
	helmet.radius = 0.16
	helmet.height = 0.16
	helmet.is_hemisphere = true
	_part(helmet, dark, rider, Vector3(0, 0.93, 0))
	for x in [-0.3, 0.3]:
		_part(_capsule(0.08, 0.7), cream, rider, Vector3(x, 0.05, -0.05), Vector3(0.3, 0, 0))
		_part(_capsule(0.06, 0.55), shirt, rider, Vector3(x * 0.8, 0.45, -0.18), Vector3(1.1, 0, 0))
