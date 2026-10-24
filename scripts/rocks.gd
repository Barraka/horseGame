@tool
extends RefCounted
## Rocks and standing stones made in code: a ball of triangles pushed in
## and out by noise, so each one is lumpy and different, flattened at the
## bottom to sit on the ground. Coloured by rock.gdshader.

const HEIGHT := 0.65   ## How tall a rock is, times stretch.y: it sits 0 to 0.65

static var _material: ShaderMaterial


## A rock about 1 m across (scale it as needed). `stretch` makes standing
## stones and slabs: e.g. (0.6, 1.8, 0.35) for a tall, thin stone.
static func grow(seed: int, stretch := Vector3.ONE, lumpiness := 0.28, detail := 2) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 1.4
	noise.fractal_octaves = 3
	var points := PackedVector3Array()
	var faces := PackedInt32Array()
	_icosphere(points, faces, detail)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in points:
		var bump := 1.0 + noise.get_noise_3dv(p * 1.3) * lumpiness
		# A few big flat faces, like broken stone.
		var facet := noise.get_noise_3dv(p * 0.5 + Vector3(9, 9, 9))
		bump *= 1.0 - maxf(facet, 0.0) * 0.25
		var v := p * bump * 0.5 * stretch
		v.y = maxf(v.y, -0.15 * stretch.y)   # Flat bottom, sunk into the ground
		st.set_color(Color(0.62, 0.61, 0.58))
		st.add_vertex(v + Vector3(0, 0.15 * stretch.y, 0))
	for f in range(0, faces.size(), 3):   # Turned round to Godot's winding
		st.add_index(faces[f])
		st.add_index(faces[f + 2])
		st.add_index(faces[f + 1])
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, material())
	return mesh


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://shaders/rock.gdshader")
		var noise := FastNoiseLite.new()
		noise.frequency = 0.03
		noise.fractal_octaves = 4
		var texture := NoiseTexture2D.new()
		texture.noise = noise
		texture.seamless = true
		texture.generate_mipmaps = true
		_material.set_shader_parameter("grain", texture)
	return _material


## A round ball of triangles: an icosahedron with each triangle split into
## four, `levels` times, pushed out onto the sphere.
static func _icosphere(points: PackedVector3Array, faces: PackedInt32Array, levels: int) -> void:
	var t := (1.0 + sqrt(5.0)) / 2.0
	for p in [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
			Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
			Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]:
		points.append(p.normalized())
	faces.append_array([0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4,
		11, 10, 2, 10, 7, 6, 7, 1, 8, 3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9,
		4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1])
	for level in levels:
		var midpoints := {}
		var split := PackedInt32Array()
		for f in range(0, faces.size(), 3):
			var a := faces[f]
			var b := faces[f + 1]
			var c := faces[f + 2]
			var ab := _midpoint(points, midpoints, a, b)
			var bc := _midpoint(points, midpoints, b, c)
			var ca := _midpoint(points, midpoints, c, a)
			split.append_array([a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca])
		faces.clear()
		faces.append_array(split)


static func _midpoint(points: PackedVector3Array, cache: Dictionary, a: int, b: int) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if not cache.has(key):
		points.append(((points[a] + points[b]) * 0.5).normalized())
		cache[key] = points.size() - 1
	return cache[key]
