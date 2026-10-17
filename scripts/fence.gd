@tool
extends Node3D
## One show jumping fence. Move and rotate it in the 3D view like any
## object; the green arrow on the ground shows the direction to jump it.
## Fences are jumped in the order they appear under Course in the scene tree.

@export_range(0.3, 1.5, 0.05, "suffix:m") var height := 0.8:
	set(value):
		height = value
		_rebuild()
@export_range(2.0, 8.0, 0.5, "suffix:m") var width := 4.0:
	set(value):
		width = value
		_rebuild()

## Set by the course from the fence's place in the scene tree.
var number := 1:
	set(value):
		number = value
		_rebuild()
var rails: Array[MeshInstance3D] = []


func _ready() -> void:
	_build()


func _rebuild() -> void:
	if is_inside_tree():
		_build()


func reset_rails() -> void:
	for rail in rails:
		rail.position.y = rail.get_meta("height")
		rail.rotation = Vector3(0, 0, PI / 2)


func _build() -> void:
	# Every child is generated here (none are saved in the scene).
	for child in get_children():
		child.free()
	rails.clear()
	var color := Color(0.85, 0.15, 0.15) if number % 2 == 1 else Color(0.15, 0.32, 0.8)

	var stand := BoxMesh.new()
	stand.size = Vector3(0.18, 1.5, 0.45)
	for x in [-width * 0.5, width * 0.5]:
		var mi := MeshInstance3D.new()
		mi.mesh = stand
		mi.material_override = _material(Color(0.95, 0.95, 0.93))
		mi.position = Vector3(x, 0.75, 0)
		add_child(mi)

	var rail_mesh := CylinderMesh.new()
	rail_mesh.top_radius = 0.06
	rail_mesh.bottom_radius = 0.06
	rail_mesh.height = width - 0.2
	rail_mesh.radial_segments = 10
	for h in [height, height * 0.55]:
		# Striped look: the top rail in the fence colour, the lower one white.
		var rail := MeshInstance3D.new()
		rail.mesh = rail_mesh
		rail.material_override = _material(color if h == height else Color(0.96, 0.96, 0.96), 0.4)
		rail.position = Vector3(0, h, 0)
		rail.rotation = Vector3(0, 0, PI / 2)
		rail.set_meta("height", h)
		add_child(rail)
		rails.append(rail)

	var label := Label3D.new()
	label.text = str(number)
	label.font_size = 96
	label.outline_size = 18
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.position = Vector3(width * 0.5 + 0.1, 1.85, 0)
	add_child(label)

	if Engine.is_editor_hint():
		add_child(_direction_arrow())


## A flat green arrow on the ground pointing the way to jump (editor only).
func _direction_arrow() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in [Vector3(-0.6, 0, 1.5), Vector3(0.6, 0, 1.5), Vector3(0, 0, -1.5)]:
		st.add_vertex(p + Vector3.UP * 0.06)
	var mat := _material(Color(0.2, 0.85, 0.3))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var arrow := MeshInstance3D.new()
	arrow.mesh = st.commit()
	arrow.material_override = mat
	return arrow


func _material(color: Color, roughness := 0.5) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat
