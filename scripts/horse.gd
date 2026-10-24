@tool
extends CharacterBody3D
## The player's horse: gaits, steering, jumping, and its look.
## The look comes from the first of these that exists: the gait set in
## gait_set_dir (one file per gait), a single model at model_path (with its
## animations), or a simple placeholder horse.

signal gait_changed(target_gait: int)
signal jump_refused
signal out_of_breath   ## Galloped too long: drops to a canter to get its breath back

const GAITS := [
	{"name": "Halt",   "speed": 0.0,  "accel": 0.0, "turn": 1.8, "jump": 0.0},
	{"name": "Walk",   "speed": 1.8,  "accel": 2.0, "turn": 1.8, "jump": 0.0},
	{"name": "Trot",   "speed": 3.6,  "accel": 3.0, "turn": 1.5, "jump": 4.4},
	{"name": "Canter", "speed": 7.0,  "accel": 3.5, "turn": 1.2, "jump": 5.2},
	{"name": "Gallop", "speed": 11.0, "accel": 4.0, "turn": 0.8, "jump": 5.6},
]
const GRAVITY := 14.0
## Training (Stable skill levels 1 to 10) makes the stable's horse better:
const SPEED_PER_LEVEL := 0.02          ## Canter and gallop 2% faster per level
const JUMP_PER_LEVEL := 0.025          ## Jumps 2.5% stronger per level
const GALLOP_SECONDS := 45.0           ## How long a level 1 horse can gallop...
const GALLOP_SECONDS_PER_LEVEL := 8.0  ## ...and how much longer for each stamina level
const REST_SECONDS := 12.0             ## Out of breath to fresh at a trot or slower; a canter takes twice as long
const CLICK_SLOP := 8.0                ## Pixels a click may move and still count as a click
const GALLOP_AGAIN := 0.25             ## Breath needed to start galloping again
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

## The gait set: one file per gait, all the same horse, animated with blend
## shapes rather than a skeleton. The files are used exactly as downloaded
## (their licence forbids edits), so these numbers, measured from them in the
## model's own units, line each one up:
## - yaw turns its head to face forward (-Z);
## - offset puts its saddle spot (see tools/saddle_track.py) on the horse's middle;
## - speed is how fast the hooves move the horse when played at normal speed;
## - root_motion marks a clip that travels forward through space (along its
##   X axis); it is cancelled out by pinning the saddle spot in place, so the
##   horse runs on the spot.
const GAIT_SET := [
	{"file": "horse_walk.glb", "yaw": 180.0, "offset": Vector3(0.09, 0.03, -0.76), "speed": 12.1, "root_motion": false},
	{"file": "horse_trot.glb", "yaw": 180.0, "offset": Vector3(0.01, 0.03, -0.82), "speed": 22.5, "root_motion": false},
	{"file": "horse_run.glb", "yaw": 90.0, "offset": Vector3(-1.24, -0.66, 0.0), "speed": 77.1, "root_motion": true},
]
const GAIT_SET_FOR_GAIT := [0, 0, 1, 2, 2]   ## Halt pauses the walk; canter is a slower gallop
const GAIT_SET_JUMP := 2                      ## Jumps hold the gallop's moment of flight...
const GAIT_SET_JUMP_TIME := 0.167             ## ...which is this far into the clip
const GAIT_SET_LENGTH := 24.6                 ## Nose to tail of the walk file, in model units
const SADDLE_HEIGHT := 0.07                   ## Rider's seat above the horse's back, in metres
const TACK_MARKS := ["nose", "muzzle", "cheek", "crown", "fl_low", "fl_high", "fr_low", "fr_high", "hl_low", "hl_high", "hr_low", "hr_high"]

@export_dir var gait_set_dir := "res://assets/horse/gaits"
@export var with_rider := true   ## Seat the player's rider on the gait set horse
@export var with_tack := true      ## Saddle and bridle the gait set horse
@export var tack: Dictionary = {}  ## Tack colours (see tack.gd), when not from the stable
@export var rider_look: Dictionary = {}   ## How the rider looks (rider.gd), when not the player's
@export_file("*.glb", "*.gltf") var model_path := "res://assets/horse/horse.glb"
@export var model_length := 2.6        ## Nose-to-tail length in metres
@export var model_yaw_offset := 0.0    ## Degrees; try 180 if the model rides backwards
@export var coat_color := Color(0.5, 0.26, 0.12)   ## Bay
@export var points_color := Color(0.08, 0.06, 0.05) ## Mane, tail and lower legs
@export_range(0.0, 1.0) var coat_strength := 1.0    ## 0 keeps the model's own painted coat
@export_enum("None", "Pinto", "Spotted", "Dappled") var coat_pattern := 0
@export var pattern_color := Color(0.95, 0.94, 0.92)
@export var pattern_seed := 0.0                     ## Moves the patches and spots around
@export_range(0.0, 1.0) var dirt := 0.0             ## Mud from riding; brushing cleans it
@export var body_shape := Vector3.ONE               ## Breed size and build (Stable.body_shape)

var target_gait := 0
var current_gait := 0
var speed := 0.0
var jumping := false
var energy := 1.0   ## Breath for galloping, from 0 to 1

var _visual: Node3D
var _body: Node3D    # The horse model, scaled to its breed; tack and rider stay unscaled
var _anim: AnimationPlayer
var _gait_anims: Array = []
var _clip_gait: Array = []   # Which gait each clip was animated for (sets its playback speed)
var _jump_anim := ""
var _placeholder: Dictionary = {}
var _set_models: Array[Node3D] = []
var _set_players: Array[AnimationPlayer] = []
var _set_scale := 1.0
var _set_active := -1
var _coat_material: ShaderMaterial
var _saddle_track: Dictionary = {}   # Where the back moves in each gait clip (tools/saddle_track.py)
var _saddle: Node3D                  # Saddle and rider, moved with the horse's back
var _rider: Node3D
var _tack: Node3D
var _rest_pitch := 0.0
var _phase := 0.0
var _ridden := 0.0   # Metres ridden since the stable was last told
var _click_from := Vector2.INF   # Where the mouse button went down
var _speed_points := 0.0     # Training earned since the stable was last told
var _stamina_points := 0.0


func _ready() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_body = Node3D.new()
	_body.name = "Body"
	_visual.add_child(_body)
	var stable := get_node_or_null("/root/Stable")
	if stable and not Engine.is_editor_hint():
		_read_coat(stable.current())
		body_shape = stable.body_shape(stable.selected)
		dirt = 1.0 - stable.care[stable.selected].clean
		tack = stable.tack[stable.selected]
	if ResourceLoader.exists(gait_set_dir.path_join(GAIT_SET[0].file)):
		_build_gait_set()
	elif ResourceLoader.exists(model_path):
		_build_from_model(load(model_path))
	else:
		_build_placeholder()
		# The blocky rider only suits the placeholder horse; a real rider
		# model comes with character creation.
		_build_rider()


func set_gait(index: int) -> void:
	target_gait = clampi(index, 0, GAITS.size() - 1)
	if target_gait == GAITS.size() - 1 and energy < GALLOP_AGAIN:
		target_gait -= 1
		out_of_breath.emit()
	gait_changed.emit(target_gait)


## The stable horse's level (1 to 10) in a skill; 1 when not from the stable.
func level(skill: String) -> int:
	var stable := get_node_or_null("/root/Stable")
	return stable.skill_level(stable.selected, skill) if stable else 1


## How fast a gait goes for this horse, with its speed training.
func top_speed(gait: int) -> float:
	var base: float = GAITS[gait].speed
	return base * (1.0 + SPEED_PER_LEVEL * (level("speed") - 1)) if gait >= 3 else base


## How long this horse can gallop from fresh, in seconds.
func gallop_seconds() -> float:
	return GALLOP_SECONDS + GALLOP_SECONDS_PER_LEVEL * (level("stamina") - 1)


## Change the coat colours (on the gait set horse).
func set_coat(body: Color, points: Color, strength := 1.0) -> void:
	coat_color = body
	points_color = points
	coat_strength = strength
	if _coat_material:
		_coat_material.set_shader_parameter("body_color", body)
		_coat_material.set_shader_parameter("points_color", points)
		_coat_material.set_shader_parameter("strength", strength)
		_coat_material.set_shader_parameter("pattern", coat_pattern)
		_coat_material.set_shader_parameter("pattern_color", pattern_color)
		_coat_material.set_shader_parameter("pattern_seed", pattern_seed)


## Give the horse the coat of one of the stable's horses (stable_data.gd HORSES).
func show_coat(horse: Dictionary) -> void:
	_read_coat(horse)
	set_coat(coat_color, points_color, coat_strength)


func _read_coat(horse: Dictionary) -> void:
	coat_color = horse.body
	points_color = horse.points
	coat_strength = horse.strength
	coat_pattern = horse.get("pattern", 0)
	pattern_color = horse.get("pattern_color", Color(0.95, 0.94, 0.92))
	pattern_seed = float(hash(horse.name) % 97)


## Draw the horse at a breed's size and build (or a foal's), as a scale in
## width, height and length. The tack follows the horse; the rider keeps
## their own size.
func set_body_shape(shape: Vector3) -> void:
	body_shape = shape
	if _body:
		_body.scale = shape
	if _saddle:
		_rest_pitch = _back_pitch(_back_points(0, 0.0))
		_follow_back()


## Show or hide the tack (foals don't wear any).
func set_tack_visible(on: bool) -> void:
	if _tack:
		_tack.set_shown(on)


## Dress the horse in tack of these colours (see tack.gd).
func set_tack(config: Dictionary) -> void:
	tack = config
	if _tack:
		_tack.build(config, _saddle)
		_follow_back()


## How muddy the horse looks, from 0 (spotless) to 1.
func set_dirt(amount: float) -> void:
	dirt = amount
	if _coat_material:
		_coat_material.set_shader_parameter("dirt", amount)
		_coat_material.set_shader_parameter("ground_y", global_position.y if is_inside_tree() else 0.0)


## Stand still in the halt pose, for when the horse isn't being ridden.
func stand() -> void:
	if not _set_models.is_empty():
		_show_gait_model(GAIT_SET_FOR_GAIT[0])
		_set_players[_set_active].seek(0.0, true)
		_set_players[_set_active].pause()
		_follow_back()


func jump() -> bool:
	if jumping or not is_on_floor():
		return false
	if GAITS[current_gait].jump <= 0.0:
		jump_refused.emit()
		return false
	velocity.y = GAITS[current_gait].jump * (1.0 + JUMP_PER_LEVEL * (level("jumping") - 1))
	jumping = true
	return true


## Height of the hooves above the ground under the horse.
func height_above_ground() -> float:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, global_position + Vector3.DOWN * 10.0)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	return global_position.y - hit.position.y if hit else 0.0


## A left click speeds up one gait and a right click slows down one, on
## PC. A click that turns into a drag (looking around) doesn't count, nor
## do taps on the tablet's screen or clicks on buttons.
func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if button.button_index != MOUSE_BUTTON_LEFT and button.button_index != MOUSE_BUTTON_RIGHT:
		return
	if button.pressed:
		_click_from = button.position
	elif button.position.distance_to(_click_from) < CLICK_SLOP and is_physics_processing():
		set_gait(target_gait + (1 if button.button_index == MOUSE_BUTTON_LEFT else -1))


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
	if Engine.is_editor_hint():
		return
	_read_buttons()
	var forward := Input.is_action_pressed("ride_forward")
	var back := Input.is_action_pressed("ride_back")
	var steer := Input.get_axis("steer_left", "steer_right")

	# Pressing forward at a halt starts a walk.
	if forward and target_gait == 0:
		set_gait(1)

	var gait: Dictionary = GAITS[target_gait]
	var top := top_speed(target_gait)
	if not is_on_floor():
		pass  # keep momentum in the air
	elif back:
		speed = move_toward(speed, -1.0, BRAKE * 2.0 * delta)
	elif speed < top:
		speed = move_toward(speed, top, gait.accel * (1.0 if forward else 0.6) * delta)
	else:
		speed = move_toward(speed, top, BRAKE * delta)

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
	var from := global_position
	move_and_slide()
	if jumping and is_on_floor() and velocity.y <= 0.0:
		jumping = false
		_landed()
	_breathe(delta)
	_wear(Vector2(global_position.x - from.x, global_position.z - from.z).length())

	_animate(delta)


## Galloping uses up breath; slower gaits get it back. Out of breath, the
## horse drops to a canter.
func _breathe(delta: float) -> void:
	if current_gait == GAITS.size() - 1 and is_on_floor():
		energy = maxf(energy - delta / gallop_seconds(), 0.0)
		if energy <= 0.0 and target_gait == GAITS.size() - 1:
			set_gait(target_gait - 1)   # Says it is out of breath
	elif current_gait < GAITS.size() - 1:
		var rest := REST_SECONDS * (2.0 if current_gait == 3 else 1.0)
		energy = minf(energy + delta / rest, 1.0)


func _landed() -> void:
	var stable := get_node_or_null("/root/Stable")
	if stable:
		stable.train(stable.selected, "jumping", stable.JUMP_POINTS)


## Riding makes the horse hungry and muddy, and trains it, a little at a time.
func _wear(metres: float) -> void:
	_ridden += metres
	if _coat_material:
		_coat_material.set_shader_parameter("ground_y", global_position.y)
	var stable := get_node_or_null("/root/Stable")
	if not stable:
		return
	_speed_points += metres * stable.SPEED_POINTS_PER_M[current_gait]
	_stamina_points += metres * stable.STAMINA_POINTS_PER_M
	if _ridden >= 25.0:
		stable.train(stable.selected, "speed", _speed_points, false)
		stable.train(stable.selected, "stamina", _stamina_points, false)
		_speed_points = 0.0
		_stamina_points = 0.0
		stable.ride(stable.selected, _ridden)   # Saves
		_ridden = 0.0
		set_dirt(1.0 - stable.care[stable.selected].clean)


func _animate(delta: float) -> void:
	var gait_speed: float = GAITS[current_gait].speed
	var ratio := speed / gait_speed if gait_speed > 0.0 else 1.0
	# Pitch the horse nose-up on take-off and nose-down on landing.
	var pitch := clampf(velocity.y * 0.05, -0.25, 0.25) if jumping else 0.0
	_visual.rotation.x = lerpf(_visual.rotation.x, pitch, 1.0 - exp(-8.0 * delta))
	if not _set_models.is_empty():
		_animate_gait_set(delta)
	elif _anim:
		if jumping and _jump_anim:
			if _anim.current_animation != _jump_anim:
				_anim.play(_jump_anim, 0.15)
			_anim.speed_scale = 1.0
			return
		var clip: String = _gait_anims[current_gait]
		if clip == "":
			_anim.pause()
			return
		if _anim.current_animation != clip or not _anim.is_playing():
			_anim.play(clip, 0.25)
		var native: float = GAITS[_clip_gait[current_gait]].speed
		_anim.speed_scale = clampf(absf(speed) / native, 0.5, 2.2) if native > 0.0 else 1.0
	elif not _placeholder.is_empty():
		_animate_placeholder(delta, ratio)


# --- Gait set ---------------------------------------------------------------

func _build_gait_set() -> void:
	_set_scale = model_length / GAIT_SET_LENGTH
	var file := FileAccess.open(gait_set_dir.path_join("saddle_track.json"), FileAccess.READ)
	_saddle_track = JSON.parse_string(file.get_as_text())
	for entry in GAIT_SET:
		var pivot := Node3D.new()
		pivot.scale = Vector3.ONE * _set_scale
		pivot.rotation.y = deg_to_rad(entry.yaw)
		_body.add_child(pivot)
		var model := (load(gait_set_dir.path_join(entry.file)) as PackedScene).instantiate() as Node3D
		model.position = entry.offset
		pivot.add_child(model)
		# Each file comes with a ground disc or plane under the horse.
		for node in model.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh and mi.mesh.get_blend_shape_count() == 0:
				mi.visible = false
			elif mi.mesh:
				mi.material_override = _coat(mi.mesh.surface_get_material(0))
				# A clip that travels moves its vertices far from the mesh's
				# bounds, which would get the horse culled as off screen.
				if entry.root_motion:
					mi.extra_cull_margin = 1000.0
		var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var clip := player.get_animation_list()[0]
		player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		player.assigned_animation = clip
		pivot.visible = false
		_set_models.append(model)
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_set_players.append(player)
	_body.scale = body_shape
	_show_gait_model(0)
	_build_saddle()


## All three files share one coat texture, so they share one coat material.
func _coat(original: Material) -> ShaderMaterial:
	if not _coat_material:
		_coat_material = ShaderMaterial.new()
		_coat_material.shader = preload("res://shaders/coat.gdshader")
		_coat_material.set_shader_parameter("albedo_texture", (original as BaseMaterial3D).albedo_texture)
		set_coat(coat_color, points_color, coat_strength)
		set_dirt(dirt)
	return _coat_material


func _show_gait_model(index: int) -> void:
	if index == _set_active:
		return
	# Carry the stride phase across so the switch is less of a jump.
	var phase := 0.0
	if _set_active >= 0:
		var old := _set_players[_set_active]
		phase = old.current_animation_position / old.current_animation_length
		old.stop()
		_set_models[_set_active].get_parent().visible = false
	_set_active = index
	var player := _set_players[index]
	_set_models[index].get_parent().visible = true
	player.play(player.assigned_animation)
	player.seek(phase * player.current_animation_length, true)


func _animate_gait_set(delta: float) -> void:
	var index: int = GAIT_SET_JUMP if jumping else GAIT_SET_FOR_GAIT[current_gait]
	_show_gait_model(index)
	var player := _set_players[index]
	var entry: Dictionary = GAIT_SET[index]
	if jumping:
		player.seek(GAIT_SET_JUMP_TIME, true)
		player.pause()
	elif current_gait == 0:
		player.pause()
	else:
		if not player.is_playing():
			player.play()
		var native: float = entry.speed * _set_scale
		player.speed_scale = clampf(absf(speed) / native, 0.5, 2.2)
		# Stepped here rather than on its own, so the saddle and the root
		# motion below follow the exact frame that gets drawn.
		player.advance(delta)
	var model := _set_models[index]
	if entry.root_motion:
		var travel := _track_point(index, "seat", player.current_animation_position).x - _track_point(index, "seat", 0.0).x
		model.position.x = entry.offset.x - travel
	_follow_back()


## The tack (scripts/tack.gd), with the player's rider in the saddle when
## with_rider is on. The horse has no bones to hang them on (it is animated
## with blend shapes), so _follow_back() moves them along with the measured
## points on its back, head and legs.
func _build_saddle() -> void:
	if not with_tack and not with_rider:
		return
	_saddle = Node3D.new()
	_saddle.name = "Saddle"
	_visual.add_child(_saddle)
	_tack = preload("res://scripts/tack.gd").new()
	_tack.name = "Tack"
	_visual.add_child(_tack)

	if with_rider:
		var rider_data := get_node_or_null("/root/RiderData")
		_rider = preload("res://scripts/rider.gd").new()
		_saddle.add_child(_rider)
		if not rider_look.is_empty():
			_rider.build(rider_look)
		else:
			_rider.build(rider_data.config if rider_data and not Engine.is_editor_hint() else {})
		_rider.set_pose("ride")
		_rider.rotation.y = PI   # The rider model faces +Z, the horse -Z
		_rider.position.y = SADDLE_HEIGHT - _rider.HIP_HEIGHT
		_tack.rider = _rider
	_tack.build(tack, _saddle)
	_rest_pitch = _back_pitch(_back_points(0, 0.0))
	_follow_back()


## Where a measured point on the horse (see tools/saddle_track.py) is in
## gait clip `index` at `time`, in the file's own space. Interpolated between
## keyframes the same way the animation is.
func _track_point(index: int, mark: String, time: float) -> Vector3:
	var track: Dictionary = _saddle_track[GAIT_SET[index].file]
	var times: Array = track.times
	var frame := times.size() - 1
	for i in times.size():
		if times[i] > time:
			frame = i
			break
	var prev := maxi(frame - 1, 0)
	var t := 0.0 if frame == prev else clampf((time - times[prev]) / (times[frame] - times[prev]), 0.0, 1.0)
	var a: Array = track[mark][prev]
	var b: Array = track[mark][frame]
	return Vector3(a[0], a[1], a[2]).lerp(Vector3(b[0], b[1], b[2]), t)


## The croup, seat and withers of gait clip `index` at `time`, in _visual's space.
func _back_points(index: int, time: float) -> Array[Vector3]:
	var model := _set_models[index]
	var to_visual: Transform3D = _body.transform * (model.get_parent() as Node3D).transform * model.transform
	var points: Array[Vector3] = []
	for mark in ["croup", "seat", "withers"]:
		points.append(to_visual * _track_point(index, mark, time))
	return points


func _back_pitch(points: Array[Vector3]) -> float:
	var along := points[2] - points[0]
	return atan2(along.y, Vector2(along.x, along.z).length())


func _follow_back() -> void:
	if not _saddle or _saddle_track.is_empty():
		return
	var player := _set_players[_set_active]
	var points := _back_points(_set_active, player.current_animation_position)
	_saddle.position = points[1]
	_saddle.rotation.x = _back_pitch(points) - _rest_pitch
	var track: Dictionary = _saddle_track[GAIT_SET[_set_active].file]
	var radii := {}
	for mark in TACK_MARKS:
		if track.has(mark + "_radius"):
			radii[mark] = track[mark + "_radius"] * _set_scale * (body_shape.x + body_shape.y) * 0.5
	_tack.follow(_tack_marks(), radii, _saddle.transform)


## Everything else the tack hangs on, in _visual's space, right now.
func _tack_marks() -> Dictionary:
	var model := _set_models[_set_active]
	var to_visual: Transform3D = _body.transform * (model.get_parent() as Node3D).transform * model.transform
	var time := _set_players[_set_active].current_animation_position
	var marks := {}
	for mark in TACK_MARKS:
		marks[mark] = to_visual * _track_point(_set_active, mark, time)
	return marks


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
		_clip_gait.append(_gait_anims.size() - 1)
	# A gait without its own clip borrows the nearest slower gait's clip,
	# played faster. With no idle clip the horse simply stands still.
	for g in range(1, GAITS.size()):
		if _gait_anims[g] == "":
			for src in range(g - 1, 0, -1):
				if _gait_anims[src] != "":
					_gait_anims[g] = _gait_anims[src]
					_clip_gait[g] = _clip_gait[src]
					break
	_jump_anim = _find_clip(names, JUMP_CLIPS)
	for clip in _gait_anims:
		if clip != "":
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
