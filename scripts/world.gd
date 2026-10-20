@tool
extends Node3D
## Builds the countryside: rolling grassy terrain, a sand riding arena,
## a trail looping past a lake and other places to discover, trees, rocks,
## swaying grass (grass.gd) and drifts of wildflowers. Hills rise at the
## edges to close it in.
## Everything is generated from a seed, so the world looks the same every
## time. It also runs in the editor; reopen the scene to see changes to
## the settings below. The places themselves are built by explore.gd.

@export var world_seed := 7
@export var size := 480.0              ## Terrain width and depth in metres
@export var cell := 2.0                ## Terrain grid spacing in metres
@export var hill_height := 9.0
@export var arena_center := Vector3(0, 0, -35)
@export var arena_size := Vector2(56, 66)   ## Width (x) and length (z)
@export var tree_count := 420
@export var rock_count := 150
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
const TRAIL_WIDTH := 3.0
const GRASS_DARK := Color(0.2, 0.44, 0.12)
const GRASS_LIGHT := Color(0.47, 0.66, 0.2)
const TRAIL_DARK := Color(0.56, 0.44, 0.3)
const TRAIL_LIGHT := Color(0.7, 0.58, 0.42)
const LAKE_BED := Color(0.42, 0.4, 0.3)

var noise := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()
var trail_points := PackedVector2Array()   ## The trail's centre line, a point every metre
var _trail_mask := PackedFloat32Array()    ## 1 on the trail, fading to 0, on a 1 m grid
var _ground_material: ShaderMaterial


func _ready() -> void:
	noise.seed = world_seed
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	detail.seed = world_seed + 1
	detail.frequency = 0.08
	rng.seed = world_seed
	_build_trail()
	_build_terrain()
	_build_arena()
	_scatter_trees()
	_scatter_bushes()
	_build_flower_beds()
	_scatter_rocks()
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
	# Hills closing in the edges of the world.
	var edge := maxf(absf(x), absf(z))
	h += EDGE_HEIGHT * smoothstep(size * 0.5 - 55.0, size * 0.5 - 5.0, edge)
	# The lake: flat shore, then a shallow bowl the horse can wade into.
	var d := Vector2(x, z).distance_to(LAKE_CENTER)
	if d < LAKE_RADIUS + 28.0:
		h = lerpf(LAKE_SHORE, h, smoothstep(LAKE_RADIUS + 4.0, LAKE_RADIUS + 28.0, d))
		if d < LAKE_RADIUS + 4.0:
			var bowl := LAKE_SHORE - 1.5 * (1.0 - smoothstep(LAKE_RADIUS * 0.3, LAKE_RADIUS + 4.0, d))
			h = minf(h, bowl)
	return h


## The ground's painted colour at a point: grass in two greens, the trail
## in sandy browns, and the lake bed. The grass blades take it too.
func ground_color(x: float, z: float) -> Color:
	var t := clampf(detail.get_noise_2d(x * 0.5, z * 0.5) * 0.8 + 0.5, 0.0, 1.0)
	var color := GRASS_DARK.lerp(GRASS_LIGHT, t)
	color = color.lerp(TRAIL_DARK.lerp(TRAIL_LIGHT, t), trail_at(x, z))
	if is_in_lake(x, z, 2.0):
		color = color.lerp(LAKE_BED, 1.0 - smoothstep(LAKE_RADIUS - 2.0, LAKE_RADIUS + 2.0, Vector2(x, z).distance_to(LAKE_CENTER)))
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
	if is_in_arena(x, z, margin) or is_in_lake(x, z, margin + 4.0) or trail_at(x, z) > 0.0:
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
	var reach := int(ceil(TRAIL_WIDTH))
	for point in trail_points:
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
	var cells := int(size / cell)
	var half := size * 0.5
	var heights := PackedFloat32Array()
	heights.resize((cells + 1) * (cells + 1))
	for zi in cells + 1:
		for xi in cells + 1:
			heights[zi * (cells + 1) + xi] = height_at(xi * cell - half, zi * cell - half)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zi in cells + 1:
		for xi in cells + 1:
			var x := xi * cell - half
			var z := zi * cell - half
			st.set_color(ground_color(x, z))
			st.set_uv(Vector2(xi, zi))
			st.add_vertex(Vector3(x, heights[zi * (cells + 1) + xi], z))
	for zi in cells:
		for xi in cells:
			var i := zi * (cells + 1) + xi
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + cells + 1)
			st.add_index(i + 1)
			st.add_index(i + cells + 2)
			st.add_index(i + cells + 1)
	st.generate_normals()

	# Soft painted detail on top of the colours: see terrain.gdshader.
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/terrain.gdshader")
	mat.set_shader_parameter("patches", _noise_texture(0.012, 3, 256, false))
	mat.set_shader_parameter("grain", _noise_texture(0.03, 4, 256, false))
	mat.set_shader_parameter("bumps", _noise_texture(0.03, 4, 256, true))
	_ground_material = mat

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Terrain"
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = mat
	add_child(mesh_instance)

	var shape := HeightMapShape3D.new()
	shape.map_width = cells + 1
	shape.map_depth = cells + 1
	shape.map_data = heights
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.scale = Vector3(cell, 1, cell)
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.add_child(collision)
	add_child(body)

	# Invisible walls on the hills at the edge, so the horse stays in the world.
	for side in 4:
		var wall := StaticBody3D.new()
		var wall_shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(size, 60.0, 2.0)
		wall_shape.shape = box
		wall.add_child(wall_shape)
		wall.rotation.y = side * PI * 0.5
		wall.position = Vector3(0, 20.0, size * 0.5 - 20.0).rotated(Vector3.UP, side * PI * 0.5)
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


## Broadleaf trees have a fluffy crown made of several overlapping leaf
## clumps; pines are three stacked cones.
func _scatter_trees() -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.14
	trunk_mesh.bottom_radius = 0.28
	trunk_mesh.height = 2.6
	trunk_mesh.radial_segments = 7
	var pine_mesh := CylinderMesh.new()
	pine_mesh.top_radius = 0.0
	pine_mesh.bottom_radius = 1.5
	pine_mesh.height = 2.6
	pine_mesh.radial_segments = 9

	var clumps_per_tree := 6
	var trunks := _multimesh(trunk_mesh, tree_count, _vertex_color_material(), "TreeTrunks")
	var clumps := _multimesh(_sphere(1.0), tree_count * clumps_per_tree, _vertex_color_material(0.8), "LeafClumps")
	var pines := _multimesh(pine_mesh, tree_count * 3, _vertex_color_material(0.8), "PineLayers")
	var clump_count := 0
	var pine_count := 0

	for i in tree_count:
		var spot := _random_spot(8.0)
		var s := rng.randf_range(0.8, 1.5)
		var yaw := Basis(Vector3.UP, rng.randf() * TAU)
		trunks.set_instance_transform(i, Transform3D(yaw.scaled(Vector3.ONE * s), spot + Vector3(0, 1.3 * s, 0)))
		trunks.set_instance_color(i, Color(0.4, 0.28, 0.18))
		if rng.randf() < 0.3:
			for layer in 3:
				var ls := s * (1.0 - layer * 0.25)
				var pos := spot + Vector3(0, s * (2.2 + layer * 1.15), 0)
				pines.set_instance_transform(pine_count, Transform3D(yaw.scaled(Vector3.ONE * ls), pos))
				pines.set_instance_color(pine_count, Color(0.12, 0.34, 0.2).lightened(layer * 0.05))
				pine_count += 1
		else:
			var crown := spot + Vector3(0, s * 3.4, 0)
			var green := Color(0.22, 0.48, 0.15).lerp(Color(0.42, 0.62, 0.18), rng.randf())
			for c in clumps_per_tree:
				var offset := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 0.8), rng.randf_range(-1, 1)) * s
				var r := s * rng.randf_range(0.9, 1.4)
				clumps.set_instance_transform(clump_count, Transform3D(Basis().scaled(Vector3(r, r * 0.85, r)), crown + offset))
				# Lighter clumps on top, as if lit by the sun.
				clumps.set_instance_color(clump_count, green.lightened(clampf(offset.y * 0.12 + 0.05, 0.0, 0.2)))
				clump_count += 1
	clumps.visible_instance_count = clump_count
	pines.visible_instance_count = pine_count


## Round bushes scattered in the meadow and along the arena fence.
func _scatter_bushes() -> void:
	var count := 140
	var bushes := _multimesh(_sphere(1.0, 8, 5), count * 3, _vertex_color_material(0.85), "Bushes")
	var placed := 0
	for i in count:
		var spot := _random_spot(3.0)
		if i < 40:
			# Line the outside of the arena's long sides.
			var side := -1.0 if i % 2 == 0 else 1.0
			var z := arena_center.z + rng.randf_range(-arena_size.y * 0.45, arena_size.y * 0.45)
			var x := arena_center.x + side * (arena_size.x * 0.5 + rng.randf_range(2.5, 4.0))
			spot = Vector3(x, height_at(x, z), z)
		var green := Color(0.2, 0.42, 0.14).lerp(Color(0.36, 0.55, 0.18), rng.randf())
		for c in 3:
			var r := rng.randf_range(0.5, 0.9)
			var offset := Vector3(rng.randf_range(-0.6, 0.6), r * 0.6, rng.randf_range(-0.6, 0.6))
			bushes.set_instance_transform(placed, Transform3D(Basis().scaled(Vector3(r, r * 0.8, r)), spot + offset))
			bushes.set_instance_color(placed, green)
			placed += 1
	bushes.visible_instance_count = placed


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


func _scatter_rocks() -> void:
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.6
	rock_mesh.height = 0.9
	rock_mesh.radial_segments = 6
	rock_mesh.rings = 3
	var rocks := _multimesh(rock_mesh, rock_count, _vertex_color_material(1.0), "Rocks")
	for i in rock_count:
		var spot := _random_spot(4.0)
		var s := Vector3(rng.randf_range(0.6, 1.8), rng.randf_range(0.5, 1.0), rng.randf_range(0.6, 1.6))
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(s)
		rocks.set_instance_transform(i, Transform3D(b, spot + Vector3(0, 0.1, 0)))
		rocks.set_instance_color(i, Color(0.55, 0.55, 0.52).darkened(rng.randf() * 0.25))


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
	var mesh := _flower_mesh()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/flower.gdshader")
	var groups := {}   # Vector2i region -> [transforms, colours]
	for i in flower_count:
		var x := rng.randf_range(-200, 200)
		var z := rng.randf_range(-200, 200)
		var drift := drifts.get_noise_2d(x, z)
		if drift < 0.05 and rng.randf() > 0.15:
			continue   # Mostly in drifts, a few on their own
		if is_in_arena(x, z, 1.0) or trail_at(x, z) > 0.2 or is_in_lake(x, z, 1.0):
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


## A daisy-like flower: a thin stem with two leaves, five petals around a
## middle. UV2 marks the parts for flower.gdshader (x: petal, y: middle),
## which colours them. UV.y is how high up the flower a point is.
func _flower_mesh() -> Mesh:
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
