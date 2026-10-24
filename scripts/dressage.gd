extends Node3D
## Dressage in the arena (competitions.gd runs it): the letter boards round
## the arena, and the test itself. A test is a list of movements: ride to a
## letter in a gait, and halt at X at the end. Each movement gets marks out
## of 10: up to 6 for staying in the right gait, 2 for riding right up to
## the letter and 2 for riding straight there without wandering. A happy,
## well-bonded horse earns a harmony bonus on top.

## The letters on the arena fence, as (x, z) offsets from the arena's
## middle; X is the middle itself. The rider is marked on the track, a few
## metres in from the fence.
const LETTERS := {
	"A": Vector2(0, 1), "K": Vector2(-1, 0.64), "E": Vector2(-1, 0), "H": Vector2(-1, -0.64),
	"C": Vector2(0, -1), "M": Vector2(1, -0.64), "B": Vector2(1, 0), "F": Vector2(1, 0.64),
	"X": Vector2(0, 0),
}
const TRACK_INSET := 3.0       ## The track runs this far inside the fence
const REACH := 3.0             ## Riding through this close to a letter counts as there
const GAIT_NAMES := ["Halt", "Walk", "Trot", "Canter", "Gallop"]
const HARMONY := 4.0           ## Bonus percent for a horse with full bond
## The tests, one for each cup: [letter, gait].
const TESTS := [
	[["X", 1], ["C", 2], ["M", 2], ["F", 2], ["A", 1], ["K", 1], ["E", 1], ["H", 2], ["C", 2], ["X", 0]],
	[["X", 2], ["C", 2], ["H", 2], ["E", 3], ["K", 3], ["A", 2], ["F", 2], ["B", 1], ["M", 1], ["C", 2], ["X", 0]],
	[["X", 2], ["C", 2], ["M", 3], ["B", 3], ["F", 3], ["A", 2], ["K", 2], ["E", 1], ["H", 1], ["C", 3], ["M", 3], ["B", 2], ["X", 0]],
]

var world: Node3D
var horse: CharacterBody3D

var _test: Array = []
var _step := 0
var _marks: Array[float] = []
var _moving := false          # Has this movement started (the horse moving)?
var _time := 0.0              # Seconds in this movement
var _in_gait := 0.0           # ...of which in the right gait
var _closest := INF
var _from := Vector2.ZERO
var _marker: Node3D
var _boards := {}             # Letter -> its board's material, lit up when it's next


func _ready() -> void:
	_build_letters()


## Where a letter is on the ground: on the track, or on the fence.
func letter_spot(letter: String, on_fence := false) -> Vector2:
	var middle := Vector2(world.arena_center.x, world.arena_center.z)
	var half: Vector2 = world.arena_size * 0.5
	if not on_fence:
		half -= Vector2.ONE * TRACK_INSET
	return middle + LETTERS[letter] * half


func start(cup: int) -> void:
	_test = TESTS[cup]
	_step = 0
	_marks.clear()
	_marker = _make_marker()
	add_child(_marker)
	# Line up at A, outside the arena, facing in.
	var a := letter_spot("A", true) + Vector2(0, 4)
	horse.global_position = Vector3(a.x, world.height_at(a.x, a.y) + 0.1, a.y)
	horse.rotation.y = 0.0
	horse.speed = 0.0
	horse.velocity = Vector3.ZERO
	horse.set_gait(0)
	horse.stand()
	_begin_movement()


func stop() -> void:
	if _marker:
		_marker.queue_free()
		_marker = null
	_light(-1)


func is_done() -> bool:
	return _step >= _test.size()


## Advance the test. Returns true when the last movement is done.
func step(delta: float) -> bool:
	if is_done():
		return true
	var at := Vector2(horse.global_position.x, horse.global_position.z)
	var movement: Array = _test[_step]
	var target := letter_spot(movement[0])
	var gait: int = movement[1]
	_marker.rotation.y += delta * 1.5
	if not _moving:
		if horse.speed < 0.1:
			return false
		_moving = true
	_time += delta
	if horse.current_gait == gait or (gait == 0 and horse.current_gait <= 1):
		_in_gait += delta
	var d := at.distance_to(target)
	_closest = minf(_closest, d)
	# A movement ends on riding past the letter's middle (or right over
	# it), or for a halt, on standing still in the ring.
	var there: bool = _closest < REACH and (d < 0.8 or d > _closest + 0.4) if gait != 0 \
		else d < REACH and horse.speed < 0.2
	if there:
		_marks.append(_mark(gait, target))
		_step += 1
		if is_done():
			stop()
			return true
		_begin_movement()
	return false


func _begin_movement() -> void:
	var movement: Array = _test[_step]
	var spot := letter_spot(movement[0])
	_marker.global_position = Vector3(spot.x, world.height_at(spot.x, spot.y), spot.y)
	_from = Vector2(horse.global_position.x, horse.global_position.z)
	_moving = _step > 0
	_time = 0.0
	_in_gait = 0.0
	_closest = INF
	_light(_step)


## Marks out of 10 for the movement just finished.
func _mark(gait: int, target: Vector2) -> float:
	var gait_part := 6.0 * clampf(_in_gait / maxf(_time, 0.01), 0.0, 1.0)
	if gait == 0:
		gait_part = 6.0   # Halted, or it wouldn't be finished
	var accuracy := 2.0 if _closest < 1.5 else (1.0 if _closest < 2.4 else 0.0)
	# Straight there: compare the time taken with riding straight at the gait.
	var speed: float = horse.GAITS[maxi(gait, 1)].speed
	var expected := _from.distance_to(target) / speed + 1.5
	var straight := 2.0 if _time < expected * 1.35 else (1.0 if _time < expected * 2.0 else 0.0)
	return snappedf(gait_part + accuracy + straight, 0.5)


## The score so far, as a percentage, with the harmony bonus.
func percent() -> float:
	if _marks.is_empty():
		return 0.0
	var total := 0.0
	for mark in _marks:
		total += mark
	return minf(total / (10.0 * _test.size()) * 100.0 + harmony(), 100.0)


func harmony() -> float:
	return HARMONY * Stable.bond[Stable.selected] / 100.0


## What to do now, for the status panel.
func instruction() -> String:
	if is_done():
		return "Test finished!"
	var movement: Array = _test[_step]
	var letter: String = movement[0]
	var gait: int = movement[1]
	var text := ("Halt at %s" % letter) if gait == 0 else ("%s to %s" % [GAIT_NAMES[gait], letter])
	if _step == 0:
		text = "Enter at A, " + text.to_lower()
	return "%d of %d: %s" % [_step + 1, _test.size(), text]


## Light up the next letter's board (or none, for -1).
func _light(step: int) -> void:
	var letter: String = _test[step][0] if step >= 0 and step < _test.size() else ""
	for key in _boards:
		var mat: StandardMaterial3D = _boards[key]
		mat.emission_energy_multiplier = 1.2 if key == letter else 0.0


# --- The letters and the marker ------------------------------------------------------

## White boards with big black letters on posts round the fence, like
## a real dressage arena. X is painted on the ground during a test instead.
func _build_letters() -> void:
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.96, 0.96, 0.94)
	var post := StandardMaterial3D.new()
	post.albedo_color = Color(0.9, 0.9, 0.88)
	for letter in LETTERS:
		if letter == "X":
			continue
		var spot := letter_spot(letter, true)
		var outward: Vector2 = LETTERS[letter]
		outward = Vector2(signf(outward.x), 0) if letter in ["K", "E", "H", "M", "B", "F"] else Vector2(0, signf(outward.y))
		spot -= outward * 0.7   # Just inside the fence, so the rails don't hide it
		var node := Node3D.new()
		node.name = "Letter" + letter
		add_child(node)
		node.global_position = Vector3(spot.x, world.height_at(spot.x, spot.y), spot.y)
		node.rotation.y = atan2(outward.x, outward.y) + PI   # Facing into the arena
		var stand := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.08, 0.9, 0.08)
		stand.mesh = box
		stand.material_override = post
		stand.position.y = 0.45
		node.add_child(stand)
		var board := MeshInstance3D.new()
		var face := BoxMesh.new()
		face.size = Vector3(0.85, 0.75, 0.06)
		board.mesh = face
		var lit := white.duplicate() as StandardMaterial3D
		lit.emission_enabled = true
		lit.emission = Color(1.0, 0.75, 0.9)
		lit.emission_energy_multiplier = 0.0
		board.material_override = lit
		board.position.y = 1.2
		node.add_child(board)
		_boards[letter] = lit
		for side in [[0.035, 0.0], [-0.035, PI]]:
			var label := Label3D.new()
			label.text = letter
			label.font_size = 112
			label.pixel_size = 0.0055
			label.modulate = Color(0.08, 0.08, 0.1)
			label.outline_size = 0
			label.position = Vector3(0, 1.2, side[0])
			label.rotation.y = side[1]
			node.add_child(label)


## A pink ring on the ground where the next movement ends, with a soft
## beam so it shows across the arena.
func _make_marker() -> Node3D:
	var node := Node3D.new()
	node.name = "DressageMarker"
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(1.0, 0.55, 0.85, 0.85)
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = REACH - 0.15
	torus.outer_radius = REACH
	torus.rings = 48
	ring.mesh = torus
	ring.material_override = glow
	ring.scale.y = 0.3
	ring.position.y = 0.06
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(ring)
	var dot := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.6
	disc.bottom_radius = 0.6
	disc.height = 0.02
	dot.mesh = disc
	dot.material_override = glow
	dot.position.y = 0.03
	node.add_child(dot)
	var beam_mat := glow.duplicate() as StandardMaterial3D
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.albedo_color = Color(1.0, 0.55, 0.85, 0.3)
	var beam := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.05
	tube.bottom_radius = 0.12
	tube.height = 6.0
	tube.radial_segments = 8
	beam.mesh = tube
	beam.material_override = beam_mat
	beam.position.y = 3.0
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(beam)
	return node
