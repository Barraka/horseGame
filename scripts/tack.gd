extends Node3D
## A horse's tack: saddle pad, saddle with stirrups, bridle with reins, and
## leg wraps, in the colours chosen in the stable. Also the grooming salon's
## braids and ribbons; its markings and glitter are painted by the coat
## shader (horse.gd set_groom). The horse has no bones
## (it is animated with blend shapes), so horse.gd hands follow() the
## measured points on its back, head and legs every frame, and each piece is
## laid along them.

## Each option the player can change, and the list it picks from. Options
## with a price are sold in the stable's shop.
const PAD_COLORS := [
	{"name": "White",    "color": Color(0.95, 0.94, 0.9)},
	{"name": "Navy",     "color": Color(0.12, 0.16, 0.36)},
	{"name": "Pink",     "color": Color(0.98, 0.55, 0.72)},
	{"name": "Lilac",    "color": Color(0.72, 0.58, 0.95), "price": 40},
	{"name": "Sky blue", "color": Color(0.5, 0.75, 0.98), "price": 40},
	{"name": "Mint",     "color": Color(0.55, 0.9, 0.75), "price": 40},
	{"name": "Red",      "color": Color(0.8, 0.12, 0.15)},
	{"name": "Black",    "color": Color(0.06, 0.06, 0.07)},
]
const TRIM_COLORS := [
	{"name": "Gold",   "color": Color(1.0, 0.78, 0.3), "metal": true},
	{"name": "Silver", "color": Color(0.85, 0.87, 0.9), "metal": true},
	{"name": "White",  "color": Color(0.97, 0.97, 0.95)},
	{"name": "Navy",   "color": Color(0.12, 0.16, 0.36)},
	{"name": "Pink",   "color": Color(1.0, 0.45, 0.68), "price": 30},
	{"name": "Purple", "color": Color(0.5, 0.28, 0.78), "price": 30},
]
const LEATHERS := [
	{"name": "Brown",      "color": Color(0.26, 0.13, 0.06)},
	{"name": "Dark brown", "color": Color(0.13, 0.065, 0.04)},
	{"name": "Black",      "color": Color(0.05, 0.045, 0.045)},
	{"name": "Tan",        "color": Color(0.62, 0.4, 0.2)},
]
const BRIDLE_COLORS := LEATHERS + [
	{"name": "Pink",   "color": Color(0.92, 0.42, 0.62), "price": 50},
	{"name": "Purple", "color": Color(0.42, 0.24, 0.66), "price": 50},
	{"name": "Blue",   "color": Color(0.2, 0.36, 0.75), "price": 50},
]
const WRAP_COLORS := [{"name": "No wraps", "color": Color.TRANSPARENT}] + PAD_COLORS

## The grooming salon. "face" and "legs" are white markings (coat.gdshader
## face_marking and leg_marking), "glitter" a sparkle on the coat.
const MANE_STYLES := [
	{"name": "Natural",        "color": Color.TRANSPARENT},
	{"name": "Button braids",  "color": Color(0.45, 0.32, 0.22), "price": 40},
	{"name": "Ribbon braids",  "color": Color(0.98, 0.55, 0.72), "price": 60},
]
const TAIL_STYLES := [
	{"name": "Natural",  "color": Color.TRANSPARENT},
	{"name": "Tail bow", "color": Color(0.98, 0.55, 0.72), "price": 30},
]
const RIBBON_COLORS := [
	{"name": "Pink",     "color": Color(1.0, 0.5, 0.7)},
	{"name": "Red",      "color": Color(0.85, 0.1, 0.15)},
	{"name": "Sky blue", "color": Color(0.45, 0.72, 1.0)},
	{"name": "Lilac",    "color": Color(0.72, 0.56, 0.98), "price": 20},
	{"name": "Gold",     "color": Color(1.0, 0.8, 0.3), "price": 20, "metal": true},
	{"name": "White",    "color": Color(0.97, 0.97, 0.95), "price": 20},
	{"name": "Mint",     "color": Color(0.5, 0.92, 0.72), "price": 20},
]
const WHITE := Color(0.95, 0.94, 0.9)
const FACE_MARKINGS := [
	{"name": "None",       "color": Color.TRANSPARENT},
	{"name": "Star",       "color": WHITE, "price": 30},
	{"name": "Stripe",     "color": WHITE, "price": 30},
	{"name": "Blaze",      "color": WHITE, "price": 40},
	{"name": "White face", "color": WHITE, "price": 60},
]
const LEG_MARKINGS := [
	{"name": "None",           "color": Color.TRANSPARENT},
	{"name": "Front socks",    "color": WHITE, "price": 30},
	{"name": "Hind socks",     "color": WHITE, "price": 30},
	{"name": "Four socks",     "color": WHITE, "price": 50},
	{"name": "Four stockings", "color": WHITE, "price": 60},
]
const GLITTERS := [
	{"name": "None",    "color": Color.TRANSPARENT},
	{"name": "Gold",    "color": Color(1.0, 0.82, 0.35), "price": 50},
	{"name": "Silver",  "color": Color(0.88, 0.92, 1.0), "price": 50},
	{"name": "Pink",    "color": Color(1.0, 0.5, 0.8), "price": 50},
	{"name": "Rainbow", "color": Color(0.6, 0.5, 1.0), "price": 80, "rainbow": true},
]

const OPTIONS := {
	"pad": PAD_COLORS, "trim": TRIM_COLORS, "saddle": LEATHERS,
	"bridle": BRIDLE_COLORS, "wraps": WRAP_COLORS,
	"face": FACE_MARKINGS, "legs": LEG_MARKINGS, "mane": MANE_STYLES,
	"tail": TAIL_STYLES, "ribbon": RIBBON_COLORS, "glitter": GLITTERS,
}
## Which options are tack (the Tack panel) and which are grooming (the Salon).
const TACK_KEYS := ["pad", "trim", "saddle", "bridle", "wraps"]
const GROOM_KEYS := ["face", "legs", "mane", "tail", "ribbon", "glitter"]
const DEFAULT := {"pad": 0, "trim": 0, "saddle": 1, "bridle": 1, "wraps": 1,
	"face": 0, "legs": 0, "mane": 0, "tail": 0, "ribbon": 0, "glitter": 0}

const LEGS := ["fl", "fr", "hl", "hr"]

var config: Dictionary = DEFAULT.duplicate()
var rider: Node3D   ## When set, the reins run to its hands and the stirrups to its feet

var _saddle_parts: Node3D
var _shells: Node3D          # Pad and saddle, scaled to the horse's breed
var body_scale := Vector3.ONE  ## The horse's breed size and build (horse.gd body_shape)
var mane_color := Color(0.1, 0.07, 0.05)  ## For button braids: the horse's mane
var _braids: Array[MeshInstance3D] = []   ## A knot (and bow) at each crest point
var _bows: Array[Node3D] = []
var _tail_bow: Node3D
var _wraps: Array[MeshInstance3D] = []
var _rings := {}    ## Name -> a loop, bit ring or stirrup iron placed each frame
var _straps := {}   ## Name -> a strap stretched between two points each frame
var _materials := {}


## Show or hide all of the tack, the saddle too.
func set_shown(on: bool) -> void:
	visible = on
	if _saddle_parts:
		_saddle_parts.visible = on


## Build the tack from a config (missing keys keep their defaults). The
## saddle goes under `saddle_root`, which horse.gd keeps on the horse's back.
func build(new_config: Dictionary, saddle_root: Node3D) -> void:
	config = DEFAULT.duplicate()
	for key in new_config:
		if OPTIONS.has(key):
			config[key] = clampi(new_config[key], 0, OPTIONS[key].size() - 1)
	for child in get_children():
		child.queue_free()
		remove_child(child)
	if _saddle_parts:
		_saddle_parts.queue_free()
	_wraps.clear()
	_braids.clear()
	_bows.clear()
	_tail_bow = null
	_rings.clear()
	_straps.clear()
	_reins.clear()
	_bands.clear()
	_make_materials()
	_saddle_parts = Node3D.new()
	_saddle_parts.name = "SaddleParts"
	_saddle_parts.visible = visible
	saddle_root.add_child(_saddle_parts)
	_build_saddle()
	_build_bridle()
	_build_wraps()
	_build_braids()


func _make_materials() -> void:
	_materials.pad = _material(PAD_CLOTH, PAD_COLORS[config.pad].color)
	var trim: Dictionary = TRIM_COLORS[config.trim]
	_materials.trim = _material(METAL if trim.get("metal", false) else CLOTH, trim.color, 0.8)
	var saddle: Color = LEATHERS[config.saddle].color
	_materials.saddle = _material(LEATHER, saddle, 0.65)
	_materials.flap = _material(LEATHER, saddle, 0.65, _arc_length(FLAP_TOP, FLAP_DEPTH))
	_materials.strap = _material(LEATHER, saddle, 0.5, STRAP_UV)
	_materials.bridle = _material(LEATHER, BRIDLE_COLORS[config.bridle].color, 0.55, STRAP_UV)
	_materials.metal = _material(METAL, Color(0.82, 0.83, 0.86), 0.8)
	_materials.mane = _material(CLOTH, mane_color, 0.3)
	var ribbon: Dictionary = RIBBON_COLORS[config.ribbon]
	_materials.ribbon = _material(METAL if ribbon.get("metal", false) else CLOTH, ribbon.color, 0.6)
	var wrap_color: Color = WRAP_COLORS[config.wraps].color
	if wrap_color.a > 0.0:
		_materials.wraps = _material(BANDAGE, wrap_color)


## Kinds of material in shaders/tack.gdshader.
const LEATHER := 0
const PAD_CLOTH := 1
const BANDAGE := 2
const CLOTH := 3
const METAL := 4
const TACK_SHADER := preload("res://shaders/tack.gdshader")
const STRAP_UV := 0.02   ## Leather straps' UVs run 0 to this across them (for the stitches)


func _material(kind: int, color: Color, shine := 0.5, stitch_width := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TACK_SHADER
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("shine", shine)
	m.set_shader_parameter("stitch_width", stitch_width)
	if color.get_luminance() > 0.5:
		m.set_shader_parameter("stitch_color", color.darkened(0.45))
	return m


# --- Saddle -------------------------------------------------------------------

## The saddle's own space is the seat: forward -Z, up +Y, the top of the
## horse's back at y = 0. The pad, saddle and girth are slabs shaped like the
## horse's back and barrel (measured from the model, plus a little room):
## how far out each side is at each depth below the top...
const BACK_WIDTH := [[0.0, 0.0], [0.01, 0.09], [0.04, 0.18], [0.08, 0.24], [0.13, 0.29], [0.2, 0.325],
	[0.27, 0.345], [0.35, 0.36], [0.45, 0.365], [0.52, 0.34], [0.6, 0.26], [0.66, 0.18], [0.7, 0.09], [0.72, 0.0]]
const PAD_DEPTH := 0.33      ## How far down the sides the pad hangs
const PAD_FRONT := -0.33
const PAD_BACK := 0.31
const SEAT_DEPTH := 0.21     ## How far down the sides the seat comes
const FLAP_TOP := 0.12       ## The flaps hang from under the seat...
const FLAP_DEPTH := 0.45     ## ...to here
const GIRTH_DEPTH := 0.72    ## Under the belly


## ...and how much the back rises in front of and behind the seat, which
## sits in the dip between the withers and the croup.
func _back_rise(z: float) -> float:
	var d := -z - 0.05
	return d * d * (1.0 if d > 0.0 else 0.55)


func _back_width(depth: float) -> float:
	for i in range(1, BACK_WIDTH.size()):
		if depth <= BACK_WIDTH[i][0] or i == BACK_WIDTH.size() - 1:
			var a: Array = BACK_WIDTH[i - 1]
			var b: Array = BACK_WIDTH[i]
			return lerpf(a[1], b[1], clampf((depth - a[0]) / (b[0] - a[0]), 0.0, 1.0))
	return 0.0


## A point `out` metres off the horse's back and barrel, at `u` (the signed
## depth below the top: negative on the left, positive on the right) and `z`.
func _point(u: float, z: float, out: float) -> Vector3:
	var depth := absf(u)
	return Vector3(signf(u) * (_back_width(depth) + out), -depth + out + _back_rise(z), z)


## How far round the horse it is from depth `a` to depth `b`, in metres.
func _arc_length(a: float, b: float) -> float:
	var length := 0.0
	for i in 24:
		length += _point(lerpf(a, b, i / 24.0), 0.0, 0.0).distance_to(_point(lerpf(a, b, (i + 1) / 24.0), 0.0, 0.0))
	return length


## How far a corner of radius `r` cuts in at `depth`, for a piece reaching
## down to `bottom`: rounded bottom corners.
func _corner(depth: float, bottom: float, r: float) -> float:
	var into := maxf(depth - (bottom - r), 0.0)
	return r - sqrt(maxf(r * r - into * into, 0.0))


## Fit the saddle and pad to a horse of another size or build.
func set_body_scale(shape: Vector3) -> void:
	body_scale = shape
	if _shells:
		_shells.scale = shape


func _build_saddle() -> void:
	# The pad and saddle are shaped to the back of a warmblood, then
	# stretched like the horse's body (see horse.gd), around the seat.
	_shells = Node3D.new()
	_shells.scale = body_scale
	_saddle_parts.add_child(_shells)
	# The pad: quilted, with rounded corners and piping round its edge.
	var pad_front := func(d: float) -> float: return PAD_FRONT + _corner(d, PAD_DEPTH, 0.09)
	var pad_back := func(d: float) -> float: return PAD_BACK - _corner(d, PAD_DEPTH, 0.12)
	_add(_slab(-PAD_DEPTH, PAD_DEPTH, pad_front, pad_back, 0.0, 0.016), _materials.pad, _shells)
	_add(_tube(_outline(-PAD_DEPTH, PAD_DEPTH, pad_front, pad_back, 0.016), 0.008), _materials.trim, _shells)
	# The girth, round the belly from under one flap to under the other.
	var girth_front := func(_d: float) -> float: return -0.15
	var girth_back := func(_d: float) -> float: return -0.07
	# Flaps hanging down each side, slanting forward, with a padded knee roll.
	var flap_front := func(d: float) -> float:
		return -0.21 - 0.15 * clampf((d - FLAP_TOP) / (FLAP_DEPTH - FLAP_TOP), 0.0, 1.0) + _corner(d, FLAP_DEPTH, 0.07)
	var flap_back := func(d: float) -> float:
		return 0.1 - 0.04 * clampf((d - FLAP_TOP) / (FLAP_DEPTH - FLAP_TOP), 0.0, 1.0) - _corner(d, FLAP_DEPTH, 0.1)
	var roll_front := func(d: float) -> float: return flap_front.call(d) + 0.02
	var roll_back := func(d: float) -> float: return flap_front.call(d) + 0.07
	for s in [-1.0, 1.0]:
		_add(_slab(s * 0.36, s * GIRTH_DEPTH, girth_front, girth_back, 0.004, 0.01), _materials.strap, _shells)
		_add(_slab(s * FLAP_TOP, s * FLAP_DEPTH, flap_front, flap_back, 0.022, 0.008), _materials.flap, _shells)
		_add(_slab(s * 0.16, s * 0.4, roll_front, roll_back, 0.03, 0.012), _materials.saddle, _shells)
	# The seat, rising to the pommel in front and the cantle behind.
	var seat_front := func(d: float) -> float: return -0.25 + _corner(d, SEAT_DEPTH, 0.08)
	var seat_back := func(d: float) -> float: return 0.2 - _corner(d, SEAT_DEPTH, 0.12)
	var seat_lift := func(u: float, z: float) -> float:
		var d := absf(u)
		var pommel := 0.035 * (1.0 - smoothstep(-0.25, -0.14, z)) * (1.0 - smoothstep(0.02, 0.12, d))
		var cantle := 0.06 * smoothstep(0.07, 0.2, z) * (1.0 - smoothstep(0.05, 0.17, d))
		return pommel + cantle
	_add(_slab(-SEAT_DEPTH, SEAT_DEPTH, seat_front, seat_back, 0.02, 0.028, seat_lift), _materials.saddle, _shells)
	# Stirrups: an iron on a leather on each side.
	for side in ["l", "r"]:
		_straps["leather_" + side] = _add(_strap_mesh(), _materials.strap, _saddle_parts)
		_rings["iron_" + side] = _stirrup_iron()


## A stirrup iron: an arch with a flat tread to stand on. Its own space:
## across the horse X, forward Y, up Z, the tread at the origin.
func _stirrup_iron() -> Node3D:
	var iron := Node3D.new()
	_saddle_parts.add_child(iron)
	var arch := TorusMesh.new()
	arch.inner_radius = 0.05
	arch.outer_radius = 0.06
	arch.rings = 20
	arch.ring_segments = 8
	var mi := _add(arch, _materials.metal, iron)
	mi.position = Vector3(0, 0, 0.055)
	mi.scale = Vector3(1.0, 1.0, 1.12)
	var tread := BoxMesh.new()
	tread.size = Vector3(0.11, 0.045, 0.012)
	_add(tread, _materials.metal, iron).position = Vector3(0, 0, 0.004)
	return iron


## A slab lying on the horse's back from `from` to `to` round it (signed
## depths, see _point), from front(depth) to back(depth) along it, `out`
## off the horse and `thick` thick, plus lift(u, z) on top. Its UVs are in
## metres: round the horse, then along it.
func _slab(from: float, to: float, front: Callable, back: Callable, out: float, thick: float, lift := Callable()) -> ArrayMesh:
	const ACROSS := 24
	const ALONG := 12
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Distance round the horse at each step across, for the UVs.
	var arc: Array[float] = [0.0]
	for i in ACROSS:
		var a := lerpf(from, to, float(i) / ACROSS)
		var b := lerpf(from, to, float(i + 1) / ACROSS)
		arc.append(arc[i] + _point(a, 0.0, 0.0).distance_to(_point(b, 0.0, 0.0)))
	var top := []
	var bottom := []
	for i in ACROSS + 1:
		var u := lerpf(from, to, float(i) / ACROSS)
		var d := absf(u)
		var top_row := []
		var bottom_row := []
		for j in ALONG + 1:
			var z := lerpf(front.call(d), back.call(d), float(j) / ALONG)
			var rise: float = lift.call(u, z) if lift.is_valid() else 0.0
			top_row.append([_point(u, z, out + thick + rise), Vector2(arc[i], z)])
			bottom_row.append([_point(u, z, out), Vector2(arc[i], z)])
		top.append(top_row)
		bottom.append(bottom_row)
	var quad := func(a: Array, b: Array, c: Array, d: Array) -> void:
		for v in [a, b, c, c, b, d]:
			st.set_uv(v[1])
			st.add_vertex(v[0])
	st.set_smooth_group(0)
	for i in ACROSS:
		for j in ALONG:
			quad.call(top[i][j], top[i + 1][j], top[i][j + 1], top[i + 1][j + 1])
	st.set_smooth_group(1)
	for i in ACROSS:
		for j in ALONG:
			quad.call(bottom[i][j], bottom[i][j + 1], bottom[i + 1][j], bottom[i + 1][j + 1])
	# The edges all round.
	st.set_smooth_group(2)
	for i in ACROSS:
		quad.call(top[i][0], bottom[i][0], top[i + 1][0], bottom[i + 1][0])
		quad.call(top[i][ALONG], top[i + 1][ALONG], bottom[i][ALONG], bottom[i + 1][ALONG])
	for j in ALONG:
		quad.call(top[0][j], top[0][j + 1], bottom[0][j], bottom[0][j + 1])
		quad.call(top[ACROSS][j], bottom[ACROSS][j], top[ACROSS][j + 1], bottom[ACROSS][j + 1])
	st.generate_normals()
	return st.commit()


## The edge of a slab's top, all the way round.
func _outline(from: float, to: float, front: Callable, back: Callable, out: float) -> Array[Vector3]:
	const STEPS := 24
	var points: Array[Vector3] = []
	for i in STEPS:
		var u := lerpf(from, to, float(i) / STEPS)
		points.append(_point(u, front.call(absf(u)), out))
	for i in STEPS:
		var z := lerpf(front.call(absf(to)), back.call(absf(to)), float(i) / STEPS)
		points.append(_point(to, z, out))
	for i in STEPS:
		var u := lerpf(to, from, float(i) / STEPS)
		points.append(_point(u, back.call(absf(u)), out))
	for i in STEPS:
		var z := lerpf(back.call(absf(from)), front.call(absf(from)), float(i) / STEPS)
		points.append(_point(from, z, out))
	return points


## A round tube of `radius` through a closed loop of points (piping).
func _tube(points: Array[Vector3], radius: float) -> ArrayMesh:
	const SIDES := 6
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := []
	var count := points.size()
	for i in count:
		var along := (points[(i + 1) % count] - points[(i - 1 + count) % count]).normalized()
		var side := along.cross(Vector3.UP)
		if side.length() < 0.1:
			side = along.cross(Vector3.RIGHT)
		side = side.normalized()
		var up := side.cross(along).normalized()
		var ring := []
		for k in SIDES:
			var a := TAU * k / SIDES
			ring.append(points[i] + (side * cos(a) + up * sin(a)) * radius)
		rings.append(ring)
	for i in count:
		var r0: Array = rings[i]
		var r1: Array = rings[(i + 1) % count]
		for k in SIDES:
			var k1 := (k + 1) % SIDES
			for v in [r0[k], r1[k], r0[k1], r0[k1], r1[k], r1[k1]]:
				st.set_uv(Vector2(float(k) / SIDES * 0.05, i * 0.01))
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


# --- Bridle -------------------------------------------------------------------

const BAND_WIDTH := 0.022      ## Noseband and crownpiece
const STRAP_THICK := 0.005
const REIN_PIECES := 10

var _reins := {}    ## "l"/"r" -> the pieces of each rein, nose to hand
var _bands := {}    ## Name -> ImmediateMesh redrawn along the head each frame
var _strap: ArrayMesh


func _build_bridle() -> void:
	# The noseband, the crownpiece with its throatlatch, the browband and
	# the cheekpieces lie along points measured round the head
	# (tools/groom_track.py), so they sit on it whatever it does.
	for name in ["noseband", "headpiece", "browband", "cheekpiece_l", "cheekpiece_r"]:
		var mesh := ImmediateMesh.new()
		_bands[name] = mesh
		_rings[name] = _add(mesh, _materials.trim if name == "browband" else _materials.bridle, self)
		_rings[name].extra_cull_margin = 1.0
	var bit := TorusMesh.new()
	bit.inner_radius = 0.024
	bit.outer_radius = 0.032
	bit.rings = 16
	bit.ring_segments = 8
	for side in ["l", "r"]:
		_rings["bit_" + side] = _add(bit, _materials.metal, self)
		_straps["buckle_" + side] = _add(_strap_mesh(), _materials.metal, self)
		_straps["keeper_" + side] = _add(_strap_mesh(), _materials.bridle, self)
		var pieces: Array[MeshInstance3D] = []
		for i in REIN_PIECES:
			pieces.append(_add(_strap_mesh(), _materials.bridle, self))
		_reins[side] = pieces


## A unit strap (a box from -0.5 to 0.5: X across it, Y through it, Z
## along it), its UVs running 0 to STRAP_UV across for the stitching.
func _strap_mesh() -> ArrayMesh:
	if _strap:
		return _strap
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)   # Flat sides
	var corner := func(x: float, y: float, z: float) -> Array:
		return [Vector3(x, y, z), Vector2((x + 0.5) * STRAP_UV, (z + 0.5) * 0.3)]
	var quad := func(a: Array, b: Array, c: Array, d: Array) -> void:
		for v in [a, b, c, c, b, d]:
			st.set_uv(v[1])
			st.add_vertex(v[0])
	for y in [-0.5, 0.5]:
		quad.call(corner.call(-0.5, y, -0.5), corner.call(0.5, y, -0.5), corner.call(-0.5, y, 0.5), corner.call(0.5, y, 0.5))
	for x in [-0.5, 0.5]:
		quad.call(corner.call(x, -0.5, -0.5), corner.call(x, 0.5, -0.5), corner.call(x, -0.5, 0.5), corner.call(x, 0.5, 0.5))
	for z in [-0.5, 0.5]:
		quad.call(corner.call(-0.5, -0.5, z), corner.call(0.5, -0.5, z), corner.call(-0.5, 0.5, z), corner.call(0.5, 0.5, z))
	st.generate_normals()
	_strap = st.commit()
	return _strap


# --- Leg wraps ----------------------------------------------------------------

func _build_wraps() -> void:
	if not _materials.has("wraps"):
		return
	for leg in LEGS:
		# A little wider at the top, where the bandage is wound over itself.
		var mesh := CylinderMesh.new()
		mesh.top_radius = 1.06
		mesh.bottom_radius = 1.0
		mesh.height = 1.0
		mesh.radial_segments = 20
		mesh.rings = 3
		var mi := _add(mesh, _materials.wraps, self)
		mi.name = "Wrap_" + leg
		_wraps.append(mi)


# --- Braids and bows ----------------------------------------------------------

const BRAIDS := 7          ## Crest points measured by tools/groom_track.py
const KNOT_SIZE := 0.032   ## Radius of a button braid, in metres


func _build_braids() -> void:
	if config.mane > 0:
		var knot := SphereMesh.new()
		knot.radius = 1.0
		knot.height = 2.0
		knot.radial_segments = 12
		knot.rings = 6
		for i in BRAIDS:
			_braids.append(_add(knot, _materials.mane, self))
			if config.mane == 2:
				_bows.append(_bow(0.55))
	if config.tail > 0:
		_tail_bow = _bow(1.0)


## A ribbon bow: two loops and a knot, with two short tails, `size` 1 being
## a bow about 16 cm across. Its own space: across is X, out is +Y.
func _bow(size: float) -> Node3D:
	var bow := Node3D.new()
	add_child(bow)
	var loop := SphereMesh.new()
	loop.radius = 1.0
	loop.height = 2.0
	loop.radial_segments = 12
	loop.rings = 6
	for s in [-1.0, 1.0]:
		var mi := _add(loop, _materials.ribbon, bow)
		mi.scale = Vector3(0.045, 0.012, 0.03) * size
		mi.position = Vector3(s * 0.04, 0.0, 0.0) * size
		mi.rotation.z = s * 0.25
		var tail := _add(BoxMesh.new(), _materials.ribbon, bow)
		tail.scale = Vector3(0.022, 0.004, 0.07) * size
		tail.position = Vector3(s * 0.022, -0.004, 0.04) * size
		tail.rotation.y = -s * 0.35
	var knot := _add(loop, _materials.ribbon, bow)
	knot.scale = Vector3(0.016, 0.016, 0.016) * size
	return bow


func _follow_braids(points: Dictionary) -> void:
	if _braids.is_empty() and not _tail_bow:
		return
	var crest: Array[Vector3] = []
	for i in BRAIDS:
		crest.append(points["crest_%d" % i])
	for i in _braids.size():
		var along := (crest[mini(i + 1, BRAIDS - 1)] - crest[maxi(i - 1, 0)]).normalized()
		var up := (Vector3.UP - along * along.dot(Vector3.UP)).normalized()
		var across := along.cross(up).normalized()
		var spot: Vector3 = crest[i] + up * KNOT_SIZE * 0.5
		_braids[i].transform = Transform3D(Basis(across * KNOT_SIZE * 0.9, up * KNOT_SIZE * 0.8, along * KNOT_SIZE * 1.25), spot)
		if i < _bows.size():
			_bows[i].transform = Transform3D(Basis(across, up, along), spot + up * KNOT_SIZE * 0.85)
	if _tail_bow:
		var dock: Vector3 = points.dock
		var croup: Vector3 = points.croup
		var back: Vector3 = (dock - croup).normalized()
		var up: Vector3 = (Vector3.UP - back * back.dot(Vector3.UP)).normalized()
		var across: Vector3 = back.cross(up).normalized()
		# On the top of the tail, facing up and back.
		var out: Vector3 = (up + back).normalized()
		_tail_bow.transform = Transform3D(Basis(across, out, out.cross(across).normalized()), dock + out * 0.01)


# --- Following the horse --------------------------------------------------------

## Lay the tack along the horse. `points` are marks from saddle_track.json
## in this node's parent's space; `radii` the legs' thickness there;
## `saddle` is the saddle root's transform in the same space.
func follow(points: Dictionary, radii: Dictionary, saddle: Transform3D) -> void:
	_follow_head(points, saddle)
	_follow_stirrups(saddle)
	_follow_braids(points)
	for i in _wraps.size():
		var leg: String = LEGS[i]
		var low: Vector3 = points[leg + "_low"]
		var high: Vector3 = points[leg + "_high"]
		var up := (high - low).normalized()
		# From the fetlock up the cannon, stopping below the knee or hock.
		var bottom := low - up * 0.04
		var top := low + up * (0.2 if leg.begins_with("f") else 0.16)
		var radius: float = radii[leg + "_low"] * 1.3
		_place_along(_wraps[i], bottom, top, Vector3(radius, 1.0, radius))


func _follow_head(points: Dictionary, saddle: Transform3D) -> void:
	var nose: Vector3 = points.nose
	var cheek: Vector3 = points.cheek
	# The head's own directions: along it towards the nose, up through the
	# forehead, and out to the horse's right.
	var ahead := (nose - cheek).normalized()
	var up := (Vector3.UP - ahead * ahead.y).normalized()
	var right := ahead.cross(up).normalized()
	if right.x < 0.0:
		right = -right
	# Off the head: away from the line down its middle.
	var off := func(p: Vector3) -> Vector3:
		var on_line := cheek + ahead * ahead.dot(p - cheek)
		return (p - on_line).normalized()

	var noseband := _marks(points, "noseband_")
	var headpiece := _marks(points, "headpiece_")
	_lay_band("noseband", noseband, _away_from_middle(noseband), BAND_WIDTH, true)
	_lay_band("headpiece", headpiece, _away_from_middle(headpiece), BAND_WIDTH, true)
	var brow := _marks(points, "brow_")
	var brow_out: Array[Vector3] = []
	for p in brow:
		brow_out.append(off.call(p))
	_lay_band("browband", brow, brow_out, 0.024, false)

	for s in [-1.0, 1.0]:
		var side := "r" if s > 0.0 else "l"
		var bit: Vector3 = points["bit_" + side]
		var bit_ring: MeshInstance3D = _rings["bit_" + side]
		bit_ring.transform = Transform3D(Basis(ahead, -right * s, up), bit + off.call(bit) * 0.012)
		# The cheekpiece runs from the crownpiece down the side of the face,
		# lying on it, to the bit (groom_track.py measures points along it).
		var top: Vector3 = points["cheek_top_" + side]
		var line: Array[Vector3] = [top]
		var k := 0
		while points.has("cheek_%d_%s" % [k, side]):
			line.append(points["cheek_%d_%s" % [k, side]])
			k += 1
		line.append(bit)
		var outs: Array[Vector3] = []
		for p in line:
			outs.append(off.call(p))
		_lay_band("cheekpiece_" + side, line, outs, 0.018, false)
		# A buckle and a keeper part way down the cheekpiece.
		var at := mini(2, line.size() - 2)
		var down: Vector3 = (line[at + 1] - line[at]).normalized()
		var face: Vector3 = outs[at]
		var buckle: Vector3 = line[at] + face * (STRAP_THICK + 0.004)
		_place_strap(_straps["buckle_" + side], buckle - down * 0.012, buckle + down * 0.012, face, 0.024, 0.006)
		_place_strap(_straps["keeper_" + side], buckle + down * 0.02, buckle + down * 0.032, face, 0.024, 0.007)
		# Reins go back to the rider's hands, or rest on the neck by the
		# withers, hanging in a gentle curve.
		var hand: Vector3
		if rider:
			hand = _bone_position("hand_" + side) + Vector3(0, -0.02, 0)
		else:
			hand = saddle * Vector3(s * 0.12, 0.06, -0.48)
		var sag := Vector3(0, -0.06 if rider else -0.14, 0)
		var pull := bit.lerp(hand, 0.5) + sag * 2.0
		var pieces: Array = _reins[side]
		var last := bit
		for i in pieces.size():
			var t := float(i + 1) / pieces.size()
			var next := bit.lerp(pull, t).lerp(pull.lerp(hand, t), t)
			var dir := (next - last).normalized()
			# Overlap the pieces a little so the bends don't show gaps.
			_place_strap(pieces[i], last - dir * 0.004, next + dir * 0.004, right * s, 0.016, 0.005)
			last = next


## The measured points `prefix`0, `prefix`1, ... in order.
func _marks(points: Dictionary, prefix: String) -> Array[Vector3]:
	var line: Array[Vector3] = []
	while points.has(prefix + str(line.size())):
		line.append(points[prefix + str(line.size())])
	return line


func _middle(line: Array[Vector3]) -> Vector3:
	var sum := Vector3.ZERO
	for p in line:
		sum += p
	return sum / maxf(line.size(), 1)


func _away_from_middle(loop: Array[Vector3]) -> Array[Vector3]:
	var middle := _middle(loop)
	var outs: Array[Vector3] = []
	for p in loop:
		outs.append((p - middle).normalized())
	return outs


## Lay a leather band along `line` (round into a loop when `closed`),
## `width` wide, its face turned to `outs`. The band's node sits at the
## band's middle, so it can be found there.
func _lay_band(name: String, line: Array[Vector3], outs: Array[Vector3], width: float, closed: bool) -> void:
	var mesh: ImmediateMesh = _bands[name]
	var node: MeshInstance3D = _rings[name]
	mesh.clear_surfaces()
	var count := line.size()
	if count < 2:
		return
	var middle := _middle(line)
	node.transform = Transform3D(Basis(), middle)
	var rows := []   # Each: [centre, half across, out, distance along]
	var travelled := 0.0
	for k in count + (1 if closed else 0):
		var i := k % count
		var prev := line[(i - 1 + count) % count] if closed or i > 0 else line[i]
		var next := line[(i + 1) % count] if closed or i < count - 1 else line[i]
		var along := (next - prev).normalized()
		var across := along.cross(outs[i]).normalized()
		if k > 0:
			travelled += line[i].distance_to(line[(k - 1) % count])
		rows.append([line[i] - middle, across * width * 0.5, outs[i], travelled])
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertex := func(p: Vector3, normal: Vector3, uv: Vector2) -> void:
		mesh.surface_set_normal(normal)
		mesh.surface_set_uv(uv)
		mesh.surface_add_vertex(p)
	for k in rows.size() - 1:
		var a: Array = rows[k]
		var b: Array = rows[k + 1]
		# The face, then the two edges down to the skin.
		var corners := [
			[a[0] - a[1], b[0] - b[1], a[0] + a[1], b[0] + b[1], a[2], b[2], 0.0, STRAP_UV],
			[a[0] - a[1] - a[2] * STRAP_THICK, b[0] - b[1] - b[2] * STRAP_THICK, a[0] - a[1], b[0] - b[1], -a[1].normalized(), -b[1].normalized(), 0.0, 0.002],
			[a[0] + a[1], b[0] + b[1], a[0] + a[1] - a[2] * STRAP_THICK, b[0] + b[1] - b[2] * STRAP_THICK, a[1].normalized(), b[1].normalized(), 0.0, 0.002],
		]
		for c in corners:
			var v0 := Vector2(c[6], a[3])
			var v1 := Vector2(c[6], b[3])
			var v2 := Vector2(c[7], a[3])
			var v3 := Vector2(c[7], b[3])
			vertex.call(c[0], c[4], v0)
			vertex.call(c[1], c[5], v1)
			vertex.call(c[2], c[4], v2)
			vertex.call(c[2], c[4], v2)
			vertex.call(c[1], c[5], v1)
			vertex.call(c[3], c[5], v3)
	mesh.surface_end()


func _follow_stirrups(saddle: Transform3D) -> void:
	for s in [-1.0, 1.0]:
		var side := "r" if s > 0.0 else "l"
		var top := Vector3(s * (_back_width(0.1) + 0.03), -0.1 + _back_rise(-0.06), -0.06) * body_scale
		var iron: Vector3
		if rider:
			iron = saddle.affine_inverse() * _bone_position("ball_" + side) + Vector3(0, -0.01, 0)
		else:
			# Run up the leather out of the way, as in a stable.
			iron = Vector3(s * (_back_width(0.24) + 0.04), -0.26, -0.06) * body_scale
		_place_strap(_straps["leather_" + side], top, iron + Vector3(0, 0.115, 0), Vector3(s, 0, 0), 0.025, 0.005)
		var ring: Node3D = _rings["iron_" + side]
		ring.transform = Transform3D(Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP), iron)


## Where one of the rider's bones is, in this node's parent's space.
func _bone_position(bone: String) -> Vector3:
	var skeleton: Skeleton3D = rider.skeleton
	var index := skeleton.find_bone(bone)
	var world := skeleton.global_transform * skeleton.get_bone_global_pose(index).origin
	return (get_parent() as Node3D).global_transform.affine_inverse() * world


# --- Helpers ------------------------------------------------------------------

func _add(mesh: Mesh, material: Material, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## A unit box stretched from `from` to `to`, `width` wide and `thick` deep,
## its flat side facing `facing`.
func _place_strap(mi: MeshInstance3D, from: Vector3, to: Vector3, facing: Vector3, width: float, thick: float) -> void:
	var along := to - from
	if along.length() < 0.001:
		mi.visible = false
		return
	mi.visible = true
	var dir := along.normalized()
	var out := (facing - dir * facing.dot(dir)).normalized()
	var across := out.cross(dir).normalized()
	mi.transform = Transform3D(Basis(across * width, out * thick, along), from + along * 0.5)


## A unit cylinder (radius 1, height 1) from `from` to `to`, scaled by `size`.
func _place_along(mi: MeshInstance3D, from: Vector3, to: Vector3, size: Vector3) -> void:
	var along := to - from
	var dir := along.normalized()
	var side := Vector3.FORWARD.cross(dir)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	var front := side.cross(dir).normalized()
	mi.transform = Transform3D(Basis(side * size.x, along, front * size.z), from + along * 0.5)
