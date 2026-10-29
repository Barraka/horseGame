extends SceneTree
## Writes the horse gait meshes' vertices in the order Godot imported them,
## for tools/gait_blend.py (run from the project folder):
##   godot --headless --path . -s tools/mesh_order.gd

const FILES := ["horse_walk.glb", "horse_trot.glb", "horse_run.glb"]


func _initialize() -> void:
	var out := {}
	for file in FILES:
		var model := (load("res://assets/horse/gaits/" + file) as PackedScene).instantiate()
		for node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh: ArrayMesh = (node as MeshInstance3D).mesh
			if mesh.get_blend_shape_count() == 0:
				continue
			var arrays := mesh.surface_get_arrays(0)
			var points := []
			for p in arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				points.append([p.x, p.y, p.z])
			var uvs := []
			for uv in arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array:
				uvs.append([uv.x, uv.y])
			out[file] = {"points": points, "uvs": uvs}
		model.free()
	var path := ProjectSettings.globalize_path("res://tools/mesh_order.json")
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(out))
	print("wrote ", path)
	quit()
