extends Node3D
## The sounds of the outdoors while you ride: hoofbeats in time with the
## horse's legs (softer on grass, clopping on the trail, hushed in sand,
## splashing in water), its snorts and whinnies, the thump of landing a
## jump, and all around: wind, birdsong by day, crickets at night, rain
## when it rains and waves near the sea. Uses the Sound autoload's streams.

## When each hoof lands, as a fraction of the gait clip's stride (horse.gd
## GAIT_SET_FOR_GAIT picks the clip): four beats at a walk, two at a trot,
## three at a canter and four quick ones at a gallop.
const FOOTFALLS := [[0.0, 0.25, 0.5, 0.75], [0.0, 0.25, 0.5, 0.75], [0.05, 0.55], [0.0, 0.14, 0.28], [0.0, 0.09, 0.18, 0.3]]
const HOOF_DB := [-12.0, -12.0, -8.0, -5.0, -3.0]
const BIRDS := 5
const GULLS := 2

@export var horse_path: NodePath
@export var world_path: NodePath
@export var sky_path: NodePath

var _horse: Node
var _world: Node3D
var _sky: Node
var _loops := {}            ## Loop name -> AudioStreamPlayer
var _calls: Array[AudioStreamPlayer3D] = []
var _last_clip_pos := -1.0
var _was_jumping := false
var _was_gait := 0
var _was_coming := false
var _was_trick := ""
var _call_wait := 3.0
var _voice_wait := 30.0


func _ready() -> void:
	_horse = get_node(horse_path)
	_world = get_node(world_path)
	_sky = get_node_or_null(sky_path)
	for loop in ["wind", "rain", "waves", "crickets"]:
		var player := AudioStreamPlayer.new()
		player.bus = "Sounds"
		player.stream = Sound.stream(loop)
		player.volume_db = -60.0
		add_child(player)
		_loops[loop] = player
	for i in 3:
		var call := AudioStreamPlayer3D.new()
		call.bus = "Sounds"
		call.unit_size = 12.0
		call.max_distance = 80.0
		add_child(call)
		_calls.append(call)
	_horse.out_of_breath.connect(func(): Sound.play("snort", -4.0))
	# Bonding (bonding.gd): a happy nicker when the horse comes to your
	# whistle, a whinny when it rears.
	_horse.came_over.connect(func(): Sound.play("nicker", -2.0))
	_horse.trick_done.connect(func(trick): if trick == "spin": Sound.play("snort", -6.0))
	if DisplayServer.get_name() != "headless":
		for loop in _loops:
			_loops[loop].play()


func _process(delta: float) -> void:
	_hooves()
	_horse_voice(delta)
	_surroundings(delta)


func _hooves() -> void:
	var gait: int = _horse.current_gait
	if _horse.jumping:
		_was_jumping = true
		return
	if _was_jumping and _horse.is_on_floor():
		_was_jumping = false
		Sound.play("land", -2.0, randf_range(0.9, 1.1))
	if _horse._set_players.is_empty() or _horse._set_active < 0:
		return
	var player: AnimationPlayer = _horse._set_players[_horse._set_active]
	var length := player.current_animation_length
	if length <= 0.0 or gait == 0 or absf(_horse.speed) < 0.3:
		_last_clip_pos = -1.0
		return
	var now := player.current_animation_position / length
	if _last_clip_pos >= 0.0:
		for fall in FOOTFALLS[gait]:
			var crossed: bool = (_last_clip_pos < fall and now >= fall) or (now < _last_clip_pos and (fall > _last_clip_pos or fall <= now))
			if crossed:
				Sound.play("hoof_" + _surface(), HOOF_DB[gait] + randf_range(-1.5, 1.0), randf_range(0.92, 1.08), 3)
	_last_clip_pos = now


## What the horse is standing on.
func _surface() -> String:
	var p: Vector3 = _horse.global_position
	if _world.is_in_lake(p.x, p.z, -1.0):
		return "water"
	if _world.has_method("shore_distance"):
		var shore: float = _world.shore_distance(p.x, p.z)
		if shore < 0.5:
			return "water"
		if shore < _world.BEACH_WIDTH:
			return "sand"
	if _world.is_in_arena(p.x, p.z):
		return "sand"
	if _world.has_method("snow_at") and _world.snow_at(p.x, p.z) > 0.5:
		return "dirt" if _world.is_on_ice(p.x, p.z) else "snow"
	return "dirt" if _world.trail_at(p.x, p.z) > 0.4 else "grass"


## Now and then the horse snorts or whinnies; a snort when you set off.
func _horse_voice(delta: float) -> void:
	if _horse.is_coming() and not _was_coming:
		Sound.play("whistle", -3.0)
	_was_coming = _horse.is_coming()
	if _horse.trick != _was_trick and _horse.trick == "rear":
		Sound.play("whinny", -4.0, 1.0, 3)
	elif _horse.trick != _was_trick and _horse.trick == "bow":
		Sound.play("nicker", -4.0)
	_was_trick = _horse.trick
	var gait: int = _horse.current_gait
	if _was_gait == 0 and gait > 0 and randf() < 0.4:
		Sound.play("snort", -6.0, randf_range(0.9, 1.1))
	_was_gait = gait
	_voice_wait -= delta
	if _voice_wait <= 0.0:
		_voice_wait = randf_range(40.0, 90.0)
		if randf() < 0.6:
			Sound.play("whinny", -7.0, randf_range(0.95, 1.05), 3)
		else:
			Sound.play("snort", -6.0)


func _surroundings(delta: float) -> void:
	var day := 1.0
	var rain := 0.0
	if _sky:
		day = _sky.daylight()
		rain = _sky.rain
	var p: Vector3 = _horse.global_position
	var sea := 0.0
	if _world.has_method("shore_distance"):
		sea = 1.0 - smoothstep(12.0, 110.0, _world.shore_distance(p.x, p.z))
	# Up in the mountains the rain is snow (no patter), the wind blows
	# harder and the birds and crickets are quiet.
	var snowy: float = _world.snow_at(p.x, p.z) if _world.has_method("snow_at") else 0.0
	var wet := rain
	rain *= 1.0 - snowy
	day *= 1.0 - snowy * 0.85
	_fade("wind", -20.0 + maxf(rain, wet * snowy) * 6.0 + sea * 3.0 + snowy * 7.0, delta)
	_fade("rain", lerpf(-60.0, -6.0, sqrt(rain)), delta)
	_fade("waves", lerpf(-60.0, -3.0, sea) if sea > 0.0 else -60.0, delta)
	_fade("crickets", lerpf(-60.0, -16.0, (1.0 - day) * (1.0 - rain) * (1.0 - snowy)), delta)
	# Birdsong by day (gulls near the sea), less of it in the rain.
	_call_wait -= delta
	if _call_wait <= 0.0:
		_call_wait = randf_range(2.5, 7.0) / maxf(day * (1.0 - rain * 0.8), 0.15)
		if day > 0.3 and rain < 0.6:
			var call := _calls[randi() % _calls.size()]
			var a := randf() * TAU
			call.global_position = p + Vector3(cos(a), 0.0, sin(a)) * randf_range(10.0, 30.0) + Vector3.UP * randf_range(4.0, 10.0)
			var gull := sea > 0.5 and randf() < 0.7
			call.stream = Sound.stream("gull_%d" % randi_range(1, GULLS) if gull else "bird_%d" % randi_range(1, BIRDS))
			call.volume_db = randf_range(-8.0, -2.0)
			call.pitch_scale = randf_range(0.92, 1.1)
			call.play()


func _fade(loop: String, target_db: float, delta: float) -> void:
	var player: AudioStreamPlayer = _loops[loop]
	player.volume_db = move_toward(player.volume_db, target_db, delta * 20.0)
