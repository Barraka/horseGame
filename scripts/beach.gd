extends Node3D
## The beach on the east side of the world (see world.gd): the sea with
## waves washing up the sand, palms on the dunes, rocks and driftwood, and
## the three places to find there: Seashell Cove, the Old Shipwreck in the
## shallows and Lighthouse Point. Seagulls glide overhead. explore.gd adds
## their name boards and discovers them.

const World := preload("res://scripts/world.gd")
const Trees := preload("res://scripts/trees.gd")
const Rocks := preload("res://scripts/rocks.gd")
const BEACH_ENDS := 178.0     ## The sand runs between z = -178 and 178
const PALM_VARIANTS := 4
const GULLS := 7

@export var world_path: NodePath

var _world: World
var _rng := RandomNumberGenerator.new()
var _lamp: Node3D             # The lighthouse's turning lamp
var _lamp_glow: StandardMaterial3D
var _gulls: Array[Node3D] = []
var _time := 0.0


func _ready() -> void:
	_world = get_node(world_path)
	_rng.seed = 21
	_build_sea()
	_build_palms()
	_build_shore_rocks()
	_build_driftwood()
	for place in World.PLACES:
		var spot := _ground(place.pos)
		match place.id:
			"cove": _build_cove(spot)
			"wreck": _build_wreck(spot)
			"lighthouse": _build_lighthouse(spot)
	_build_gulls()


func _process(delta: float) -> void:
	_time += delta
	if _lamp:
		_lamp.rotation.y += delta * 0.8
		var sky := get_node_or_null("../SkyCycle")
		var night: float = 1.0 - sky.daylight() if sky else 0.0
		_lamp_glow.emission_energy_multiplier = lerpf(1.2, 6.0, night)
		_lamp.visible = night > 0.2
	for i in _gulls.size():
		var gull := _gulls[i]
		var circle: Vector3 = gull.get_meta("centre")
		var r: float = gull.get_meta("radius")
		var a: float = _time * gull.get_meta("speed") + i * 1.7
		gull.position = circle + Vector3(cos(a) * r, sin(a * 1.3) * 1.2, sin(a) * r)
		gull.rotation.y = -a + (PI if gull.get_meta("speed") > 0.0 else 0.0)
		gull.rotation.z = 0.25 * signf(gull.get_meta("speed"))
		# Wings flap now and then between long glides.
		var flap: float = sin(_time * 9.0 + i) * maxf(0.0, sin(_time * 0.7 + i * 2.0))
		gull.get_child(0).rotation.z = 0.15 + flap * 0.5
		gull.get_child(1).rotation.z = -0.15 - flap * 0.5


func _ground(pos: Vector2) -> Vector3:
	return Vector3(pos.x, _world.height_at(pos.x, pos.y), pos.y)


# --- Sea, palms, rocks ------------------------------------------------------------

func _build_sea() -> void:
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1800, 2400)
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	sea.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/sea.gdshader")
	mat.set_shader_parameter("sand_slope", World.SAND_SLOPE)
	mat.set_shader_parameter("floor_slope", World.SEA_FLOOR_SLOPE)
	sea.material_override = mat
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# From just inland of the shore far out to the horizon.
	sea.position = Vector3(175.0 + 900.0, World.SEA_LEVEL, 0)
	add_child(sea)


## Palms in loose groups along the top of the beach, leaning every which way.
func _build_palms() -> void:
	var meshes: Array[Mesh] = []
	for v in PALM_VARIANTS:
		meshes.append(Trees.grow("palm", 500 + v))
	var spots: Array[Array] = []
	for v in PALM_VARIANTS:
		spots.append([])
	var z := -BEACH_ENDS + 6.0
	while z < BEACH_ENDS - 6.0:
		var group := _rng.randi_range(1, 4)
		for i in group:
			var zz := z + _rng.randf_range(-5.0, 5.0)
			var x := World.coast_x(zz) - _rng.randf_range(14.0, World.BEACH_WIDTH + 4.0)
			if _near_place(x, zz, 12.0) or _world.trail_at(x, zz) > 0.0:
				continue
			spots[_rng.randi() % PALM_VARIANTS].append(Vector3(x, _world.height_at(x, zz) - 0.1, zz))
		z += _rng.randf_range(10.0, 22.0)
	for v in PALM_VARIANTS:
		if spots[v].is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = meshes[v]
		mm.instance_count = spots[v].size()
		for i in mm.instance_count:
			var s := _rng.randf_range(0.85, 1.2)
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), spots[v][i]))
			var tint := _rng.randf_range(0.9, 1.08)
			mm.set_instance_color(i, Color(tint, tint, tint))
		var palms := MultiMeshInstance3D.new()
		palms.name = "Palms_%d" % v
		palms.multimesh = mm
		add_child(palms)
		for spot in spots[v]:
			_solid(Vector3(0.5, 3.0, 0.5), spot + Vector3(0, 1.5, 0))


func _near_place(x: float, z: float, distance: float) -> bool:
	for place in World.PLACES:
		if Vector2(x, z).distance_to(place.pos) < distance:
			return true
	return false


## Dark wet rocks here and there at the water's edge, in little groups.
func _build_shore_rocks() -> void:
	for i in 14:
		var zz := _rng.randf_range(-BEACH_ENDS, BEACH_ENDS)
		var x := World.coast_x(zz) + _rng.randf_range(-3.0, 6.0)
		if _near_place(x, zz, 18.0):
			continue
		for k in _rng.randi_range(1, 3):
			var p := Vector2(x + _rng.randf_range(-2.5, 2.5), zz + _rng.randf_range(-2.5, 2.5))
			var size := _rng.randf_range(0.6, 1.6) if k > 0 else _rng.randf_range(1.4, 2.4)
			_rock(900 + i * 5 + k, Vector3(1.3, 0.7, 1.0), _ground(p) - Vector3(0, size * 0.25, 0), _rng.randf() * TAU, size)


## Sun-bleached logs washed up on the sand.
func _build_driftwood() -> void:
	var wood := _material(Color(0.72, 0.66, 0.58), 0.95)
	for i in 10:
		var zz := _rng.randf_range(-BEACH_ENDS, BEACH_ENDS)
		var x := World.coast_x(zz) - _rng.randf_range(4.0, 12.0)
		if _near_place(x, zz, 14.0):
			continue
		var length := _rng.randf_range(1.6, 3.2)
		var log := _add(_cylinder(0.12, 0.17, length, 7), wood, _ground(Vector2(x, zz)) + Vector3(0, 0.1, 0))
		log.rotation = Vector3(PI * 0.5, _rng.randf() * TAU, 0.0)
		var branch := _add(_cylinder(0.04, 0.07, length * 0.4, 5), wood, Vector3(0.1, length * 0.15, 0), log)
		branch.rotation.z = 0.8


# --- Places -----------------------------------------------------------------------

## Seashell Cove: a little bay ringed by rocks, its sand scattered with
## shells and starfish, with a rock pool and a beach hut.
func _build_cove(spot: Vector3) -> void:
	# A curved ridge of rocks behind the cove, open to the sea.
	for i in 13:
		var a := lerpf(-1.25, 1.25, i / 12.0) + PI
		var p := Vector2(spot.x, spot.z) + Vector2(cos(a), sin(a)) * _rng.randf_range(12.0, 14.0)
		var size := _rng.randf_range(1.6, 2.8)
		_rock(700 + i, Vector3(1.2, 1.0, 1.0), _ground(p) - Vector3(0, size * 0.3, 0), a, size)
		_solid(Vector3(size * 1.6, size * 1.4, size * 1.6), _ground(p) + Vector3(0, size * 0.3, 0))
	# A rock pool with a starfish in it.
	var pool := _ground(Vector2(spot.x - 4.0, spot.z + 6.0))
	for i in 8:
		var a := i * TAU / 8.0
		_rock(760 + i, Vector3(1.0, 0.6, 1.0), pool + Vector3(cos(a) * 1.6, -0.15, sin(a) * 1.6), a, 0.6)
	var water := _material(Color(0.3, 0.7, 0.75, 0.75), 0.05)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_add(_cylinder(1.5, 1.5, 0.04, 20), water, pool + Vector3(0, 0.08, 0))
	_starfish(pool + Vector3(0.3, 0.02, -0.2), Color(1.0, 0.45, 0.3))
	# Shells and starfish on the sand.
	var shell_colors := [Color(1.0, 0.82, 0.8), Color(0.98, 0.94, 0.86), Color(1.0, 0.7, 0.55), Color(0.85, 0.75, 0.95)]
	for i in 26:
		var a := _rng.randf() * TAU
		var p := Vector2(spot.x, spot.z) + Vector2(cos(a), sin(a)) * _rng.randf_range(1.0, 10.0)
		var at := _ground(p)
		if i % 6 == 0:
			_starfish(at + Vector3(0, 0.02, 0), [Color(1.0, 0.45, 0.3), Color(0.95, 0.65, 0.2), Color(0.85, 0.35, 0.55)][i % 3])
		else:
			var shell := make_shell(shell_colors[i % shell_colors.size()])
			shell.position = at + Vector3(0, 0.03, 0)
			shell.rotation = Vector3(-0.2, _rng.randf() * TAU, 0)
			add_child(shell)
	# A striped beach hut on stilts, and a sun umbrella.
	var hut := Node3D.new()
	hut.position = _ground(Vector2(spot.x - 9.0, spot.z - 7.0))
	hut.rotation.y = -PI * 0.5
	add_child(hut)
	var wood := _material(Color(0.95, 0.93, 0.88))
	var stripe := _material(Color(0.3, 0.65, 0.85))
	for x in [-1.1, 1.1]:
		for z2 in [-0.9, 0.9]:
			_add(_box(Vector3(0.14, 0.6, 0.14)), wood, Vector3(x, 0.3, z2), hut)
	_add(_box(Vector3(2.4, 2.0, 2.0)), wood, Vector3(0, 1.6, 0), hut)
	for k in 5:
		_add(_box(Vector3(0.24, 2.0, 2.02)), stripe, Vector3(-1.0 + k * 0.5, 1.6, 0), hut)
	var roof := _add(_box(Vector3(2.8, 0.14, 2.5)), _material(Color(0.85, 0.3, 0.3)), Vector3(0, 2.7, 0), hut)
	roof.rotation.z = 0.12
	_add(_box(Vector3(0.9, 1.4, 0.06)), _material(Color(0.95, 0.75, 0.3)), Vector3(0, 1.4, 1.02), hut)
	_solid(Vector3(2.6, 3.0, 2.2), hut.position + Vector3(0, 1.5, 0), hut.rotation.y)
	var umbrella := _ground(Vector2(spot.x + 2.0, spot.z - 4.0))
	_add(_cylinder(0.04, 0.04, 2.4, 6), wood, umbrella + Vector3(0, 1.2, 0))
	var canopy := _material(Color(1.0, 0.55, 0.35))
	canopy.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add(_cylinder(0.05, 1.5, 0.5, 12), canopy, umbrella + Vector3(0, 2.3, 0))
	_add(_box(Vector3(0.9, 0.04, 1.8)), _material(Color(0.4, 0.75, 0.9)), umbrella + Vector3(0.6, 0.03, -1.4))


## The Old Shipwreck: a wooden hull lying heeled over in the shallows,
## with a hole stove in its side, ribs showing through, and a snapped mast.
func _build_wreck(spot: Vector3) -> void:
	var plank := _material(Color(0.45, 0.32, 0.22), 0.9)
	plank.cull_mode = BaseMaterial3D.CULL_DISABLED
	var dark := _material(Color(0.3, 0.21, 0.15), 0.9)
	var ship := Node3D.new()
	ship.position = Vector3(spot.x, World.SEA_LEVEL + 1.3, spot.z)
	ship.rotation = Vector3(0.05, 0.5, 0.42)   # Heeled over
	add_child(ship)
	var length := 16.0
	var width := 2.8
	var depth := 2.6
	# The hull: cross-sections along its length (a U that narrows to a
	# point at the bow and less so at the stern), joined into planked sides.
	var rows := 24
	var around := 12
	var hull := SurfaceTool.new()
	hull.begin(Mesh.PRIMITIVE_TRIANGLES)
	var point := func(i: int, k: int) -> Vector3:
		var t := i / float(rows)
		var z := lerpf(-length * 0.5, length * 0.5, t)
		var w := width * pow(sin(lerpf(0.18, 1.0, t) * PI * 0.5 + (1.0 - t) * 0.6), 0.7) * (1.0 - pow(t, 6.0))
		var a := lerpf(-PI * 0.5, PI * 0.5, k / float(around))
		return Vector3(w * sin(a), depth * (1.0 - cos(a)) - depth + 0.4 * t * t, z)
	for i in rows:
		for k in around:
			# A hole stove in the upper side, amidships.
			if k >= around - 4 and k < around - 1 and i >= 9 and i < 14:
				continue
			var shade := 0.85 + 0.15 * float((i * 7 + k * 3) % 5) / 4.0
			var quad := [point.call(i, k), point.call(i, k + 1), point.call(i + 1, k + 1), point.call(i + 1, k)]
			var normal: Vector3 = (quad[1] - quad[0]).cross(quad[3] - quad[0]).normalized()
			for c in [0, 1, 2, 0, 2, 3]:
				hull.set_color(Color(shade, shade, shade))
				hull.set_normal(normal)
				hull.set_uv(Vector2(k / float(around), i / float(rows)))
				hull.add_vertex(quad[c])
	plank.vertex_color_use_as_albedo = true
	_add(hull.commit(), plank, Vector3.ZERO, ship)
	# Ribs showing through the hole, a rail along the top edges, and the keel.
	for i in range(8, 16):
		var top_l: Vector3 = point.call(i, around)
		var mid: Vector3 = point.call(i, around - 3)
		var rib := _add(_box(Vector3(0.14, top_l.distance_to(mid), 0.14)), dark, (top_l + mid) * 0.5, ship)
		rib.rotation.z = atan2(-(top_l - mid).x, (top_l - mid).y)
	for side in [0, around]:
		for i in rows:
			var a: Vector3 = point.call(i, side)
			var b: Vector3 = point.call(i + 1, side)
			var rail := _add(_box(Vector3(0.16, 0.16, a.distance_to(b) + 0.05)), dark, (a + b) * 0.5, ship)
			rail.look_at_from_position(rail.position, rail.position + (b - a), Vector3.UP)
	# The bow's stem post, a snapped mast with a torn flag, and a broken spar.
	var stem := _add(_box(Vector3(0.3, 3.0, 0.3)), dark, Vector3(0, 0.6, length * 0.5 + 0.2), ship)
	stem.rotation.x = 0.4
	var mast := _add(_cylinder(0.18, 0.22, 5.0, 8), dark, Vector3(0, 1.4, -1.5), ship)
	mast.rotation.x = -0.15
	var spar := _add(_cylinder(0.1, 0.1, 3.4, 6), dark, Vector3(0, 1.4, 0), mast)
	spar.rotation.z = PI * 0.5 + 0.3
	var flag := _material(Color(0.88, 0.86, 0.8))
	flag.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cloth := _add(_box(Vector3(0.02, 1.1, 1.5)), flag, Vector3(0, 1.8, -0.8), mast)
	cloth.rotation.x = 0.25
	# A barrel and a treasure chest washed up on the sand nearby.
	var barrel := _add(_cylinder(0.35, 0.35, 0.8, 12), plank, _ground(Vector2(spot.x - 9.0, spot.z + 3.0)) + Vector3(0, 0.25, 0))
	barrel.rotation = Vector3(PI * 0.5, 0.7, 0)
	var chest := _add(_box(Vector3(0.9, 0.55, 0.6)), dark, _ground(Vector2(spot.x - 10.0, spot.z - 2.0)) + Vector3(0, 0.25, 0))
	chest.rotation.y = 0.4
	_add(_box(Vector3(0.95, 0.08, 0.65)), _material(Color(0.85, 0.7, 0.3), 0.4), Vector3(0, 0.2, 0), chest)
	_solid(Vector3(6.0, 3.0, length), Vector3(spot.x, World.SEA_LEVEL + 1.0, spot.z), 0.5)


## Lighthouse Point: a white and red striped lighthouse on a rocky point,
## with a lamp that turns and shines at night, and the keeper's cottage.
func _build_lighthouse(spot: Vector3) -> void:
	for i in 16:
		var a := i * TAU / 16.0
		var r := _rng.randf_range(3.0, 6.5)
		var size := _rng.randf_range(1.8, 3.2)
		_rock(800 + i, Vector3(1.2, 0.9, 1.1), spot + Vector3(cos(a) * r, -size * 0.35, sin(a) * r), a, size)
	var base := spot + Vector3(0, 0.6, 0)
	var white := _material(Color(0.96, 0.96, 0.94), 0.6)
	var red := _material(Color(0.85, 0.18, 0.16), 0.6)
	_add(_cylinder(2.6, 2.9, 1.2, 24), _material(Color(0.62, 0.6, 0.56)), base)
	# The tower in bands, narrowing as it rises.
	var bands := 6
	for i in bands:
		var t0 := i / float(bands)
		var t1 := (i + 1) / float(bands)
		var r0 := lerpf(2.0, 1.25, t0)
		var r1 := lerpf(2.0, 1.25, t1)
		_add(_cylinder(r1, r0, 2.2, 24), red if i % 2 == 1 else white, base + Vector3(0, 0.6 + 2.2 * (i + 0.5), 0))
	var top := base + Vector3(0, 0.6 + 2.2 * bands, 0)
	var iron := _material(Color(0.15, 0.15, 0.17), 0.5)
	_add(_cylinder(1.9, 1.9, 0.2, 24), iron, top + Vector3(0, 0.1, 0))
	for i in 20:
		var a := i * TAU / 20.0
		_add(_cylinder(0.03, 0.03, 0.9, 4), iron, top + Vector3(cos(a) * 1.8, 0.65, sin(a) * 1.8))
	var rail := TorusMesh.new()
	rail.inner_radius = 1.76
	rail.outer_radius = 1.84
	rail.rings = 32
	_add(rail, iron, top + Vector3(0, 1.1, 0))
	var glass := _material(Color(0.85, 0.9, 0.85, 0.35), 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_add(_cylinder(1.0, 1.0, 1.6, 16), glass, top + Vector3(0, 1.0, 0))
	_add(_cylinder(0.1, 1.3, 1.0, 16), red, top + Vector3(0, 2.3, 0))
	_add(_sphere(0.2), iron, top + Vector3(0, 2.9, 0))
	# The lamp: a glowing bulb with two soft beams sweeping round at night.
	_lamp_glow = _material(Color(1.0, 0.92, 0.6))
	_lamp_glow.emission_enabled = true
	_lamp_glow.emission = Color(1.0, 0.9, 0.55)
	_add(_sphere(0.4), _lamp_glow, top + Vector3(0, 1.0, 0))
	_lamp = Node3D.new()
	_lamp.position = top + Vector3(0, 1.0, 0)
	add_child(_lamp)
	var beam := StandardMaterial3D.new()
	beam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.albedo_color = Color(1.0, 0.85, 0.45, 0.1)
	beam.disable_fog = true
	for side in [-1.0, 1.0]:
		# Narrow at the lamp, widening as it goes.
		var ray := _add(_cylinder(0.3, 1.8, 28.0, 12), beam, Vector3(side * 14.0, 0, 0), _lamp)
		ray.rotation.z = side * PI * 0.5
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.9, 0.6)
	light.omni_range = 14.0
	light.light_energy = 1.5
	_lamp.add_child(light)
	_solid(Vector3(4.4, 16.0, 4.4), base + Vector3(0, 8.0, 0))
	# The keeper's cottage, a little way back from the point.
	var cottage := Node3D.new()
	cottage.position = _ground(Vector2(spot.x - 12.0, spot.z + 9.0))
	cottage.rotation.y = 0.4
	add_child(cottage)
	_add(_box(Vector3(4.0, 2.4, 3.2)), white, Vector3(0, 1.1, 0), cottage)
	for side in [-1.0, 1.0]:
		var slope := _add(_box(Vector3(4.4, 0.14, 2.0)), red, Vector3(0, 2.75, side * 0.85), cottage)
		slope.rotation.x = side * 0.6
	_add(_box(Vector3(0.9, 1.6, 0.06)), _material(Color(0.3, 0.45, 0.7)), Vector3(0.6, 0.8, 1.62), cottage)
	_add(_box(Vector3(0.7, 0.6, 0.06)), _material(Color(0.6, 0.75, 0.85), 0.2), Vector3(-1.0, 1.4, 1.62), cottage)
	_solid(Vector3(4.2, 3.0, 3.4), cottage.position + Vector3(0, 1.5, 0), cottage.rotation.y)


# --- Gulls --------------------------------------------------------------------------

## Seagulls circling lazily over the beach and the sea.
func _build_gulls() -> void:
	var white := _material(Color(0.96, 0.96, 0.95), 0.8)
	var grey := _material(Color(0.6, 0.62, 0.66), 0.8)
	for i in GULLS:
		var gull := Node3D.new()
		var zz := _rng.randf_range(-150.0, 150.0)
		gull.set_meta("centre", Vector3(World.coast_x(zz) + _rng.randf_range(-6.0, 20.0), _rng.randf_range(9.0, 15.0), zz))
		gull.set_meta("radius", _rng.randf_range(8.0, 16.0))
		gull.set_meta("speed", _rng.randf_range(0.18, 0.3) * (1.0 if i % 2 == 0 else -1.0))
		add_child(gull)
		for side in [-1.0, 1.0]:
			var wing := Node3D.new()
			gull.add_child(wing)
			var feather := _add(_box(Vector3(0.75, 0.03, 0.22)), grey, Vector3(side * 0.38, 0, 0), wing)
			feather.rotation.y = side * 0.15
		_add(_sphere(0.12), white, Vector3.ZERO, gull).scale = Vector3(1.0, 0.9, 2.4)
		_gulls.append(gull)


# --- Pieces -----------------------------------------------------------------------

## A little fan-shaped seashell (also used for Marina's quest).
static func make_shell(color: Color) -> Node3D:
	var shell := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.45
	var body := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 0.16
	dome.height = 0.16
	dome.is_hemisphere = true
	dome.radial_segments = 10
	dome.rings = 4
	body.mesh = dome
	body.material_override = mat
	body.scale = Vector3(1.0, 0.7, 0.85)
	shell.add_child(body)
	var ridge := StandardMaterial3D.new()
	ridge.albedo_color = color.darkened(0.25)
	for k in 5:
		var rib := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.02, 0.03, 0.17)
		rib.mesh = box
		rib.material_override = ridge
		rib.rotation.y = (k - 2) * 0.32
		rib.position = Vector3(sin((k - 2) * 0.32) * 0.07, 0.07, cos((k - 2) * 0.32) * 0.07 - 0.03)
		shell.add_child(rib)
	return shell


func _starfish(at: Vector3, color: Color) -> void:
	var mat := _material(color, 0.8)
	for k in 5:
		var arm := _add(_cylinder(0.02, 0.06, 0.22, 5), mat, at, self)
		arm.rotation = Vector3(PI * 0.5, k * TAU / 5.0, 0)
		arm.translate_object_local(Vector3(0, 0.11, 0))


func _material(color: Color, roughness := 0.85) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat


func _add(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D = self) -> MeshInstance3D:
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
	return mesh


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return mesh


func _rock(seed: int, stretch: Vector3, pos: Vector3, yaw: float, size: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Rocks.grow(seed, stretch, 0.22, 3)
	mi.position = pos
	mi.rotation.y = yaw
	mi.scale = Vector3.ONE * size
	add_child(mi)
	return mi


## A solid block the horse bumps into instead of walking through.
func _solid(size: Vector3, pos: Vector3, yaw := 0.0) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	body.rotation.y = yaw
	add_child(body)
