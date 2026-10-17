@tool
extends Node3D
## Show jumping course: ride through START, jump the fences in order,
## then ride through FINISH. Each knocked rail costs 4 faults.
## Fence positions can be edited in the Inspector (x, z, height); the
## editor redraws the course as you change them.

signal status_changed(text: String)
signal announce(text: String)

@export var horse_path: NodePath
@export var start_gate := Vector2(0, -6):
	set(value):
		start_gate = value
		_rebuild()
@export var finish_gate := Vector2(8, -12):
	set(value):
		finish_gate = value
		_rebuild()
@export var fences: Array[Vector3] = [
	Vector3(0, -18, 0.6),
	Vector3(-12, -32, 0.7),
	Vector3(-6, -52, 0.8),
	Vector3(10, -54, 0.8),
	Vector3(14, -34, 0.9),
]:
	set(value):
		fences = value
		_rebuild()
@export var width := 4.0:
	set(value):
		width = value
		_rebuild()
@export var clearance := 0.3   ## Hooves tuck up this far below the horse

enum State { READY, RIDING, DONE }

var state := State.READY
var next_fence := 0
var faults := 0
var time := 0.0

var _horse: CharacterBody3D
var _last_pos: Vector3
var _lines: Array = []    # {pos: Vector2, dir: Vector2, rails: Array}
var _start: Dictionary
var _finish: Dictionary


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	_horse = get_node(horse_path)
	_last_pos = _horse.global_position
	_update_status.call_deferred()


func _rebuild() -> void:
	if is_inside_tree():
		_build()


func _build() -> void:
	# Every child of this node is generated here, so clear them all first.
	for child in get_children():
		child.free()
	_lines.clear()
	if fences.is_empty():
		return
	var colors := [Color(0.85, 0.15, 0.15), Color(0.15, 0.32, 0.8)]
	var points: Array[Vector2] = [start_gate]
	for f in fences:
		points.append(Vector2(f.x, f.y))
	points.append(finish_gate)

	for i in fences.size():
		var pos := points[i + 1]
		var dir := (pos - points[i]).normalized()
		var rails := _build_fence(pos, dir, fences[i].z, colors[i % 2], i + 1)
		_lines.append({"pos": pos, "dir": dir, "rails": rails, "height": fences[i].z})
	_start = {"pos": start_gate, "dir": (points[1] - start_gate).normalized()}
	_finish = {"pos": finish_gate, "dir": (finish_gate - points[points.size() - 2]).normalized()}
	_build_gate(_start, "START", Color(0.2, 0.7, 0.3))
	_build_gate(_finish, "FINISH", Color(0.85, 0.2, 0.2))


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var pos := _horse.global_position
	var from := Vector2(_last_pos.x, _last_pos.z)
	var to := Vector2(pos.x, pos.z)
	_last_pos = pos

	if _crossed(_start, from, to):
		_reset()
		state = State.RIDING
		announce.emit("Go!")
	if state != State.RIDING:
		return

	time += delta
	if next_fence < _lines.size():
		var line: Dictionary = _lines[next_fence]
		if _crossed(line, from, to):
			var hooves: float = _horse.height_above_ground()
			var knocked := 0
			for rail in line.rails:
				if hooves < rail.get_meta("height") - clearance:
					_knock_down(rail)
					knocked += 1
			if knocked:
				faults += 4
				announce.emit("Rail down! +4 faults")
			else:
				announce.emit("Clear!")
			next_fence += 1
	elif _crossed(_finish, from, to):
		state = State.DONE
		if faults == 0:
			announce.emit("Clear round! %.1f s" % time)
		else:
			announce.emit("Finished in %.1f s with %d faults" % [time, faults])
	_update_status()


## Did the horse ride across this line, in its riding direction, between two frames?
func _crossed(line: Dictionary, from: Vector2, to: Vector2) -> bool:
	var before: float = (from - line.pos).dot(line.dir)
	var after: float = (to - line.pos).dot(line.dir)
	if not (before < 0.0 and after >= 0.0):
		return false
	var across: float = absf((to - line.pos).cross(line.dir))
	return across < width * 0.5 + 0.5


func _reset() -> void:
	next_fence = 0
	faults = 0
	time = 0.0
	for line in _lines:
		for rail in line.rails:
			rail.position.y = rail.get_meta("height")
			rail.rotation = Vector3(0, 0, PI / 2)


func _knock_down(rail: Node3D) -> void:
	var tween := create_tween()
	tween.tween_property(rail, "position:y", 0.08, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(rail, "rotation:y", 0.3, 0.35)


func _update_status() -> void:
	match state:
		State.READY:
			status_changed.emit("Show jumping\nRide through the green START gate")
		State.RIDING:
			var next := "Fence %d" % (next_fence + 1) if next_fence < _lines.size() else "FINISH"
			status_changed.emit("Next: %s\nTime %.1f s   Faults %d" % [next, time, faults])
		State.DONE:
			status_changed.emit("Time %.1f s   Faults %d\nRide through START to go again" % [time, faults])


func _material(color: Color, roughness := 0.5) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat


func _node_at(pos: Vector2, dir: Vector2) -> Node3D:
	var node := Node3D.new()
	node.position = Vector3(pos.x, 0, pos.y)
	# Face so the fence spans across the riding direction.
	node.rotation.y = atan2(-dir.x, -dir.y)
	add_child(node)
	return node


func _build_fence(pos: Vector2, dir: Vector2, height: float, color: Color, number: int) -> Array:
	var node := _node_at(pos, dir)
	var stand := BoxMesh.new()
	stand.size = Vector3(0.18, 1.5, 0.45)
	for x in [-width * 0.5, width * 0.5]:
		var mi := MeshInstance3D.new()
		mi.mesh = stand
		mi.material_override = _material(Color(0.95, 0.95, 0.93))
		mi.position = Vector3(x, 0.75, 0)
		node.add_child(mi)
	var rails := []
	var rail_mesh := CylinderMesh.new()
	rail_mesh.top_radius = 0.06
	rail_mesh.bottom_radius = 0.06
	rail_mesh.height = width - 0.2
	rail_mesh.radial_segments = 10
	for h in [height, height * 0.55]:
		# Striped look: alternate the colour of the two rails.
		var rail := MeshInstance3D.new()
		rail.mesh = rail_mesh
		rail.material_override = _material(color if h == height else Color(0.96, 0.96, 0.96), 0.4)
		rail.position = Vector3(0, h, 0)
		rail.rotation = Vector3(0, 0, PI / 2)
		rail.set_meta("height", h)
		node.add_child(rail)
		rails.append(rail)
	var label := Label3D.new()
	label.text = str(number)
	label.font_size = 96
	label.outline_size = 18
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.position = Vector3(width * 0.5 + 0.1, 1.85, 0)
	node.add_child(label)
	return rails


func _build_gate(gate: Dictionary, text: String, color: Color) -> void:
	var node := _node_at(gate.pos, gate.dir)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.07
	pole.bottom_radius = 0.07
	pole.height = 3.0
	for x in [-width * 0.5 - 0.5, width * 0.5 + 0.5]:
		var mi := MeshInstance3D.new()
		mi.mesh = pole
		mi.material_override = _material(color)
		mi.position = Vector3(x, 1.5, 0)
		node.add_child(mi)
	var flag := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width + 1.0, 0.55, 0.05)
	flag.mesh = box
	flag.material_override = _material(color)
	flag.position.y = 2.75
	node.add_child(flag)
	for side in [1, -1]:
		var label := Label3D.new()
		label.text = text
		label.font_size = 64
		label.outline_size = 0
		label.position = Vector3(0, 2.75, 0.04 * side)
		label.rotation.y = 0.0 if side == 1 else PI
		node.add_child(label)
