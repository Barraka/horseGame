extends RefCounted
## One horse mesh that can take any pose from any of the gait files, so
## horse.gd can blend smoothly from one gait into the next instead of
## swapping models.
##
## The walk file's mesh is posed in every frame of every gait: each of its
## vertices follows its partner (or a mix of vertices) in the trot and run
## meshes, as measured by tools/gait_blend.py. Each frame becomes one blend shape. The files
## themselves are used as they are (their licence forbids edits); this mixes
## their poses while the game runs. Built once and shared by every horse.

const GAIT_SET_DIR := "res://assets/horse/gaits"
const CACHE := "user://gait_blend.res"

static var _mesh: ArrayMesh
static var _first_shape: Array[int] = []   # Each gait's first blend shape
static var _frames: Array[int] = []        # How many frames each gait has
static var _times: Array = []              # When each frame is, per gait


## The shared mesh for a gait set (horse.gd GAIT_SET), built on first use.
## `track` is the saddle track (tools/saddle_track.py), for the frame times
## and how far the travelling clips move.
static func mesh(gait_set: Array, track: Dictionary) -> ArrayMesh:
	if _mesh:
		return _mesh
	var file := FileAccess.open(GAIT_SET_DIR.path_join("gait_blend.json"), FileAccess.READ)
	if not file:
		return null
	var text := file.get_as_text()
	_frames.clear()
	_times.clear()
	_first_shape.clear()
	for entry in gait_set:
		_first_shape.append(_frames.reduce(func(sum, n): return sum + n, 0))
		_frames.append(track[entry.file].times.size() - 1)   # The last frame is the first again
		_times.append(track[entry.file].times)
	# Building it takes a few seconds, so it is kept between games (made
	# again whenever the measurements or Godot change).
	var stamp := "%s %s" % [text.md5_text(), Engine.get_version_info().string]
	if FileAccess.file_exists(CACHE) and ResourceLoader.exists(CACHE):
		var kept := ResourceLoader.load(CACHE, "ArrayMesh", ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
		if kept and kept.has_meta("stamp") and kept.get_meta("stamp") == stamp:
			_mesh = kept
			return _mesh
	var follow: Dictionary = JSON.parse_string(text)
	var walk: Dictionary = gait_set[0]
	var base := _surface(walk.file)
	var arrays: Array = base.surface_get_arrays(0)
	var count: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	if count != int(follow.vertices):
		push_warning("gait_blend.json doesn't match the walk mesh; gaits will switch without blending")
		return null
	var shapes: Array = []
	var bounds := AABB(Vector3.INF, Vector3.ZERO)
	for entry in gait_set:
		var source := base if entry == walk else _surface(entry.file)
		var source_arrays: Array = source.surface_get_arrays(0) if entry != walk else arrays
		var source_shapes: Array = source.surface_get_blend_shape_arrays(0)
		var times: Array = track[entry.file].times
		var seat: Array = track[entry.file].seat
		# Into the walk file's space: the file's own turn and offset, less the walk's.
		var turn := Basis(Vector3.UP, deg_to_rad(entry.yaw - walk.yaw))
		for frame in times.size() - 1:
			# Frame 0 is the mesh at rest; frame n is blend shape n - 1.
			var pose: Array = source_arrays if frame == 0 else source_shapes[frame - 1]
			var offset: Vector3 = entry.offset
			if entry.root_motion:
				offset.x -= seat[frame][0] - seat[0][0]
			var place := Transform3D(turn, turn * offset - walk.offset)
			var posed := _pose(pose, follow.get(entry.file, {}), count, place, arrays)
			for p in posed[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				bounds = AABB(p, Vector3.ZERO) if bounds.position == Vector3.INF else bounds.expand(p)
			shapes.append(posed)
	_mesh = ArrayMesh.new()
	for i in shapes.size():
		_mesh.add_blend_shape("pose_%d" % i)
	_mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, shapes)
	_mesh.surface_set_material(0, base.surface_get_material(0))
	_mesh.custom_aabb = bounds.grow(1.0)
	_mesh.set_meta("stamp", stamp)
	ResourceSaver.save(_mesh, CACHE, ResourceSaver.FLAG_COMPRESS)
	return _mesh


## Blend shape weights for a mix of poses: each [gait, time in its clip, weight].
static func weights(poses: Array) -> Dictionary:
	var out := {}
	for pose in poses:
		var gait: int = pose[0]
		var weight: float = pose[2]
		if weight <= 0.0:
			continue
		var times: Array = _times[gait]
		var time: float = pose[1]
		# Between which frames, the same way the clip plays (and _track_point reads).
		var frame := times.size() - 1
		for i in times.size():
			if times[i] > time:
				frame = i
				break
		var prev := maxi(frame - 1, 0)
		var t := 0.0 if frame == prev else clampf((time - times[prev]) / (times[frame] - times[prev]), 0.0, 1.0)
		for pair in [[prev, 1.0 - t], [frame, t]]:
			var shape: int = _first_shape[gait] + (pair[0] % _frames[gait])
			out[shape] = out.get(shape, 0.0) + weight * pair[1]
	return out


static func _surface(file: String) -> ArrayMesh:
	var model := (load(GAIT_SET_DIR.path_join(file)) as PackedScene).instantiate()
	var found: ArrayMesh
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh as ArrayMesh
		if mesh and mesh.get_blend_shape_count() > 0:
			found = mesh
	model.free()
	return found


## One frame of a gait file, on the walk mesh's vertices, in the walk's space.
static func _pose(pose: Array, follow: Dictionary, count: int, place: Transform3D, walk_arrays: Array) -> Array:
	var points: PackedVector3Array = pose[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = pose[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = pose[Mesh.ARRAY_TANGENT]
	var out_points := PackedVector3Array()
	var out_normals := PackedVector3Array()
	var out_tangents := PackedFloat32Array()
	if follow.is_empty():
		# The walk itself: its own vertices.
		out_points = points
		out_normals = normals
		out_tangents = tangents
	else:
		out_points.resize(count)
		out_normals.resize(count)
		out_tangents = (walk_arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).duplicate()
		var direct: Array = follow.direct
		for v in count:
			var j: int = direct[v]
			if j >= 0:
				out_points[v] = points[j]
				out_normals[v] = normals[j]
				out_tangents[v * 4] = tangents[j * 4]
				out_tangents[v * 4 + 1] = tangents[j * 4 + 1]
				out_tangents[v * 4 + 2] = tangents[j * 4 + 2]
		# The inside of the mouth follows a mix of the vertices round it,
		# kept about as close to their middle as it is at rest.
		for row in follow.get("mixes", []):
			var size: int = (row.size() - 2) / 2
			var p := Vector3.ZERO
			var n := Vector3.ZERO
			var middle := Vector3.ZERO
			for k in size:
				var j: int = row[1 + k]
				var weight: float = row[1 + size + k]
				p += points[j] * weight
				n += normals[j] * weight
				middle += points[j] / size
			out_points[row[0]] = middle + (p - middle).limit_length(float(row[-1]) * 1.5 + 0.1)
			out_normals[row[0]] = n.normalized()
	# Into the walk's space.
	var moved := PackedVector3Array()
	moved.resize(count)
	var turned_normals := PackedVector3Array()
	turned_normals.resize(count)
	var turned_tangents := out_tangents.duplicate()
	var turn := place.basis
	for v in count:
		moved[v] = place * out_points[v]
		turned_normals[v] = (turn * out_normals[v]).normalized()
		var t := turn * Vector3(out_tangents[v * 4], out_tangents[v * 4 + 1], out_tangents[v * 4 + 2])
		turned_tangents[v * 4] = t.x
		turned_tangents[v * 4 + 1] = t.y
		turned_tangents[v * 4 + 2] = t.z
	var result := []
	result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX] = moved
	result[Mesh.ARRAY_NORMAL] = turned_normals
	result[Mesh.ARRAY_TANGENT] = turned_tangents
	return result
