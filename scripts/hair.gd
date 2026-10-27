extends Node3D
## The horse's mane, forelock and tail, as strands of hair (cards with a
## hair texture drawn by shaders/hair.gdshader) that swing as the horse
## moves. The horse model has no mane and only a thin tail of its own.
##
## Each strand is a short chain of points. Every frame horse.gd hands in the
## measured points on the neck, head and tail (tools/saddle_track.py and
## groom_track.py), each strand works out where it would rest, and its
## points spring towards that, lagging behind and swinging when the horse
## moves, turns, bounces or gallops. The strands then become one mesh.

const MANE_STRANDS := 56       ## Down the crest from the withers to the poll
const MANE_LENGTH := 0.24      ## At the middle of the neck, in metres
const FORELOCK_STRANDS := 5
const FORELOCK_LENGTH := 0.2
const TAIL_STRANDS := 24
const TAIL_LENGTH := 0.82
const POINTS := 6              ## Points down each strand
const STRAND_WIDTH := 0.05

## How the springs feel: stiff near the roots, loose at the tips.
const STIFFNESS := 120.0
const DAMPING := 9.0
const WIND := 0.25
const INERTIA := 0.6           ## How much the horse's speeding up and slowing down swings it

var color := Color(0.08, 0.06, 0.05)
var braided := false           ## Button or ribbon braids: no loose mane
var simple := false            ## Fewer strands (horses in the stalls)

var _mesh := ImmediateMesh.new()
var _instance := MeshInstance3D.new()
var _material := ShaderMaterial.new()
## Each strand: {"kind", "slot", "length", "width", "seed", "pos": [world], "vel": [world]}
var _strands: Array[Dictionary] = []
var _settled := 0.0            ## Seconds the hair has been still (stop redrawing)
var _time := 0.0
var _last_origin := Vector3.INF
var _last_velocity := Vector3.ZERO


func _ready() -> void:
	_material.shader = preload("res://shaders/hair.gdshader")
	_instance.mesh = _mesh
	_instance.material_override = _material
	_instance.extra_cull_margin = 2.0
	add_child(_instance)
	build()


## Make the strands (again), for the current colour and style.
func build() -> void:
	_material.set_shader_parameter("hair_color", color)
	_strands.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var mane := 0 if braided else (MANE_STRANDS / 2 if simple else MANE_STRANDS)
	for i in mane:
		# More of the mane falls to the right than the left.
		var side := -1.0 if i % 5 == 1 or i % 5 == 3 else 1.0
		var along := (i + rng.randf_range(-0.3, 0.3)) / maxf(mane - 1, 1)
		_add_strand("mane", clampf(along, 0.0, 1.0), side, rng)
	for i in (2 if simple else FORELOCK_STRANDS):
		_add_strand("forelock", float(i) / maxf(FORELOCK_STRANDS - 1, 1), 0.0, rng)
	var tail := TAIL_STRANDS / 2 if simple else TAIL_STRANDS
	for i in tail:
		_add_strand("tail", float(i) / tail, 0.0, rng)
	_last_origin = Vector3.INF
	_settled = 0.0


func _add_strand(kind: String, slot: float, side: float, rng: RandomNumberGenerator) -> void:
	var length: float
	var width := STRAND_WIDTH
	match kind:
		"mane":
			# Shorter up by the poll and at the withers.
			length = MANE_LENGTH * (0.55 + 0.6 * sin(PI * clampf(slot * 0.9 + 0.08, 0.0, 1.0))) * rng.randf_range(0.85, 1.1)
			width *= rng.randf_range(1.1, 1.5)
		"forelock":
			length = FORELOCK_LENGTH * rng.randf_range(0.8, 1.1)
			width *= 0.9
		"tail":
			length = TAIL_LENGTH * rng.randf_range(0.82, 1.05)
			width *= 1.35
	var pos: Array[Vector3] = []
	var vel: Array[Vector3] = []
	for k in POINTS:
		pos.append(Vector3.ZERO)
		vel.append(Vector3.ZERO)
	_strands.append({"kind": kind, "slot": slot, "side": side, "length": length, "width": width,
		"seed": rng.randf(), "pos": pos, "vel": vel})


## Move the hair along. `marks` are the measured points in this node's
## parent's space (horse.gd _hair_marks); `speed` how fast the horse goes.
## The hair moves in the horse's own space, so it doesn't trail behind just
## because the horse is moving; speeding up, slowing down, turning and the
## bounce of each stride swing it about.
func follow(marks: Dictionary, speed: float, delta: float) -> void:
	if _strands.is_empty() or delta <= 0.0:
		return
	_time += delta
	var to_world: Transform3D = (get_parent() as Node3D).global_transform
	var to_local := to_world.affine_inverse()
	var origin := to_world.origin
	var first := _last_origin == Vector3.INF
	# Big jumps (a new horse in the stable, the horse put back on the trail)
	# snap the hair to rest instead of flinging it about.
	if not first and origin.distance_to(_last_origin) > 3.0:
		first = true
	var velocity := Vector3.ZERO if first else (origin - _last_origin) / delta
	var shove := Vector3.ZERO
	if not first:
		shove = -(to_local.basis * ((velocity - _last_velocity) / delta)) * INERTIA
		shove = shove.limit_length(25.0)
	_last_origin = origin
	_last_velocity = velocity
	var back: Vector3 = to_world.basis * Vector3.BACK
	back = back.normalized()
	var blow := clampf(absf(speed) / 11.0, 0.0, 1.0)   # 1 at a full gallop

	var crest := _crest(marks)
	var moved := false
	for strand in _strands:
		var rest := _rest_shape(strand, marks, crest, to_world, back, blow)
		for k in rest.size():
			rest[k] = to_local * rest[k]
		moved = _spring(strand, rest, shove, delta, first) or moved
	if moved or first:
		_settled = 0.0
	else:
		_settled += delta
	if _settled < 0.5:
		_draw()


## The crest from the withers up to the poll, as points in the parent's space.
func _crest(marks: Dictionary) -> Array[Vector3]:
	# The mane starts a little behind the measured withers, where the neck
	# meets the back.
	var start: Vector3 = marks.withers + (marks.withers - marks.crest_0).normalized() * 0.09
	var crest: Array[Vector3] = [start, marks.withers]
	for i in 7:
		crest.append(marks["crest_%d" % i])
	crest.append(marks.crown.lerp(marks.crest_6, 0.35))
	return crest


## The point a fraction `t` of the way along the crest, and its direction.
func _along_crest(crest: Array[Vector3], t: float) -> Array[Vector3]:
	var length := 0.0
	for i in crest.size() - 1:
		length += crest[i].distance_to(crest[i + 1])
	return _along_line(crest, t * length)


## The point `distance` along a line of points, and the way the line runs
## there; past its end the line carries straight on.
func _along_line(line: Array[Vector3], distance: float) -> Array[Vector3]:
	for i in line.size() - 1:
		var piece := line[i + 1] - line[i]
		var length := piece.length()
		if distance <= length or i == line.size() - 2:
			var dir := piece / maxf(length, 0.0001)
			return [line[i] + dir * distance, dir]
		distance -= length
	return [line[0], Vector3.DOWN]


## Where a strand's points would be at rest, in world space.
func _rest_shape(strand: Dictionary, marks: Dictionary, crest: Array[Vector3], to_world: Transform3D, back: Vector3, blow: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var length: float = strand.length
	var step := length / (POINTS - 1)
	var sway := sin(_time * 1.7 + strand.seed * 9.0) * WIND * (0.4 + blow)
	match strand.kind:
		"mane":
			var at := _along_crest(crest, strand.slot)
			var root: Vector3 = to_world * at[0]
			var ahead: Vector3 = (to_world.basis * at[1]).normalized()
			var right: Vector3 = (to_world.basis * Vector3.RIGHT).normalized()
			var up := ahead.cross(right).normalized()
			if up.y < 0.0:
				up = -up
			right = up.cross(ahead).normalized() * (1.0 if strand.side >= 0.0 else -1.0)
			# The hair lies over the top of the neck and down its side. The
			# neck is narrow at the crest and widens below it (measured off
			# the model: about 6 cm out 4 cm down, 10 cm out 12 cm down),
			# and is a little wider towards the withers. Past the side the
			# hair hangs.
			var wide := lerpf(1.25, 1.0, strand.slot)
			var a := 0.115 * wide      # Out to the side
			var b := 0.13 * wide       # Down from the crest
			var angle := 0.0
			var p: Vector3 = root + up * 0.012 + right * 0.008 * (strand.seed - 0.5)
			points.append(p)
			for k in range(1, POINTS):
				var d := step
				var lift := 0.012 + 0.004 * k   # Lying on the hair underneath
				if angle < PI * 0.5:
					# Step round the ellipse by about one piece of the strand.
					var round_speed := Vector2(a * cos(angle), b * sin(angle)).length()
					angle = minf(angle + d / maxf(round_speed, 0.01), PI * 0.5)
					p = root + right * (a * sin(angle) + lift) - up * (b * (1.0 - cos(angle)) - lift * cos(angle))
				else:
					p += (Vector3.DOWN + right * 0.2).normalized() * d
				# In the wind of a canter or gallop the mane lifts and flies back.
				p += (back * 0.6 + up * 0.25) * blow * d * k * 0.5 + right * sway * 0.01 * k
				points.append(p)
		"forelock":
			var crown: Vector3 = to_world * marks.crown
			var nose: Vector3 = to_world * marks.nose
			var cheek: Vector3 = to_world * marks.cheek
			var face := (nose - cheek).normalized()
			var right: Vector3 = (to_world.basis * Vector3.RIGHT).normalized()
			var up := right.cross(face).normalized()
			if up.dot(Vector3.UP) < 0.0:
				up = -up
			# Between the ears, falling forward down the forehead.
			var across: float = (strand.slot - 0.5) * 0.06
			var p: Vector3 = crown + right * across + up * 0.02 + face * 0.01
			points.append(p)
			for k in range(1, POINTS):
				var bend := float(k) / (POINTS - 1)
				var dir := (face * (0.85 - bend * 0.3) - up * (0.15 + bend * 0.2) + right * across * 2.0).normalized()
				p += dir * step
				p += up * 0.012 * (1.0 - bend)   # Lying on the forehead, not in it
				p += -face * blow * step * 0.4 * bend + right * sway * 0.006 * k
				points.append(p)
		"tail":
			# Down the middle of the model's own tail (hidden by the coat
			# shader), which already swishes with each stride and streams out
			# at a gallop; strands longer than it carry on the way it points.
			var spine: Array[Vector3] = [to_world * marks.dock]
			for i in 6:
				spine.append(to_world * marks["tail_%d" % i])
			var right: Vector3 = (to_world.basis * Vector3.RIGHT).normalized()
			var a: float = strand.slot * TAU
			for k in POINTS:
				var bend := float(k) / (POINTS - 1)
				var at := _along_line(spine, strand.length * bend)
				var dir: Vector3 = at[1]
				var across := (right - dir * dir.dot(right)).normalized()
				var over := dir.cross(across).normalized()
				# Close round the root, fanning out towards the end.
				var spread := 0.03 + 0.05 * bend
				var p: Vector3 = at[0] + (across * cos(a) + over * sin(a) * 0.7) * spread
				p += across * sway * 0.012 * k
				points.append(p)
	return points


## Spring the strand's points (in the parent's space) towards their rest
## shape. True while moving.
func _spring(strand: Dictionary, rest: Array[Vector3], shove: Vector3, delta: float, snap: bool) -> bool:
	var pos: Array[Vector3] = strand.pos
	var vel: Array[Vector3] = strand.vel
	if snap:
		for k in POINTS:
			pos[k] = rest[k]
			vel[k] = Vector3.ZERO
		return true
	var moving := false
	var dt := minf(delta, 1.0 / 30.0)
	pos[0] = rest[0]
	var seg: float = strand.length / (POINTS - 1)
	for k in range(1, POINTS):
		var loose := float(k) / (POINTS - 1)
		var stiff := STIFFNESS * lerpf(1.0, 0.35, loose)
		var pull := (rest[k] - pos[k]) * stiff - vel[k] * DAMPING + shove * loose
		vel[k] += pull * dt
		pos[k] += vel[k] * dt
		# Keep each piece of the strand its own length.
		var link := pos[k] - pos[k - 1]
		var length := link.length()
		if length > 0.0001:
			pos[k] = pos[k - 1] + link * (seg / length)
		if vel[k].length_squared() > 0.0004 or pos[k].distance_squared_to(rest[k]) > 0.0001:
			moving = true
	return moving


## One mesh for all the strands: a ribbon down each, lying flat on the neck
## (or round the tail).
func _draw() -> void:
	var to_local := transform.affine_inverse()
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for strand in _strands:
		var pos: Array[Vector3] = strand.pos
		var width: float = strand.width
		var verts: Array[Vector3] = []
		var normals: Array[Vector3] = []
		var tangents: Array[Vector3] = []
		var tail: bool = strand.kind == "tail"
		for k in POINTS:
			var along := (pos[mini(k + 1, POINTS - 1)] - pos[maxi(k - 1, 0)]).normalized()
			var facing: Vector3
			if tail:
				# Round the tail, facing out from its middle.
				var a: float = strand.slot * TAU
				facing = Vector3.RIGHT * cos(a) + Vector3.UP * sin(a)
				facing = (facing - along * along.dot(facing)).normalized()
			elif strand.kind == "forelock":
				facing = Vector3.RIGHT.cross(along).normalized()   # Out of the forehead
			else:
				facing = Vector3.RIGHT * (1.0 if strand.side >= 0.0 else -1.0)
			var across := along.cross(facing).normalized()
			var t := float(k) / (POINTS - 1)
			var spread := width * (1.0 + 0.7 * t) if tail else width * (1.0 - 0.35 * t)
			verts.append(to_local * (pos[k] - across * spread * 0.5))
			verts.append(to_local * (pos[k] + across * spread * 0.5))
			var n := (to_local.basis * across.cross(along)).normalized()
			if n.dot(to_local.basis * facing) < 0.0:
				n = -n
			normals.append(n)
			tangents.append((to_local.basis * along).normalized())
		var seed: float = strand.seed
		for k in POINTS - 1:
			var v0 := float(k) / (POINTS - 1)
			var v1 := float(k + 1) / (POINTS - 1)
			var quad := [[k * 2, 0.0, v0], [k * 2 + 1, 1.0, v0], [k * 2 + 2, 0.0, v1], [k * 2 + 3, 1.0, v1]]
			for q in [0, 1, 2, 2, 1, 3]:
				var c: Array = quad[q]
				var row := int(c[0]) / 2
				_mesh.surface_set_normal(normals[row])
				_mesh.surface_set_tangent(Plane(tangents[row], 1.0))
				_mesh.surface_set_uv(Vector2(c[1], c[2]))
				_mesh.surface_set_uv2(Vector2(seed, 0.0))
				_mesh.surface_add_vertex(verts[c[0]])
	_mesh.surface_end()
