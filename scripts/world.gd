extends Node3D
## Builds the meadow: rolling grassy terrain, a sand riding arena,
## trees, rocks, grass tufts and flowers. Everything is generated from
## a seed, so the world looks the same every time.

@export var world_seed := 7
@export var size := 240.0              ## Terrain width and depth in metres
@export var cell := 2.0                ## Terrain grid spacing in metres
@export var hill_height := 9.0
@export var arena_center := Vector3(0, 0, -35)
@export var arena_size := Vector2(56, 66)   ## Width (x) and length (z)
@export var tree_count := 160
@export var rock_count := 60
@export var grass_count := 4000
@export var flower_count := 900

var noise := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	noise.seed = world_seed
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	detail.seed = world_seed + 1
	detail.frequency = 0.08
	rng.seed = world_seed
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
	return h * mask


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

	var grass_dark := Color(0.2, 0.44, 0.12)
	var grass_light := Color(0.47, 0.66, 0.2)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zi in cells + 1:
		for xi in cells + 1:
			var x := xi * cell - half
			var z := zi * cell - half
			var t := clampf(detail.get_noise_2d(x * 0.5, z * 0.5) * 0.8 + 0.5, 0.0, 1.0)
			st.set_color(grass_dark.lerp(grass_light, t))
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

	# A fine mottled pattern over the grass colours so the ground doesn't look flat.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.72, 0.78, 0.68))
	ramp.set_color(1, Color(1.05, 1.05, 0.98))
	var grain := FastNoiseLite.new()
	grain.frequency = 0.06
	grain.fractal_octaves = 4
	var grain_texture := NoiseTexture2D.new()
	grain_texture.noise = grain
	grain_texture.color_ramp = ramp
	grain_texture.seamless = true
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = grain_texture
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.12, 0.12, 0.12)
	mat.roughness = 0.95

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
		if is_in_arena(x, z, margin) or Vector2(x, z).length() < margin + 4.0:
			continue
		return Vector3(x, height_at(x, z), z)
	return Vector3(half, height_at(half, half), half)


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
	# A tuft is three thin crossed blades, cheap enough to draw thousands.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		var a := i * TAU / 3.0
		var side := Vector3(cos(a), 0, sin(a)) * 0.12
		var lean := Vector3(-sin(a), 0, cos(a)) * 0.08
		st.add_vertex(-side)
		st.add_vertex(side)
		st.add_vertex(lean + Vector3(0, 0.5, 0))
	st.generate_normals()
	var mat := _vertex_color_material()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tufts := _multimesh(st.commit(), grass_count, mat, "GrassTufts")
	tufts.visible_instance_count = 0
	var placed := 0
	for i in grass_count:
		var half := 70.0
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half) + arena_center.z * 0.5
		if is_in_arena(x, z, 1.0):
			continue
		var s := rng.randf_range(0.7, 1.4)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.4), s))
		tufts.set_instance_transform(placed, Transform3D(b, Vector3(x, height_at(x, z), z)))
		tufts.set_instance_color(placed, Color(0.36, 0.58, 0.2).lerp(Color(0.58, 0.72, 0.3), rng.randf()))
		placed += 1
	tufts.visible_instance_count = placed


func _scatter_flowers() -> void:
	var flower_mesh := SphereMesh.new()
	flower_mesh.radius = 0.07
	flower_mesh.height = 0.1
	flower_mesh.radial_segments = 5
	flower_mesh.rings = 2
	var colors := [Color(0.98, 0.98, 0.95), Color(0.98, 0.85, 0.2), Color(0.85, 0.35, 0.6), Color(0.55, 0.5, 0.95)]
	var flowers := _multimesh(flower_mesh, flower_count, _vertex_color_material(0.6), "Flowers")
	flowers.visible_instance_count = 0
	var placed := 0
	for i in flower_count:
		var x := rng.randf_range(-80, 80)
		var z := rng.randf_range(-80, 80)
		if is_in_arena(x, z, 1.0):
			continue
		flowers.set_instance_transform(placed, Transform3D(Basis(), Vector3(x, height_at(x, z) + 0.25, z)))
		flowers.set_instance_color(placed, colors[rng.randi() % colors.size()])
		placed += 1
	flowers.visible_instance_count = placed
