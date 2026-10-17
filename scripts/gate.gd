@tool
extends Node3D
## The START or FINISH gate. Ride through it in the direction of the green
## arrow (shown in the editor). Move and rotate it like any object.

@export var text := "START":
	set(value):
		text = value
		_rebuild()
@export var color := Color(0.2, 0.7, 0.3):
	set(value):
		color = value
		_rebuild()
@export_range(2.0, 10.0, 0.5, "suffix:m") var width := 5.0:
	set(value):
		width = value
		_rebuild()


func _ready() -> void:
	_build()


func _rebuild() -> void:
	if is_inside_tree():
		_build()


func _build() -> void:
	for child in get_children():
		child.free()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.5

	var pole := CylinderMesh.new()
	pole.top_radius = 0.07
	pole.bottom_radius = 0.07
	pole.height = 3.0
	for x in [-width * 0.5, width * 0.5]:
		var mi := MeshInstance3D.new()
		mi.mesh = pole
		mi.material_override = mat
		mi.position = Vector3(x, 1.5, 0)
		add_child(mi)
	var flag := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, 0.55, 0.05)
	flag.mesh = box
	flag.material_override = mat
	flag.position.y = 2.75
	add_child(flag)
	for side in [1, -1]:
		var label := Label3D.new()
		label.text = text
		label.font_size = 64
		label.position = Vector3(0, 2.75, 0.04 * side)
		label.rotation.y = 0.0 if side == 1 else PI
		add_child(label)

	if Engine.is_editor_hint():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for p in [Vector3(-0.6, 0, 1.5), Vector3(0.6, 0, 1.5), Vector3(0, 0, -1.5)]:
			st.add_vertex(p + Vector3.UP * 0.06)
		var arrow_mat := StandardMaterial3D.new()
		arrow_mat.albedo_color = Color(0.2, 0.85, 0.3)
		arrow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		arrow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var arrow := MeshInstance3D.new()
		arrow.mesh = st.commit()
		arrow.material_override = arrow_mat
		add_child(arrow)
