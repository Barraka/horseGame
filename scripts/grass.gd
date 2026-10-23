extends Node3D
## Grass that covers the meadows around the camera. The world is cut into
## squares; each square's grass is grown the first time the camera comes
## near it (a square a frame) and kept after that. Grass is only
## drawn up close and shrinks away into the ground further off (see
## grass.gdshader), where the ground's own colours take over. Thicker in
## lush patches, thinner on the trail's edges, none in the arena or lake.

const CHUNK := 16.0          ## Square size in metres
const BLADES := 7            ## Blades in one tuft

var world: Node3D
var per_chunk := 900         ## Tufts tried in a square
var reach := 44.0            ## Grass is drawn this far from the camera
var _built := {}             ## Vector2i square -> true
var _material: ShaderMaterial
var _tuft: Mesh
var _lushness := FastNoiseLite.new()


func setup(owner_world: Node3D, ground: ShaderMaterial) -> void:
	world = owner_world
	if OS.has_feature("mobile"):
		per_chunk = 450
		reach = 32.0
	_lushness.seed = world.world_seed + 5
	_lushness.frequency = 0.03
	_tuft = _tuft_mesh()
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/grass.gdshader")
	for texture in ["patches", "grain"]:
		_material.set_shader_parameter(texture, ground.get_shader_parameter(texture))
	_material.set_shader_parameter("fade_start", reach * 0.68)
	_material.set_shader_parameter("fade_end", reach)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		# All at once the first time, then a square a frame.
		grow_near(camera.global_position, 0 if _built.is_empty() else 1)


## Grow the squares within reach of `spot`, nearest first, at most `limit`
## of them (all of them when limit is 0).
func grow_near(spot: Vector3, limit := 0) -> void:
	var centre := Vector2i(floori(spot.x / CHUNK), floori(spot.z / CHUNK))
	var span := int(ceil(reach / CHUNK)) + 1
	var todo: Array[Vector2i] = []
	for dz in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var square := centre + Vector2i(dx, dz)
			if not _built.has(square) and _square_distance(square, spot) < reach + 4.0:
				todo.append(square)
	todo.sort_custom(func(a, b): return _square_distance(a, spot) < _square_distance(b, spot))
	for i in todo.size() if limit == 0 else mini(limit, todo.size()):
		_grow(todo[i])


func _square_distance(square: Vector2i, spot: Vector3) -> float:
	var nearest := Vector2(clampf(spot.x, square.x * CHUNK, (square.x + 1) * CHUNK),
		clampf(spot.z, square.y * CHUNK, (square.y + 1) * CHUNK))
	return nearest.distance_to(Vector2(spot.x, spot.z))


func _grow(square: Vector2i) -> void:
	_built[square] = true
	var edge: float = world.size * 0.5 - 12.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(square.x, square.y, world.world_seed))
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in per_chunk:
		var x := (square.x + rng.randf()) * CHUNK
		var z := (square.y + rng.randf()) * CHUNK
		var lush := clampf(_lushness.get_noise_2d(x, z) * 0.9 + 0.55, 0.0, 1.0)
		var keep := rng.randf()
		if absf(x) > edge or absf(z) > edge or keep > 0.3 + lush * 0.7:
			continue
		if world.is_in_arena(x, z, 0.6) or world.is_in_lake(x, z, -1.0):
			continue
		var trail: float = world.trail_at(x, z)
		if trail > 0.45 or rng.randf() < trail * 2.2:
			continue
		var s := rng.randf_range(0.75, 1.15)
		var tall := (0.55 + lush * 0.75) * rng.randf_range(0.8, 1.2) * (1.0 - trail)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, tall, s))
		transforms.append(Transform3D(b, Vector3(x, world.height_at(x, z) - 0.03, z)))
		colors.append(world.ground_color(x, z) * rng.randf_range(0.88, 1.1))
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _tuft
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
	var patch := MultiMeshInstance3D.new()
	patch.name = "Grass_%d_%d" % [square.x, square.y]
	patch.multimesh = mm
	patch.material_override = _material
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	patch.visibility_range_end = reach + CHUNK * 0.75
	add_child(patch)


## One tuft: blades fanning out from the root, each a tapering, curving
## strip in three steps. UV.y runs from 0 at the root to 1 at the tip.
func _tuft_mesh() -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in BLADES:
		var angle := blade * TAU / BLADES + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(angle), 0, sin(angle))
		var across := Vector3(-out.z, 0, out.x)
		var root := out * rng.randf_range(0.02, 0.12)
		var height := rng.randf_range(0.32, 0.55)
		var lean := rng.randf_range(0.08, 0.22)
		var width := rng.randf_range(0.03, 0.045)
		var rows: Array[Vector3] = []
		var rows_uv: Array[float] = []
		for step in 4:
			var t := step / 3.0
			var centre := root + out * lean * t * t + Vector3.UP * height * t
			var w := width * (1.0 - t)
			rows.append(centre - across * w)
			rows.append(centre + across * w)
			rows_uv.append(t)
		for step in 3:
			var a := rows[step * 2]
			var b := rows[step * 2 + 1]
			var c := rows[step * 2 + 2]
			var d := rows[step * 2 + 3]
			var ta := rows_uv[step]
			var tb := rows_uv[step + 1]
			_vertex(st, a, ta)
			_vertex(st, b, ta)
			_vertex(st, c, tb)
			if step < 2:   # The last step ends in a point
				_vertex(st, b, ta)
				_vertex(st, d, tb)
				_vertex(st, c, tb)
	st.generate_normals()
	return st.commit()


func _vertex(st: SurfaceTool, at: Vector3, t: float) -> void:
	st.set_uv(Vector2(0.5, t))
	st.add_vertex(at)
