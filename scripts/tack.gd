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

## Sizes in metres, fitted to the horse model by eye.
const NOSEBAND_SIZE := Vector2(0.1, 0.135) ## Half-width and half-height
const HEADPIECE_SIZE := Vector2(0.13, 0.22)
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
var _rings := {}    ## Name -> torus MeshInstance3D placed each frame
var _straps := {}   ## Name -> box MeshInstance3D stretched between two points each frame
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
	var cloth := func(color: Color) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.rim_enabled = true
		m.rim = 0.3
		return m
	_materials.pad = cloth.call(PAD_COLORS[config.pad].color)
	var trim: Dictionary = TRIM_COLORS[config.trim]
	_materials.trim = cloth.call(trim.color)
	if trim.get("metal", false):
		_materials.trim.metallic = 0.8
		_materials.trim.roughness = 0.3
	var leather := func(color: Color) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.6
		m.metallic_specular = 0.3
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return m
	_materials.saddle = leather.call(LEATHERS[config.saddle].color)
	_materials.bridle = leather.call(BRIDLE_COLORS[config.bridle].color)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.82, 0.83, 0.86)
	metal.metallic = 0.9
	metal.roughness = 0.25
	_materials.metal = metal
	_materials.mane = cloth.call(mane_color)
	_materials.mane.roughness = 0.7
	var ribbon: Dictionary = RIBBON_COLORS[config.ribbon]
	_materials.ribbon = cloth.call(ribbon.color)
	_materials.ribbon.roughness = 0.4
	if ribbon.get("metal", false):
		_materials.ribbon.metallic = 0.7
		_materials.ribbon.roughness = 0.3
	var wrap_color: Color = WRAP_COLORS[config.wraps].color
	if wrap_color.a > 0.0:
		_materials.wraps = cloth.call(wrap_color)
		_materials.wraps.roughness = 0.95


# --- Saddle -------------------------------------------------------------------

## The saddle's own space is the seat: forward -Z, up +Y, the top of the
## horse's back at y = 0. The pad and saddle are shells shaped like the back
## (measured from the model, plus a little room): how far out each side is
## at each depth below the top...
const BACK_WIDTH := [[0.0, 0.0], [0.01, 0.09], [0.04, 0.18], [0.08, 0.24], [0.13, 0.29], [0.2, 0.34], [0.27, 0.385], [0.35, 0.43], [0.45, 0.45]]
const PAD_DEPTH := 0.33      ## How far down the sides the pad hangs
const SADDLE_DEPTH := 0.2


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
	# The pad, with trim along its lower edges and across its front and back.
	_add(_shell(-PAD_DEPTH, PAD_DEPTH, -0.33, 0.31, 0.0), _materials.pad, _shells)
	for s in [-1.0, 1.0]:
		_add(_shell(s * (PAD_DEPTH - 0.035), s * PAD_DEPTH, -0.33, 0.31, 0.004), _materials.trim, _shells)
	for z in [-0.33, 0.275]:
		_add(_shell(-PAD_DEPTH, PAD_DEPTH, z, z + 0.035, 0.004), _materials.trim, _shells)
	# The saddle: flaps over the pad, and a raised pommel and cantle.
	_add(_shell(-SADDLE_DEPTH, SADDLE_DEPTH, -0.22, 0.2, 0.026), _materials.saddle, _shells)
	for part in [[0.1, -0.2, -0.01], [0.13, 0.19, -0.035]]:
		var mesh := CylinderMesh.new()
		mesh.top_radius = part[0]
		mesh.bottom_radius = part[0]
		mesh.height = 0.05
		mesh.radial_segments = 24
		var mi := _add(mesh, _materials.saddle, _shells)
		mi.rotation.x = PI / 2
		mi.position = Vector3(0, part[2] + _back_rise(part[1]), part[1])
		mi.scale = Vector3(1.0, 1.0, 0.75)
	# Stirrups: an iron on a leather on each side.
	for side in ["l", "r"]:
		_straps["leather_" + side] = _add(BoxMesh.new(), _materials.saddle, _saddle_parts)
		var iron := TorusMesh.new()
		iron.inner_radius = 0.045
		iron.outer_radius = 0.058
		iron.rings = 16
		iron.ring_segments = 6
		_rings["iron_" + side] = _add(iron, _materials.metal, _saddle_parts)


## A shell over the horse's back, from `from` to `to` around it (signed
## depths below the top: negative on the left, positive on the right), from
## `front` to `back` along it, and `out` further out than the back itself.
func _shell(from: float, to: float, front: float, back: float, out: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var across := 20
	var along := 8
	var point := func(u: float, z: float) -> Vector3:
		var depth := absf(u)
		return Vector3(signf(u) * (_back_width(depth) + out), -depth + out + _back_rise(z), z)
	for i in across:
		var u0 := lerpf(from, to, float(i) / across)
		var u1 := lerpf(from, to, float(i + 1) / across)
		for j in along:
			var z0 := lerpf(front, back, float(j) / along)
			var z1 := lerpf(front, back, float(j + 1) / along)
			var quad: Array[Vector3] = [point.call(u0, z0), point.call(u1, z0), point.call(u0, z1), point.call(u1, z1)]
			for k in [0, 1, 2, 2, 1, 3]:
				st.add_vertex(quad[k])
	st.generate_normals()
	return st.commit()


# --- Bridle -------------------------------------------------------------------

func _build_bridle() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.9
	ring.outer_radius = 1.0
	ring.rings = 24
	ring.ring_segments = 6
	for name in ["noseband", "headpiece"]:
		_rings[name] = _add(ring, _materials.bridle, self)
	var bit := TorusMesh.new()
	bit.inner_radius = 0.024
	bit.outer_radius = 0.032
	bit.rings = 12
	bit.ring_segments = 6
	for side in ["l", "r"]:
		_rings["bit_" + side] = _add(bit, _materials.metal, self)
		for name in ["cheekpiece_", "rein_", "rein_end_"]:
			_straps[name + side] = _add(BoxMesh.new(), _materials.bridle, self)
	_straps.browband = _add(BoxMesh.new(), _materials.trim, self)


# --- Leg wraps ----------------------------------------------------------------

func _build_wraps() -> void:
	if not _materials.has("wraps"):
		return
	for leg in LEGS:
		var mesh := CylinderMesh.new()
		mesh.top_radius = 1.0
		mesh.bottom_radius = 1.0
		mesh.height = 1.0
		mesh.radial_segments = 16
		mesh.rings = 1
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
	var muzzle: Vector3 = points.muzzle
	# The head's own directions: along it towards the nose, up through the
	# forehead, and out to the horse's right.
	var ahead := (nose - cheek).normalized()
	var up := (Vector3.UP - ahead * ahead.y).normalized()
	var right := ahead.cross(up).normalized()
	if right.x < 0.0:
		right = -right

	var noseband := muzzle.lerp(cheek, 0.35) + up * 0.01
	_place_ring(_rings.noseband, noseband, right, up, ahead, NOSEBAND_SIZE)
	var poll := cheek - ahead * 0.02 + up * 0.0
	var tilt := ahead.rotated(right, -0.35)
	var tilt_up := up.rotated(right, -0.35)
	_place_ring(_rings.headpiece, poll, right, tilt_up, tilt, HEADPIECE_SIZE)
	var brow := poll + ahead * 0.06 + up * (HEADPIECE_SIZE.y * 0.82)
	_place_strap(_straps.browband, brow - right * 0.085, brow + right * 0.085, ahead, 0.022, 0.008)

	var mouth := nose - ahead * 0.07 - up * 0.04
	for s in [-1.0, 1.0]:
		var side := "r" if s > 0.0 else "l"
		var bit: Vector3 = mouth + right * s * (NOSEBAND_SIZE.x + 0.01)
		var bit_ring: MeshInstance3D = _rings["bit_" + side]
		bit_ring.transform = Transform3D(Basis(ahead, -right, up), bit)
		var cheek_top: Vector3 = poll + right * s * (HEADPIECE_SIZE.x + 0.005)
		_place_strap(_straps["cheekpiece_" + side], cheek_top, bit + up * 0.025, right * s, 0.018, 0.007)
		# Reins go back to the rider's hands, or rest on the neck by the withers.
		var hand: Vector3
		if rider:
			hand = _bone_position("hand_" + side) + Vector3(0, -0.02, 0)
		else:
			hand = saddle * Vector3(s * 0.12, 0.06, -0.48)
		var sag := bit.lerp(hand, 0.55) + Vector3(0, -0.06 if rider else -0.14, 0)
		_place_strap(_straps["rein_" + side], bit, sag, right * s, 0.016, 0.006)
		_place_strap(_straps["rein_end_" + side], sag, hand, right * s, 0.016, 0.006)


func _follow_stirrups(saddle: Transform3D) -> void:
	for s in [-1.0, 1.0]:
		var side := "r" if s > 0.0 else "l"
		var top := Vector3(s * (_back_width(0.1) + 0.016), -0.1 + _back_rise(-0.06), -0.06) * body_scale
		var iron: Vector3
		if rider:
			iron = saddle.affine_inverse() * _bone_position("ball_" + side) + Vector3(0, -0.01, 0)
		else:
			# Run up the leather out of the way, as in a stable.
			iron = Vector3(s * (_back_width(0.24) + 0.03), -0.24, -0.06) * body_scale
		_place_strap(_straps["leather_" + side], top, iron + Vector3(0, 0.05, 0), Vector3(s, 0, 0), 0.025, 0.006)
		var ring: MeshInstance3D = _rings["iron_" + side]
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


## A unit torus (radius 1) as an ellipse around `centre`, facing `normal`.
func _place_ring(mi: MeshInstance3D, centre: Vector3, across: Vector3, up: Vector3, normal: Vector3, size: Vector2) -> void:
	# The tube is 0.1 deep, so this makes the strap about 2 cm wide.
	mi.transform = Transform3D(Basis(across * size.x, normal * 0.2, up * size.y), centre)


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
