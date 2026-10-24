@tool
extends Node3D
## Builds the countryside: rolling grassy terrain, a sand riding arena,
## a trail looping past a lake and other places to discover, trees, rocks,
## swaying grass (grass.gd) and drifts of wildflowers. Hills rise at the
## edges to close it in, the sea lies to the east and snowy mountains lie
## beyond a pass to the north.
## Everything is generated from a seed, so the world looks the same every
## time. It also runs in the editor; reopen the scene to see changes to
## the settings below. The places themselves are built by explore.gd.

@export var world_seed := 7
@export var size := 480.0              ## Terrain width and depth in metres
@export var cell := 2.0                ## Terrain grid spacing in metres
@export var hill_height := 9.0
@export var arena_center := Vector3(0, 0, -35)
@export var arena_size := Vector2(56, 66)   ## Width (x) and length (z)
@export var tree_count := 560
@export var rock_count := 240   ## In groups of two to five
@export var flower_count := 20000   ## Tries; most land outside the drifts

## Places to find while exploring, as (x, z) positions. "the" goes before
## the name in messages ("You found the Old Windmill!").
const PLACES := [
	{"id": "lake",     "name": "Sparkle Lake",      "pos": Vector2(95, 70)},
	{"id": "flowers",  "name": "Flower Valley",     "pos": Vector2(20, 168)},
	{"id": "stones",   "name": "Stone Circle", "the": true,      "pos": Vector2(-72, 152)},
	{"id": "windmill", "name": "Old Windmill", "the": true,      "pos": Vector2(-128, 40)},
	{"id": "lookout",  "name": "Hilltop Lookout", "the": true,   "pos": Vector2(-152, -142)},
	{"id": "wild",     "name": "Wild Horse Meadow", "the": true, "pos": Vector2(128, -118)},
	{"id": "cove",     "name": "Seashell Cove",     "pos": Vector2(184, -36)},
	{"id": "wreck",    "name": "Old Shipwreck", "the": true,     "pos": Vector2(204, 82)},
	{"id": "lighthouse", "name": "Lighthouse Point",  "pos": Vector2(188, -152)},
	{"id": "frozen_lake", "name": "Frozen Lake", "the": true,  "pos": Vector2(12, -338), "reach": 26.0},
	{"id": "hut",      "name": "Mountain Hut", "the": true,      "pos": Vector2(-46, -298)},
	{"id": "falls",    "name": "Frozen Falls", "the": true,      "pos": Vector2(44, -392)},
]
const LAKE_CENTER := Vector2(95, 70)
const LAKE_RADIUS := 30.0
const WATER_LEVEL := 1.0
const LAKE_SHORE := 1.6        ## Height of the flat ground around the lake
const HILL_HEIGHT := 14.0      ## Extra height of the lookout's hill
const EDGE_HEIGHT := 20.0      ## How high the hills at the world's edge rise
## The trail: a loop from the arena past every place, smoothed into a curve.
const TRAIL := [
	Vector2(0, 14), Vector2(30, 28), Vector2(56, 52), Vector2(58, 92), Vector2(42, 135),
	Vector2(22, 155), Vector2(-20, 168), Vector2(-60, 140), Vector2(-98, 98), Vector2(-122, 58),
	Vector2(-136, 0), Vector2(-148, -62), Vector2(-142, -125), Vector2(-100, -152), Vector2(-40, -132),
	Vector2(20, -118), Vector2(70, -122), Vector2(114, -104), Vector2(140, -52), Vector2(124, 0),
	Vector2(78, 16), Vector2(36, 12),
]
## A path off the trail down to the beach, and along the sand.
const BEACH_PATH := [
	Vector2(128, -6), Vector2(146, -12), Vector2(160, -4), Vector2(172, -2),
]
## A path off the trail north, up through the pass into the mountains.
const MOUNTAIN_PATH := [
	Vector2(-40, -132), Vector2(-34, -160), Vector2(-26, -190), Vector2(-21, -212), Vector2(-20, -238),
]
const TRAIL_WIDTH := 3.0
## The snowy mountains beyond the hills to the north: a valley reached
## through a pass, with the Frozen Lake, the Mountain Hut and the Frozen
## Falls, and peaks all round. Snow starts at SNOW_LINE (z) and covers
## everything past SNOW_FULL. mountains.gd builds the places.
const SNOW_LINE := -212.0
const SNOW_FULL := -246.0
const PASS_X := -20.0              ## Where the pass cuts through the hills
const MOUNTAINS_END := -440.0      ## The far edge of the mountain land
const MOUNTAIN_HEIGHT := 70.0      ## How high the peaks rise above the valley
const ICE_RADIUS := 26.0           ## The Frozen Lake
const ICE_LEVEL := 21.0
## The snowy track through the valley, marked with poles: from the pass to
## the hut, the lake and the falls.
const SNOW_TRACK := [
	Vector2(-20, -238), Vector2(-24, -262), Vector2(-40, -286), Vector2(-30, -306),
	Vector2(-14, -318), Vector2(10, -306), Vector2(38, -322), Vector2(44, -350), Vector2(42, -378),
]
const SNOW := Color(0.86, 0.89, 0.95)
const SNOW_SHADE := Color(0.64, 0.71, 0.85)
const SNOW_TRACK_COLOR := Color(0.74, 0.74, 0.76)
const MOUNTAIN_ROCK := Color(0.36, 0.35, 0.38)
## The beach along the east side: dunes, then sand sloping down into the
## sea. The coast curves gently (coast_x); the edge hills run out into the
## sea at both ends as headlands.
const SEA_LEVEL := 0.4
const BEACH_WIDTH := 30.0          ## Sand from the dunes to the water's edge
const SAND_SLOPE := 0.05           ## How fast the beach rises from the water
const SEA_FLOOR_SLOPE := 0.06
const SAND_DRY := Color(0.76, 0.65, 0.46)
const SAND_LIGHT := Color(0.84, 0.74, 0.55)
const SAND_WET := Color(0.55, 0.46, 0.34)
const TREE_VARIANTS := 3           ## Different-looking trees of each kind
const PLANTING_SQUARE := 120.0     ## Trees are drawn in squares this big, so ones out of view are skipped
const ROCK_VARIANTS := 6
const Trees := preload("res://scripts/trees.gd")
const Rocks := preload("res://scripts/rocks.gd")
const GRASS_DARK := Color(0.2, 0.44, 0.12)
const GRASS_LIGHT := Color(0.47, 0.66, 0.2)
const TRAIL_DARK := Color(0.56, 0.44, 0.3)
const TRAIL_LIGHT := Color(0.7, 0.58, 0.42)
const LAKE_BED := Color(0.42, 0.4, 0.3)

var noise := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var ridges := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()
var trail_points := PackedVector2Array()   ## The trail's centre line, a point every metre
var _trail_mask := PackedFloat32Array()    ## 1 on the trail, fading to 0, on a 1 m grid
var _ground_material: ShaderMaterial
var _plantings := {}               ## [tree mesh key, square] -> [transforms, colours]
var _flower_material: ShaderMaterial
var _tree_meshes := {}             ## "kind:variant" -> Mesh


func _ready() -> void:
	noise.seed = world_seed
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	detail.seed = world_seed + 1
	detail.frequency = 0.08
	ridges.seed = world_seed + 5
	ridges.frequency = 0.011
	ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridges.fractal_octaves = 4
	rng.seed = world_seed
	_build_trail()
	_build_terrain()
	_build_arena()
	_scatter_trees()
	_scatter_mountain_trees()
	_scatter_bushes()
	_scatter_rocks()
	_build_plantings()
	_build_flower_beds()
	_scatter_grass()
	_scatter_flowers()


## Ground height at a point. The area around the arena and the spawn
## point is kept flat; hills rise further out.
func height_at(x: float, z: float) -> float:
	var to_arena := Vector2(x - arena_center.x, z - arena_center.z)
	var flat_radius := arena_size.length() * 0.5 + 6.0
	var mask := smoothstep(flat_radius, flat_radius + 40.0, to_arena.length())
	var h := (noise.get_noise_2d(x, z) * 0.5 + 0.5) * hill_height
	h += detail.get_noise_2d(x, z) * 0.4
	h *= mask
	# A big hill for the lookout.
	var lookout: Vector2 = PLACES[4].pos
	h += HILL_HEIGHT * exp(-Vector2(x, z).distance_squared_to(lookout) / (34.0 * 34.0))
	# Hills closing in the edges of the world, except the east, which opens
	# onto the beach.
	var hills := EDGE_HEIGHT * smoothstep(size * 0.5 - 55.0, size * 0.5 - 5.0, absf(z))
	if z < 0.0:   # The pass through the north hills
		hills *= 1.0 - exp(-pow(x - PASS_X, 2.0) / (24.0 * 24.0))
	h += maxf(EDGE_HEIGHT * smoothstep(size * 0.5 - 55.0, size * 0.5 - 5.0, -x), hills)
	# The beach: sand sloping gently into the sea, with the end hills as headlands.
	var shore := shore_distance(x, z)
	if shore < BEACH_WIDTH + 40.0:
		var beach := SEA_LEVEL + (shore * SAND_SLOPE if shore > 0.0 else maxf(shore, -30.0) * SEA_FLOOR_SLOPE)
		if shore > BEACH_WIDTH * 0.6:
			beach += smoothstep(BEACH_WIDTH * 0.6, BEACH_WIDTH, shore) * (0.5 + detail.get_noise_2d(x * 0.6, z * 0.6) * 0.5)
		beach = minf(beach, SEA_LEVEL + BEACH_WIDTH * SAND_SLOPE + 1.0)
		h = lerpf(h, beach + hills, smoothstep(BEACH_WIDTH + 40.0, BEACH_WIDTH + 4.0, shore))
	# The lake: flat shore, then a shallow bowl the horse can wade into.
	var d := Vector2(x, z).distance_to(LAKE_CENTER)
	if d < LAKE_RADIUS + 28.0:
		h = lerpf(LAKE_SHORE, h, smoothstep(LAKE_RADIUS + 4.0, LAKE_RADIUS + 28.0, d))
		if d < LAKE_RADIUS + 4.0:
			var bowl := LAKE_SHORE - 1.5 * (1.0 - smoothstep(LAKE_RADIUS * 0.3, LAKE_RADIUS + 4.0, d))
			h = minf(h, bowl)
	# Past the pass, the mountains.
	var snowy := smoothstep(SNOW_LINE + 12.0, SNOW_FULL, z)
	if snowy > 0.0:
		h = lerpf(h, _mountain_height(x, z), snowy)
	return h


## The mountain land: a valley climbing from the pass, with a flat frozen
## lake, and steep ridged peaks on both sides and at the far end.
func _mountain_height(x: float, z: float) -> float:
	var middle := lerpf(PASS_X, 0.0, smoothstep(-236.0, -300.0, z))
	var half := lerpf(18.0, 80.0, smoothstep(-232.0, -292.0, z)) * (1.0 - 0.3 * smoothstep(-360.0, -410.0, z))
	var across := absf(x - middle)
	var ground := 4.0 + 17.0 * smoothstep(-225.0, -322.0, z)
	ground += (noise.get_noise_2d(x * 1.6, z * 1.6) * 0.5 + 0.5) * 3.0 + detail.get_noise_2d(x, z) * 0.35
	var rise := maxf(smoothstep(half, half + 60.0, across), smoothstep(-392.0, -428.0, z))
	var peaks := MOUNTAIN_HEIGHT * (0.55 + 0.6 * (ridges.get_noise_2d(x, z) * 0.5 + 0.5))
	peaks *= lerpf(0.4, 1.0, 1.0 - smoothstep(175.0, 236.0, absf(x)))   # Lower out towards the sea
	var h := ground + peaks * pow(rise, 1.4)
	# The frozen lake: flat ice, with a gentle bank around it.
	var lake: Vector2 = PLACES[9].pos
	var d := Vector2(x, z).distance_to(lake)
	if d < ICE_RADIUS + 16.0:
		h = lerpf(ICE_LEVEL, h, smoothstep(ICE_RADIUS + 2.0, ICE_RADIUS + 16.0, d))
	return h


## How snowy a spot is: 0 below the snow line, 1 in the mountains.
static func snow_at(x: float, z: float) -> float:
	return smoothstep(SNOW_LINE, SNOW_FULL, z)


func is_on_ice(x: float, z: float, margin := 0.0) -> bool:
	return Vector2(x, z).distance_to(PLACES[9].pos) < ICE_RADIUS + margin


## How far a point is from the snowy track's centre line.
func snow_track_distance(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := INF
	for i in SNOW_TRACK.size() - 1:
		var a: Vector2 = SNOW_TRACK[i]
		var b: Vector2 = SNOW_TRACK[i + 1]
		var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a.lerp(b, t)))
	return best


## Where the sea meets the sand, along the east side, at `z`.
static func coast_x(z: float) -> float:
	return 194.0 + 6.0 * sin(z * 0.023) + 3.0 * sin(z * 0.071 + 1.3)


## How far inland from the water's edge a point is (negative out at sea).
func shore_distance(x: float, z: float) -> float:
	return coast_x(z) - x


## On the beach (sand or sea), give or take `margin` metres.
func is_beach(x: float, z: float, margin := 0.0) -> bool:
	return shore_distance(x, z) < BEACH_WIDTH + margin


## The ground's painted colour at a point: grass in two greens, the trail
## in sandy browns, the lake bed, sand, and snow and rock in the mountains. The grass blades take it too.
func ground_color(x: float, z: float) -> Color:
	var t := clampf(detail.get_noise_2d(x * 0.5, z * 0.5) * 0.8 + 0.5, 0.0, 1.0)
	var color := GRASS_DARK.lerp(GRASS_LIGHT, t)
	color = color.lerp(TRAIL_DARK.lerp(TRAIL_LIGHT, t), trail_at(x, z))
	var shore := shore_distance(x, z)
	if shore < BEACH_WIDTH + 8.0:
		var sand := SAND_DRY.lerp(SAND_LIGHT, t).lerp(SAND_WET, 1.0 - smoothstep(-1.0, 5.0, shore))
		var amount := 1.0 - smoothstep(BEACH_WIDTH - 2.0, BEACH_WIDTH + 8.0, shore)
		amount *= 1.0 - smoothstep(SEA_LEVEL + 3.0, SEA_LEVEL + 6.0, height_at(x, z))   # Not up the headlands
		color = color.lerp(sand, amount)
	if is_in_lake(x, z, 2.0):
		color = color.lerp(LAKE_BED, 1.0 - smoothstep(LAKE_RADIUS - 2.0, LAKE_RADIUS + 2.0, Vector2(x, z).distance_to(LAKE_CENTER)))
	var snowy := snow_at(x, z)
	if snowy > 0.0:
		# Snow, bluer in the hollows; grey rock on the steepest slopes, and
		# a trodden track through the valley.
		var h := height_at(x, z)
		var slope := Vector2(height_at(x + 1.5, z) - h, height_at(x, z + 1.5) - h).length() / 1.5
		var snow := SNOW_SHADE.lerp(SNOW, clampf(detail.get_noise_2d(x * 0.3, z * 0.3) * 0.9 + 0.6, 0.0, 1.0))
		var crag := ridges.get_noise_2d(x * 2.0, z * 2.0) * 0.5 + 0.5
		snow = snow.lerp(MOUNTAIN_ROCK.lerp(SNOW_SHADE, t * 0.3), smoothstep(0.55, 0.95, slope + (crag - 0.5) * 0.5))
		if z < SNOW_FULL + 20.0:
			snow = snow.lerp(SNOW_TRACK_COLOR, (1.0 - smoothstep(1.2, TRAIL_WIDTH, snow_track_distance(x, z))) * 0.8)
		# Patches of grass poke through near the snow line.
		var patchy := clampf(snowy * 1.4 - 0.2 + detail.get_noise_2d(x * 0.7, z * 0.7) * 0.6, 0.0, 1.0)
		color = color.lerp(snow, patchy)
	return color


## How much a point is on the trail: 1 in the middle, 0 off it.
func trail_at(x: float, z: float) -> float:
	var cells := int(size)
	var xi := int(x + size * 0.5)
	var zi := int(z + size * 0.5)
	if xi < 0 or zi < 0 or xi >= cells or zi >= cells or _trail_mask.is_empty():
		return 0.0
	return _trail_mask[zi * cells + xi]


func is_in_lake(x: float, z: float, margin := 0.0) -> bool:
	return Vector2(x, z).distance_to(LAKE_CENTER) < LAKE_RADIUS + margin


## Somewhere trees and rocks should stay away from.
func is_kept_clear(x: float, z: float, margin: float) -> bool:
	if is_in_arena(x, z, margin) or is_in_lake(x, z, margin + 4.0) or trail_at(x, z) > 0.0 or is_beach(x, z, margin + 2.0):
		return true
	for place in PLACES:
		if Vector2(x, z).distance_to(place.pos) < 16.0 + margin:
			return true
	return false


## Smooth the trail's corners (Catmull-Rom) and paint it into a grid.
func _build_trail() -> void:
	trail_points.clear()
	var n := TRAIL.size()
	for i in n:
		var p0: Vector2 = TRAIL[(i - 1 + n) % n]
		var p1: Vector2 = TRAIL[i]
		var p2: Vector2 = TRAIL[(i + 1) % n]
		var p3: Vector2 = TRAIL[(i + 2) % n]
		var steps := int(p1.distance_to(p2))
		for step in steps:
			var t := float(step) / steps
			trail_points.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
	var cells := int(size)
	_trail_mask = PackedFloat32Array()
	_trail_mask.resize(cells * cells)
	var path := PackedVector2Array()
	for spur in [BEACH_PATH, MOUNTAIN_PATH]:
		for i in spur.size() - 1:
			var a: Vector2 = spur[i]
			var b: Vector2 = spur[i + 1]
			for step in int(a.distance_to(b)):
				path.append(a.lerp(b, step / a.distance_to(b)))
	var reach := int(ceil(TRAIL_WIDTH))
	for point in trail_points + path:
		var cx := int(point.x + size * 0.5)
		var cz := int(point.y + size * 0.5)
		for dz in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var xi := cx + dx
				var zi := cz + dz
				if xi < 0 or zi < 0 or xi >= cells or zi >= cells:
					continue
				var d := Vector2(xi - size * 0.5 + 0.5, zi - size * 0.5 + 0.5).distance_to(point)
				var v := 1.0 - smoothstep(TRAIL_WIDTH * 0.35, TRAIL_WIDTH, d)
				_trail_mask[zi * cells + xi] = maxf(_trail_mask[zi * cells + xi], v)


func is_in_arena(x: float, z: float, margin := 0.0) -> bool:
	return absf(x - arena_center.x) < arena_size.x * 0.5 + margin \
		and absf(z - arena_center.z) < arena_size.y * 0.5 + margin


func _build_terrain() -> void:
	# Soft painted detail on top of the colours: see terrain.gdshader.
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/terrain.gdshader")
	mat.set_shader_parameter("patches", _noise_texture(0.012, 3, 256, false))
	mat.set_shader_parameter("grain", _noise_texture(0.03, 4, 256, false))
	mat.set_shader_parameter("bumps", _noise_texture(0.03, 4, 256, true))
	_ground_material = mat
	var half := size * 0.5
	_build_ground(Rect2(-half, -half, size, size), "Terrain")
	_build_ground(Rect2(-half, MOUNTAINS_END, size, -half - MOUNTAINS_END), "Mountains")
	# Invisible walls on the hills at the edge, so the horse stays in the
	# world: round the countryside, with a gap at the pass, and round the
	# mountains beyond it.
	var edge := size * 0.5 - 20.0
	var back := MOUNTAINS_END + 14.0
	var gap := 22.0
	_wall(Vector2(-size * 0.5, edge), Vector2(size * 0.5, edge))
	_wall(Vector2(-edge, back), Vector2(-edge, size * 0.5))
	_wall(Vector2(214.0, back), Vector2(214.0, size * 0.5))   # The east one stands in the shallow sea
	_wall(Vector2(-size * 0.5, -edge), Vector2(PASS_X - gap, -edge))
	_wall(Vector2(PASS_X + gap, -edge), Vector2(size * 0.5, -edge))
	_wall(Vector2(-size * 0.5, back), Vector2(size * 0.5, back))


## One piece of ground: a mesh painted with ground_color and its collision.
func _build_ground(area: Rect2, node_name: String) -> void:
	var columns := int(area.size.x / cell)
	var rows := int(area.size.y / cell)
	var heights := PackedFloat32Array()
	heights.resize((columns + 1) * (rows + 1))
	for zi in rows + 1:
		for xi in columns + 1:
			heights[zi * (columns + 1) + xi] = height_at(area.position.x + xi * cell, area.position.y + zi * cell)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zi in rows + 1:
		for xi in columns + 1:
			var x := area.position.x + xi * cell
			var z := area.position.y + zi * cell
			st.set_color(ground_color(x, z))
			st.set_uv((Vector2(x, z) + Vector2(size, size) * 0.5) / cell)
			st.add_vertex(Vector3(x, heights[zi * (columns + 1) + xi], z))
	for zi in rows:
		for xi in columns:
			var i := zi * (columns + 1) + xi
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + columns + 1)
			st.add_index(i + 1)
			st.add_index(i + columns + 2)
			st.add_index(i + columns + 1)
	st.generate_normals()

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = _ground_material
	add_child(mesh_instance)

	var shape := HeightMapShape3D.new()
	shape.map_width = columns + 1
	shape.map_depth = rows + 1
	shape.map_data = heights
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.scale = Vector3(cell, 1, cell)
	var body := StaticBody3D.new()
	body.name = node_name + "Body"
	body.position = Vector3(area.get_center().x, 0, area.get_center().y)
	body.add_child(collision)
	add_child(body)


## An invisible wall along a line on the ground.
func _wall(from: Vector2, to: Vector2) -> void:
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(absf(to.x - from.x), 2.0), 200.0, maxf(absf(to.y - from.y), 2.0))
	wall_shape.shape = box
	wall.add_child(wall_shape)
	var middle := (from + to) * 0.5
	wall.position = Vector3(middle.x, 40.0, middle.y)
	add_child(wall)


func _build_arena() -> void:
	# Raked sand: a soft noise pattern between two sand colours.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.62, 0.48, 0.33))
	ramp.set_color(1, Color(0.8, 0.67, 0.5))
	var sand_noise := FastNoiseLite.new()
	sand_noise.frequency = 0.03
	var sand_texture := NoiseTexture2D.new()
	sand_texture.noise = sand_noise
	sand_texture.color_ramp = ramp
	sand_texture.seamless = true
	var sand := StandardMaterial3D.new()
	sand.albedo_texture = sand_texture
	sand.uv1_scale = Vector3(6, 6, 1)
	sand.roughness = 1.0
	var footing := MeshInstance3D.new()
	footing.name = "ArenaSand"
	var plane := PlaneMesh.new()
	plane.size = arena_size
	footing.mesh = plane
	footing.material_override = sand
	footing.position = arena_center + Vector3(0, 0.03, 0)
	add_child(footing)

	# White post-and-rail fence with an opening on the near side.
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.95, 0.95, 0.92)
	var hx := arena_size.x * 0.5
	var hz := arena_size.y * 0.5
	var c := arena_center
	var sides := [
		[Vector3(c.x - hx, 0, c.z - hz), Vector3(c.x + hx, 0, c.z - hz)],
		[Vector3(c.x - hx, 0, c.z - hz), Vector3(c.x - hx, 0, c.z + hz)],
		[Vector3(c.x + hx, 0, c.z - hz), Vector3(c.x + hx, 0, c.z + hz)],
		[Vector3(c.x - hx, 0, c.z + hz), Vector3(c.x - 5, 0, c.z + hz)],
		[Vector3(c.x + 5, 0, c.z + hz), Vector3(c.x + hx, 0, c.z + hz)],
	]
	for side in sides:
		_build_fence_line(side[0], side[1], white)


func _build_fence_line(from: Vector3, to: Vector3, mat: Material) -> void:
	var length := from.distance_to(to)
	var posts := maxi(1, int(length / 3.0))
	var dir := (to - from).normalized()
	for i in posts + 1:
		var post := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.14, 1.3, 0.14)
		post.mesh = box
		post.material_override = mat
		post.position = from + dir * (length * i / posts) + Vector3(0, 0.65, 0)
		add_child(post)
	# Invisible wall so the horse stays inside unless it uses the gate.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.3, 1.6, length)
	shape.shape = box_shape
	wall.add_child(shape)
	wall.position = (from + to) * 0.5 + Vector3(0, 0.8, 0)
	wall.rotation.y = atan2(dir.x, dir.z)
	add_child(wall)
	for h in [0.6, 1.1]:
		var rail := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.08, 0.1, length)
		rail.mesh = box
		rail.material_override = mat
		rail.position = (from + to) * 0.5 + Vector3(0, h, 0)
		rail.rotation.y = atan2(dir.x, dir.z)
		add_child(rail)


## A random spot on open ground, away from the arena and the spawn point.
func _random_spot(margin: float) -> Vector3:
	var half := size * 0.5 - 4.0
	for attempt in 30:
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if is_kept_clear(x, z, margin) or Vector2(x, z).length() < margin + 4.0:
			continue
		return Vector3(x, height_at(x, z), z)
	return Vector3(half, height_at(half, half), half)   # Hidden in the edge hills


func _noise_texture(frequency: float, octaves: int, texture_size: int, normal_map: bool) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = world_seed
	n.frequency = frequency
	n.fractal_octaves = octaves
	var texture := NoiseTexture2D.new()
	texture.noise = n
	texture.width = texture_size
	texture.height = texture_size
	texture.seamless = true
	texture.as_normal_map = normal_map
	texture.bump_strength = 4.0
	texture.generate_mipmaps = true
	return texture


func _multimesh(mesh: Mesh, count: int, mat: Material, node_name: String) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)
	return mm


func _vertex_color_material(roughness := 0.9) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = roughness
	return mat


func _sphere(radius: float, segments := 10, rings := 6) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = rings
	return m


## Trees grow in groves of mostly one kind, with open meadow between:
## willows and birches round the lake, pines up on the hills, blossom
## trees near the arena, oaks and poplars elsewhere and the odd autumn
## tree for colour. Each kind has a few variants (trees.gd), and each tree
## is turned, sized and tinted a little differently.
func _scatter_trees() -> void:
	var groves := FastNoiseLite.new()
	groves.seed = world_seed + 3
	groves.frequency = 0.018
	var kinds := FastNoiseLite.new()
	kinds.seed = world_seed + 4
	kinds.frequency = 0.012
	for i in tree_count:
		var spot := _random_spot(8.0)
		# Fewer trees outside the groves, so there are open meadows too.
		if groves.get_noise_2d(spot.x, spot.z) < -0.1 and rng.randf() < 0.75:
			continue
		var kind := _tree_kind(spot, kinds.get_noise_2d(spot.x, spot.z))
		_plant(kind, spot, rng.randf_range(0.85, 1.35))
	# A ring of willows (and a few birches) on the lake shore.
	for i in 24:
		var a := i * TAU / 24.0 + rng.randf_range(-0.1, 0.1)
		var p := LAKE_CENTER + Vector2(cos(a), sin(a)) * rng.randf_range(LAKE_RADIUS + 6.0, LAKE_RADIUS + 13.0)
		if trail_at(p.x, p.y) > 0.0:
			continue
		_plant("willow" if rng.randf() < 0.75 else "birch", Vector3(p.x, height_at(p.x, p.y), p.y), rng.randf_range(0.95, 1.3))


## Snowy pines (and a few birches) in the mountain valley and up its
## lower slopes, keeping off the track, the ice and the places.
func _scatter_mountain_trees() -> void:
	var groves := FastNoiseLite.new()
	groves.seed = world_seed + 6
	groves.frequency = 0.03
	var planted := 0
	for attempt in 900:
		if planted >= 150:
			break
		var x := rng.randf_range(-130.0, 130.0)
		var z := rng.randf_range(SNOW_FULL - 8.0, -400.0)
		var y := height_at(x, z)
		var above := y - (4.0 + 17.0 * smoothstep(-225.0, -322.0, z))
		if above > 22.0 or groves.get_noise_2d(x, z) < -0.15 or snow_track_distance(x, z) < 5.0 or is_on_ice(x, z, 8.0):
			continue
		if PLACES.slice(9).any(func(place): return Vector2(x, z).distance_to(place.pos) < 18.0):
			continue
		_plant("pine" if rng.randf() < 0.88 else "birch", Vector3(x, y, z), rng.randf_range(0.9, 1.5))
		planted += 1


## Which kind of tree grows at a spot. `field` is a slowly changing noise
## value, so neighbouring trees are mostly the same kind.
func _tree_kind(spot: Vector3, field: float) -> String:
	if rng.randf() < 0.04:
		return "autumn"
	var lake := Vector2(spot.x, spot.z).distance_to(LAKE_CENTER)
	if lake < LAKE_RADIUS + 30.0:
		return "willow" if rng.randf() < 0.35 else "birch"
	var edge := maxf(absf(spot.x), absf(spot.z))
	if spot.y > hill_height * 0.85 or edge > size * 0.5 - 50.0:
		return "pine" if rng.randf() < 0.8 else "birch"
	if Vector2(spot.x - arena_center.x, spot.z - arena_center.z).length() < 75.0 and rng.randf() < 0.45:
		return "blossom"
	if rng.randf() < 0.2:   # A few of anything, so groves aren't too tidy
		return ["oak", "birch", "poplar", "pine"][rng.randi() % 4]
	if field < -0.25:
		return "pine"
	if field < 0.05:
		return "oak"
	if field < 0.3:
		return "birch"
	return "poplar" if field < 0.45 else "oak"


## Round bushes and flowering bushes scattered in the meadow and along the
## arena fence.
func _scatter_bushes() -> void:
	for i in 160:
		var spot := _random_spot(3.0)
		if i < 40:
			# Line the outside of the arena's long sides.
			var side := -1.0 if i % 2 == 0 else 1.0
			var z := arena_center.z + rng.randf_range(-arena_size.y * 0.45, arena_size.y * 0.45)
			var x := arena_center.x + side * (arena_size.x * 0.5 + rng.randf_range(2.5, 4.0))
			spot = Vector3(x, height_at(x, z), z)
		_plant("flower_bush" if rng.randf() < 0.3 else "bush", spot, rng.randf_range(0.8, 1.4))


func _plant(kind: String, spot: Vector3, scale_by: float, sink := 0.1) -> void:
	var key := "%s:%d" % [kind, rng.randi() % (ROCK_VARIANTS if kind == "rock" else TREE_VARIANTS)]
	if not _tree_meshes.has(key):
		if kind == "rock":
			var stretch := Vector3(rng.randf_range(0.9, 1.4), rng.randf_range(0.5, 0.9), rng.randf_range(0.8, 1.2))
			_tree_meshes[key] = Rocks.grow(hash(key) + world_seed, stretch)
		else:
			_tree_meshes[key] = Trees.grow(kind, hash(key) + world_seed)
	var square := Vector2i(floori(spot.x / PLANTING_SQUARE), floori(spot.z / PLANTING_SQUARE))
	var bucket := [key, square]
	if not _plantings.has(bucket):
		_plantings[bucket] = [[], []]
	var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale_by)
	_plantings[bucket][0].append(Transform3D(b, spot - Vector3(0, sink * scale_by, 0)))
	var tint := rng.randf_range(0.88, 1.1)
	_plantings[bucket][1].append(Color(tint, tint * rng.randf_range(0.97, 1.03), tint))


func _build_plantings() -> void:
	for bucket in _plantings:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _tree_meshes[bucket[0]]
		mm.instance_count = _plantings[bucket][0].size()
		for i in mm.instance_count:
			mm.set_instance_transform(i, _plantings[bucket][0][i])
			mm.set_instance_color(i, _plantings[bucket][1][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Trees_%s_%d_%d" % [bucket[0].replace(":", "_"), bucket[1].x, bucket[1].y]
		mmi.multimesh = mm
		add_child(mmi)
	_plantings.clear()


## Rose beds on both sides of the arena entrance, like a show yard.
func _build_flower_beds() -> void:
	var gate_z := arena_center.z + arena_size.y * 0.5 + 2.5
	var beds := [Vector3(-11, 0, gate_z), Vector3(11, 0, gate_z)]
	var leaves := _multimesh(_sphere(1.0, 8, 5), 2 * 14, _vertex_color_material(0.8), "RoseLeaves")
	var roses := _multimesh(_sphere(0.12, 6, 4), 2 * 14 * 6, _vertex_color_material(0.5), "Roses")
	var rose_colors := [Color(0.85, 0.08, 0.12), Color(0.95, 0.94, 0.9), Color(0.95, 0.45, 0.55)]
	var li := 0
	var ri := 0
	for bed in beds:
		for b in 14:
			var pos: Vector3 = bed + Vector3(rng.randf_range(-6.5, 6.5), 0, rng.randf_range(-1.2, 1.2))
			var r := rng.randf_range(0.45, 0.65)
			leaves.set_instance_transform(li, Transform3D(Basis().scaled(Vector3(r, r * 0.9, r)), pos + Vector3(0, r * 0.7, 0)))
			leaves.set_instance_color(li, Color(0.16, 0.36, 0.12))
			li += 1
			var color: Color = rose_colors[rng.randi() % rose_colors.size()]
			for f in 6:
				var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 1), rng.randf_range(-1, 1)).normalized()
				roses.set_instance_transform(ri, Transform3D(Basis(), pos + Vector3(0, r * 0.7, 0) + dir * r * 0.95))
				roses.set_instance_color(ri, color)
				ri += 1


## Rocks lie in little groups: a big one with a few smaller ones around
## it, half sunk into the grass.
func _scatter_rocks() -> void:
	for i in rock_count / 4:
		var spot := _random_spot(4.0)
		_plant("rock", spot, rng.randf_range(1.0, 2.2), 0.15)
		for small in rng.randi_range(1, 4):
			var a := rng.randf() * TAU
			var p := Vector2(spot.x, spot.z) + Vector2(cos(a), sin(a)) * rng.randf_range(1.2, 2.6)
			if not is_kept_clear(p.x, p.y, 0.0):
				_plant("rock", Vector3(p.x, height_at(p.x, p.y), p.y), rng.randf_range(0.35, 0.8), 0.05)


func _scatter_grass() -> void:
	if Engine.is_editor_hint():
		return   # Grass grows around the camera while playing
	var grass := Node3D.new()
	grass.set_script(preload("res://scripts/grass.gd"))
	grass.name = "Grass"
	add_child(grass)
	grass.setup(self, _ground_material)


## Wildflowers in drifts: more where the meadow is lush, in groups of one
## colour. Split into squares so only the ones in view are drawn.
func _scatter_flowers() -> void:
	var region := 80.0
	var colors := [Color(0.98, 0.98, 0.95), Color(1.0, 0.86, 0.25), Color(0.92, 0.42, 0.66), Color(0.62, 0.55, 1.0), Color(1.0, 0.55, 0.35)]
	var drifts := FastNoiseLite.new()
	drifts.seed = world_seed + 9
	drifts.frequency = 0.025
	var mesh := flower_mesh()
	var mat := flower_material()
	var groups := {}   # Vector2i region -> [transforms, colours]
	for i in flower_count:
		var x := rng.randf_range(-200, 200)
		var z := rng.randf_range(-200, 200)
		var drift := drifts.get_noise_2d(x, z)
		if drift < 0.05 and rng.randf() > 0.15:
			continue   # Mostly in drifts, a few on their own
		if is_in_arena(x, z, 1.0) or trail_at(x, z) > 0.2 or is_in_lake(x, z, 1.0) or is_beach(x, z):
			continue
		var key := Vector2i(floori(x / region), floori(z / region))
		if not groups.has(key):
			groups[key] = [[], []]
		var s := rng.randf_range(1.2, 1.8)
		groups[key][0].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, height_at(x, z) - 0.02, z)))
		# Neighbouring flowers share a colour, picked by where they grow.
		var pick := int(absf(drifts.get_noise_2d(x * 3.0 + 500.0, z * 3.0)) * 40.0) % colors.size()
		groups[key][1].append(colors[pick])
	for key in groups:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = groups[key][0].size()
		for i in mm.instance_count:
			mm.set_instance_transform(i, groups[key][0][i])
			mm.set_instance_color(i, groups[key][1][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Flowers_%d_%d" % [key.x, key.y]
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 80.0 + region
		add_child(mmi)


## The wildflowers' material (flower.gdshader), shared by all of them.
func flower_material() -> ShaderMaterial:
	if _flower_material == null:
		_flower_material = ShaderMaterial.new()
		_flower_material.shader = preload("res://shaders/flower.gdshader")
	return _flower_material


## A daisy-like flower: a thin stem with two leaves, five petals around a
## middle. UV2 marks the parts for flower.gdshader (x: petal, y: middle),
## which colours them. UV.y is how high up the flower a point is.
func flower_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := 0.32
	var head := Vector3(0.03, top, 0)
	var add := func(at: Vector3, part: Vector2) -> void:
		st.set_uv(Vector2(0.5, at.y / top))
		st.set_uv2(part)
		st.add_vertex(at)
	# Stem: two crossed thin strips.
	for side in [Vector3(0.008, 0, 0), Vector3(0, 0, 0.008)]:
		for v in [-side, side, head + side, -side, head + side, head - side]:
			add.call(v, Vector2.ZERO)
	# Leaves.
	for leaf in [Vector3(0.09, 0.1, 0.02), Vector3(-0.08, 0.14, -0.03)]:
		var mid := Vector3(0, leaf.y - 0.06, 0)
		var w := Vector3(0, 0.025, 0)
		for v in [mid, leaf * Vector3(0.5, 1, 0.5) + w, leaf, mid, leaf, leaf * Vector3(0.5, 1, 0.5) - w]:
			add.call(v, Vector2.ZERO)
	# Petals, tilted up a little, and the middle.
	for p in 5:
		var a := p * TAU / 5.0
		var out := Vector3(cos(a), 0.25, sin(a))
		var across := Vector3(-sin(a), 0, cos(a))
		var base := head + out * 0.015
		for v in [base - across * 0.018, base + out * 0.06 + across * 0.022, base + out * 0.075,
				base - across * 0.018, base + out * 0.075, base + out * 0.06 - across * 0.022,
				base - across * 0.018, base + across * 0.018, base + out * 0.06 + across * 0.022]:
			add.call(v, Vector2(1, 0))
	for p in 5:
		var a := p * TAU / 5.0
		var b := (p + 1) * TAU / 5.0
		add.call(head + Vector3(0, 0.008, 0), Vector2(0, 1))
		add.call(head + Vector3(cos(b), 0, sin(b)) * 0.02, Vector2(0, 1))
		add.call(head + Vector3(cos(a), 0, sin(a)) * 0.02, Vector2(0, 1))
	st.generate_normals()
	return st.commit()
