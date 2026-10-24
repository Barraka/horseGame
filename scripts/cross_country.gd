extends Node3D
## The cross-country course (competitions.gd runs the competition): natural
## jumps along the trail from the arena east towards the Wild Horse Meadow:
## logs, hay bales, a brush hedge, a jump into a splash of water, a stone
## wall and more, each with a red flag on the right and a white one on the
## left. They stay out in the countryside, so you can practise any time.
##
## In the competition you jump them in order. A jump too low is a refusal
## (the horse stops: 20 penalties, try again), going past beside it is a
## run-out (20 penalties, turn round and jump it), and every second over
## the optimum time adds 0.4 penalties. Fewest penalties wins.

const Gate := preload("res://scripts/gate.gd")
const Rocks := preload("res://scripts/rocks.gd")
const START := Vector2(22, 12)    ## The course starts on the trail nearest here...
const METRES := 470.0             ## ...runs this far along it (away from Flower Valley)
const WIDTH := 5.0                ## Between the flags
const CLEARANCE := 0.3            ## Hooves tuck up this far below the horse
const REFUSAL := 20
const RUN_OUT := 20
const MISSED := 50                ## For a jump not jumped at all by the finish
const TIME_FAULT := 0.4           ## Penalties per second over the optimum time
const OPTIMUM_SPEED := [7.5, 8.6, 9.6]   ## m/s for the optimum time, by cup
const RUN_OUT_WIDTH := 16.0       ## Passing this close beside a jump is a run-out
## The jumps: metres along the course, kind and height.
const JUMPS := [
	[30.0, "log", 0.55], [70.0, "water", 0.5], [140.0, "bales", 0.65], [240.0, "hedge", 0.75],
	[290.0, "wall", 0.7], [335.0, "double", 0.7], [392.0, "round_bale", 0.8], [420.0, "log", 0.75],
	[446.0, "flowers", 0.8],
]
const POND_RADIUS := 6.0
const POND_AFTER := 7.0           ## The water starts this far after its jump

var world: Node3D
var horse: CharacterBody3D

var penalties := 0
var time := 0.0
var next := 0                     ## The jump to ride next
var _cup := 0
var _start := 0                   ## Trail point where the course starts
var _jumped: Array[bool] = []
var _last := Vector2.ZERO
var _flags: Array[Node3D] = []     ## Each jump's flags, which wave while it's next
var _gates: Array[Node3D] = []
var _clock := 0.0
var started := false               ## Through the START gate yet?


func _ready() -> void:
	var points: PackedVector2Array = world.trail_points
	for i in points.size():
		if points[i].distance_to(START) < points[_start].distance_to(START):
			_start = i
	for k in JUMPS.size():
		_build_jump(k)


## A point on the course `along` metres in (`side` metres to the right).
func spot(along: float, side := 0.0) -> Vector3:
	var p := _point(along) + _direction(along).orthogonal() * -side
	return Vector3(p.x, world.height_at(p.x, p.y), p.y)


func _point(along: float) -> Vector2:
	var points: PackedVector2Array = world.trail_points
	var i := _start - along   # The course runs backwards along the trail
	var a := points[wrapi(floori(i), 0, points.size())]
	var b := points[wrapi(floori(i) + 1, 0, points.size())]
	return a.lerp(b, i - floorf(i))


func _direction(along: float) -> Vector2:
	return (_point(along + 2.0) - _point(along - 2.0)).normalized()


## The yaw that faces a node (-Z forward) along the course.
func yaw(along: float) -> float:
	var dir := _direction(along)
	return atan2(-dir.x, -dir.y)


## Where the splash of water lies, as (x, z, radius).
func pond() -> Vector3:
	for jump in JUMPS:
		if jump[1] == "water":
			var p := _point(jump[0] + POND_AFTER + POND_RADIUS - 1.0)
			return Vector3(p.x, p.y, POND_RADIUS)
	return Vector3.ZERO


func optimum_time(cup: int) -> float:
	return METRES / OPTIMUM_SPEED[cup]


## Penalties for a round: jumping penalties plus time over the optimum.
func score(cup: int, seconds: float, jump_penalties: int) -> float:
	return jump_penalties + maxf(0.0, ceilf(seconds - optimum_time(cup))) * TIME_FAULT


func start(cup: int) -> void:
	_cup = cup
	penalties = 0
	time = 0.0
	next = 0
	_clock = 0.0
	started = false
	_jumped.clear()
	_jumped.resize(JUMPS.size())
	for g in [[0.0, "START", Color(0.2, 0.7, 0.3)], [METRES, "FINISH", Color(0.85, 0.2, 0.2)]]:
		var gate := Gate.new()
		gate.text = g[1]
		gate.color = g[2]
		gate.width = 8.0
		add_child(gate)
		gate.global_position = spot(g[0])
		gate.rotation.y = yaw(g[0])
		_gates.append(gate)
	var at := spot(-6.0)
	horse.global_position = at + Vector3.UP * 0.1
	horse.rotation.y = yaw(0.0)
	horse.speed = 0.0
	horse.velocity = Vector3.ZERO
	horse.energy = 1.0
	horse.set_gait(0)
	horse.stand()
	_last = Vector2(at.x, at.z)


func stop() -> void:
	for gate in _gates:
		gate.queue_free()
	_gates.clear()


## Ride on. Returns a message to show (a jump cleared, a refusal...), "done"
## at the finish, or "".
func step(delta: float) -> String:
	_clock += delta
	_wave_flags()
	var at := Vector2(horse.global_position.x, horse.global_position.z)
	var from := _last
	_last = at
	if not started:
		if _crossed(0.0, from, at, 4.0) != 0:
			return ""
		started = true
		return "Go!"
	time += delta
	if next < JUMPS.size():
		var jump: Array = JUMPS[next]
		var through := _crossed(jump[0], from, at, WIDTH * 0.5 + 0.4)
		if through == 0:
			var hooves: float = horse.height_above_ground()
			if hooves >= jump[2] - CLEARANCE:
				_jumped[next] = true
				next += 1
				Stable.train(Stable.selected, "jumping", Stable.CLEAR_FENCE_POINTS)
				return "Clear!" if next < JUMPS.size() else "Clear! Now gallop for the finish!"
			# Too low: the horse stops in front of it.
			penalties += REFUSAL
			var back := spot(jump[0] - 5.0)
			horse.global_position = back + Vector3.UP * 0.1
			horse.rotation.y = yaw(jump[0])
			horse.speed = 0.0
			_last = Vector2(back.x, back.z)
			return "Refusal! +%d\nJump just before the logs" % REFUSAL
		if through == 1:
			penalties += RUN_OUT
			return "Run-out! +%d\nTurn round and jump %d" % [RUN_OUT, next + 1]
	if _crossed(METRES, from, at, 8.0) == 0:
		for k in JUMPS.size():
			if not _jumped[k]:
				penalties += MISSED
		return "done"
	return ""


## Did the horse cross the course line at `along`, going forwards, between
## two frames? 0: through the gap, 1: beside it (a run-out), -1: no.
func _crossed(along: float, from: Vector2, to: Vector2, half_width: float) -> int:
	var middle := _point(along)
	var dir := _direction(along)
	if not ((from - middle).dot(dir) < 0.0 and (to - middle).dot(dir) >= 0.0):
		return -1
	var side := absf((to - middle).cross(dir))
	if side < half_width:
		return 0
	return 1 if side < RUN_OUT_WIDTH else -1


func status() -> String:
	var what := "Jump %d of %d" % [next + 1, JUMPS.size()] if next < JUMPS.size() else "Gallop to FINISH"
	return "%s   %.1f s (optimum %.0f s)   %d penalties" % [what, time, optimum_time(_cup), penalties]


func _wave_flags() -> void:
	for k in _flags.size():
		var flags := _flags[k]
		var live := k == next and _gates.size() > 0
		for flag in flags.get_children():
			if flag.has_meta("cloth"):
				flag.rotation.y = flag.get_meta("rest") + (sin(_clock * 6.0 + k) * 0.35 if live else 0.0)
				flag.scale = Vector3.ONE * (1.35 if live else 1.0)


# --- Building the jumps -------------------------------------------------------------

func _build_jump(k: int) -> void:
	var along: float = JUMPS[k][0]
	var kind: String = JUMPS[k][1]
	var height: float = JUMPS[k][2]
	var jump := Node3D.new()
	jump.name = "XCJump%d" % (k + 1)
	add_child(jump)
	jump.global_position = spot(along)
	jump.rotation.y = yaw(along)
	var wood := _material(Color(0.45, 0.31, 0.19))
	var pale := _material(Color(0.62, 0.48, 0.32))
	var half := WIDTH * 0.5 - 0.3
	match kind:
		"log", "water":
			_log(jump, Vector3(0, height - 0.22, 0), half * 2.0, 0.24, wood)
			for x in [-half + 0.4, half - 0.4]:
				for tilt in [-0.5, 0.5]:
					var leg := _log(jump, Vector3(x, 0.25, 0), 0.9, 0.08, pale)
					leg.rotation = Vector3(0, PI / 2, tilt)
			if kind == "water":
				_build_pond(jump, along)
		"double":
			for z in [-0.6, 0.6]:
				_log(jump, Vector3(0, height - 0.18 - (0.12 if z < 0.0 else 0.0), z), half * 2.0, 0.18, wood)
				_log(jump, Vector3(0, 0.15, z), half * 2.0, 0.14, pale)
		"bales":
			var straw := _material(Color(0.85, 0.72, 0.38))
			for x in 4:
				_add(jump, _box(Vector3(1.05, height * 0.55, 0.55)), straw, Vector3(-1.6 + x * 1.07, height * 0.275, 0))
			for x in 3:
				_add(jump, _box(Vector3(1.05, height * 0.45, 0.55)), straw, Vector3(-1.07 + x * 1.07, height * 0.55 + height * 0.225, 0))
		"hedge":
			var green := _material(Color(0.2, 0.42, 0.14))
			_add(jump, _box(Vector3(half * 2.0, 0.35, 0.9)), wood, Vector3(0, 0.175, 0))
			for x in 18:
				var tuft := _add(jump, _sphere(0.32), green, Vector3(-half + 0.15 + x * (half * 2.0 - 0.3) / 17.0, height - 0.2 + (x % 3) * 0.05, (x % 2) * 0.2 - 0.1))
				tuft.scale = Vector3(1.0, 1.3, 1.2)
		"wall":
			for row in 3:
				for x in 9:
					var shift := 0.27 if row % 2 == 1 else 0.0
					var stone := Rocks.grow(700 + row * 10 + x, Vector3(1.1, 0.7, 0.9), 0.18, 1)
					var mi := MeshInstance3D.new()
					mi.mesh = stone
					mi.scale = Vector3.ONE * 0.36
					mi.position = Vector3(-half + 0.25 + x * 0.55 + shift, 0.14 + row * height / 3.0, 0)
					if absf(mi.position.x) < half:
						jump.add_child(mi)
		"round_bale":
			var straw := _material(Color(0.8, 0.66, 0.33))
			var bale := _add(jump, _cylinder(height * 0.5, height * 0.5, half * 1.6, 20), straw, Vector3(0, height * 0.5, 0))
			bale.rotation.z = PI / 2
		"flowers":
			var box := _material(Color(0.95, 0.93, 0.88))
			_add(jump, _box(Vector3(half * 2.0, height * 0.6, 0.7)), box, Vector3(0, height * 0.3, 0))
			var colors := [Color(1.0, 0.4, 0.6), Color(1.0, 0.85, 0.3), Color(0.7, 0.5, 1.0), Color(1, 1, 1)]
			for x in 22:
				var bloom := _add(jump, _sphere(0.11), _material(colors[x % colors.size()], 0.6), Vector3(-half + 0.2 + x * (half * 2.0 - 0.4) / 21.0, height * 0.6 + 0.12 + (x % 2) * 0.06, (x % 3 - 1) * 0.18))
				bloom.scale.y = 0.8
			_add(jump, _box(Vector3(half * 2.0 - 0.1, 0.1, 0.6)), _material(Color(0.2, 0.45, 0.15)), Vector3(0, height * 0.6 + 0.04, 0))
	# Flags: red on the right, white on the left, and the number.
	var flags := Node3D.new()
	jump.add_child(flags)
	_flags.append(flags)
	for side in [[1.0, Color(0.9, 0.15, 0.12)], [-1.0, Color(0.97, 0.97, 0.95)]]:
		var x: float = side[0] * (WIDTH * 0.5 + 0.2)
		_add(flags, _cylinder(0.035, 0.04, 1.8, 6), _material(Color(0.95, 0.95, 0.95)), Vector3(x, 0.9, 0))
		var cloth := Node3D.new()
		cloth.position = Vector3(x, 1.6, 0)
		cloth.set_meta("cloth", true)
		cloth.set_meta("rest", 0.0)
		flags.add_child(cloth)
		var flag := _add(cloth, _box(Vector3(0.45, 0.3, 0.02)), _material(side[1], 0.7), Vector3(side[0] * 0.24, 0, 0))
		flag.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	var number := Label3D.new()
	number.text = str(k + 1)
	number.font_size = 64
	number.pixel_size = 0.006
	number.outline_size = 12
	number.position = Vector3(WIDTH * 0.5 + 0.2, 2.05, 0)
	number.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	flags.add_child(number)


## A splash of water after a log: the horse lands in it and splashes
## through (world.gd knows it's there, for the hoofbeats).
func _build_pond(jump: Node3D, along: float) -> void:
	var p := pond()
	var water := MeshInstance3D.new()
	water.name = "Splash"
	water.mesh = _cylinder(p.z, p.z, 0.02, 40)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/water.gdshader")
	mat.set_shader_parameter("centre", Vector2(p.x, p.y))
	mat.set_shader_parameter("radius", p.z)
	water.material_override = mat
	add_child(water)
	var ground: float = world.height_at(p.x, p.y)
	for a in 12:
		var edge := Vector2(p.x, p.y) + Vector2.from_angle(a * TAU / 12.0) * p.z
		ground = maxf(ground, world.height_at(edge.x, edge.y))
	water.global_position = Vector3(p.x, ground + 0.08, p.y)
	world.ponds.append(p)
	# Reeds round the edge, clear of the way through.
	var reed := _material(Color(0.35, 0.5, 0.2))
	for i in 26:
		var a := i * TAU / 26.0
		var edge := Vector2(p.x, p.y) + Vector2.from_angle(a) * (p.z + randf_range(-0.3, 0.5))
		var across := absf((edge - _point(along + POND_AFTER + p.z)).cross(_direction(along + POND_AFTER + p.z)))
		if across < 2.6:
			continue
		var stem := _add(self, _cylinder(0.015, 0.03, randf_range(0.7, 1.2), 4), reed, Vector3.ZERO)
		stem.global_position = Vector3(edge.x, world.height_at(edge.x, edge.y) + 0.45, edge.y)
		stem.rotation.z = randf_range(-0.15, 0.15)


func _log(parent: Node3D, pos: Vector3, length: float, radius: float, mat: Material) -> MeshInstance3D:
	var mi := _add(parent, _cylinder(radius, radius * 1.05, length, 10), mat, pos)
	mi.rotation.z = PI / 2
	return mi


func _material(color: Color, roughness := 0.85) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat


func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _box(size: Vector3) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	return box


func _cylinder(top: float, bottom: float, height: float, segments := 12) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	return mesh
