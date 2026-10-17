extends Node3D
## Things to find in the countryside: the lake and the other places listed
## in world.gd's PLACES. Each place has a landmark, a name board and,
## until it is found, a golden light beam that can be seen from far away.
## Riding up to a place discovers it; the count is saved with the stable.

const Horse := preload("res://scripts/horse.gd")
const World := preload("res://scripts/world.gd")
const FIND_DISTANCE := 15.0

@export var world_path: NodePath
@export var horse_path: NodePath
@export var hud_path: NodePath

var _world: World
var _horse: Node3D
var _hud: Node
var _beams := {}   ## Place id -> its light beam
var _sails: Node3D


func _ready() -> void:
	_world = get_node(world_path)
	_horse = get_node(horse_path)
	_hud = get_node_or_null(hud_path)
	_build_lake()
	for place in _world.PLACES:
		var spot := _ground(place.pos)
		match place.id:
			"lake": _build_jetty()
			"flowers": _build_flower_valley(spot)
			"stones": _build_stone_circle(spot)
			"windmill": _build_windmill(spot)
			"lookout": _build_lookout(spot)
			"wild": _build_wild_horses(spot)
		if place.id != "lake":
			_build_name_board(place.name, spot + Vector3(-6, 0, 9))
		if not place.id in Stable.discovered:
			_beams[place.id] = _build_beam(spot)
	_build_trail_sign()
	_update_count()


func _process(delta: float) -> void:
	if _sails:
		_sails.rotation.z += 0.4 * delta
	var at := Vector2(_horse.global_position.x, _horse.global_position.z)
	for place in _world.PLACES:
		if place.id in Stable.discovered:
			continue
		var reach := FIND_DISTANCE + (_world.LAKE_RADIUS if place.id == "lake" else 0.0)
		if at.distance_to(place.pos) < reach:
			_discover(place)


func _discover(place: Dictionary) -> void:
	if not Stable.discover(place.id):
		return
	var title: String = ("the " if place.get("the", false) else "") + place.name
	var found := Stable.discovered.size()
	var total: int = _world.PLACES.size()
	if _hud:
		if found == total:
			_hud.show_message("You found %s!\nYou've found every place!" % title)
		else:
			_hud.show_message("You found %s!\n%d of %d places" % [title, found, total])
	_update_count()
	if _beams.has(place.id):
		var beam: Node3D = _beams[place.id]
		_beams.erase(place.id)
		var tween := create_tween()
		tween.tween_property(beam, "scale", Vector3(3.0, 1.0, 3.0), 0.8)
		tween.parallel().tween_property(beam, "transparency", 1.0, 0.8)
		tween.tween_callback(beam.queue_free)


func _update_count() -> void:
	if _hud:
		_hud.set_explore_text("Places found: %d of %d" % [Stable.discovered.size(), _world.PLACES.size()])


func _ground(pos: Vector2) -> Vector3:
	return Vector3(pos.x, _world.height_at(pos.x, pos.y), pos.y)


# --- Building blocks ----------------------------------------------------------

func _material(color: Color, roughness := 0.85) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat


func _add(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _box(size: Vector3) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	return box


func _cylinder(top: float, bottom: float, height: float, segments := 12) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	return mesh


## A solid block the horse bumps into instead of walking through.
func _solid(size: Vector3, pos: Vector3, yaw := 0.0) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	body.rotation.y = yaw
	add_child(body)


## A tall soft golden beam marking a place not found yet.
func _build_beam(spot: Vector3) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1.0, 0.85, 0.4, 0.35)
	mat.disable_fog = true
	return _add(_cylinder(1.2, 1.2, 60.0, 16), mat, spot + Vector3(0, 30, 0))


func _build_name_board(text: String, spot: Vector3) -> void:
	var wood := _material(Color(0.5, 0.33, 0.2))
	var board := Node3D.new()
	board.position = spot
	add_child(board)
	for x in [-1.1, 1.1]:
		_add(_box(Vector3(0.12, 1.6, 0.12)), wood, Vector3(x, 0.8, 0), board)
	_add(_box(Vector3(2.8, 0.7, 0.08)), wood, Vector3(0, 1.35, 0), board)
	for side in [1.0, -1.0]:
		var label := Label3D.new()
		label.text = text
		label.font_size = 64
		label.pixel_size = 0.005
		label.modulate = Color(1, 0.96, 0.85)
		label.outline_size = 12
		label.outline_modulate = Color(0.25, 0.15, 0.08)
		label.position = Vector3(0, 1.35, 0.05 * side)
		label.rotation.y = 0.0 if side > 0 else PI
		board.add_child(label)
	# Face the board towards the trail's general direction (the world centre).
	board.look_at(Vector3(0, spot.y, 0), Vector3.UP, true)


func _build_trail_sign() -> void:
	var spot := _ground(Vector2(-6, 16))
	_build_name_board("Trail: explore!", spot)


# --- Places -------------------------------------------------------------------

func _build_lake() -> void:
	var water := MeshInstance3D.new()
	water.name = "Lake"
	water.mesh = _cylinder(_world.LAKE_RADIUS + 6.0, _world.LAKE_RADIUS + 6.0, 0.02, 64)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/water.gdshader")
	mat.set_shader_parameter("centre", _world.LAKE_CENTER)
	mat.set_shader_parameter("radius", _world.LAKE_RADIUS)
	water.material_override = mat
	water.position = Vector3(_world.LAKE_CENTER.x, _world.WATER_LEVEL, _world.LAKE_CENTER.y)
	add_child(water)

	# Lily pads and reeds around the edge.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var pad := _cylinder(0.5, 0.5, 0.03, 10)
	var pad_mat := _material(Color(0.25, 0.55, 0.2))
	var bloom := _material(Color(1.0, 0.75, 0.85))
	bloom.emission_enabled = true
	bloom.emission = Color(0.3, 0.1, 0.15)
	for i in 26:
		var a := rng.randf() * TAU
		var r := rng.randf_range(_world.LAKE_RADIUS * 0.45, _world.LAKE_RADIUS * 0.85)
		var p := _world.LAKE_CENTER + Vector2(cos(a), sin(a)) * r
		var lily := _add(pad, pad_mat, Vector3(p.x, _world.WATER_LEVEL + 0.03, p.y))
		lily.scale = Vector3.ONE * rng.randf_range(0.7, 1.3)
		if i % 3 == 0:
			_add(_cylinder(0.0, 0.16, 0.14, 6), bloom, lily.position + Vector3(0, 0.08, 0))
	var reed := _cylinder(0.02, 0.04, 1.6, 4)
	var reed_mat := _material(Color(0.4, 0.5, 0.2))
	for i in 90:
		var a := rng.randf() * TAU
		var r := _world.LAKE_RADIUS + rng.randf_range(-3.0, 1.0)
		var p := _world.LAKE_CENTER + Vector2(cos(a), sin(a)) * r
		if _world.trail_at(p.x, p.y) > 0.0 or (a > 2.6 and a < 3.4):
			continue   # Leave the jetty and the trail side open
		var stalk := _add(reed, reed_mat, Vector3(p.x, _world.height_at(p.x, p.y) + 0.7, p.y))
		stalk.rotation = Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15))


## A wooden jetty from the west shore out over the water.
func _build_jetty() -> void:
	var wood := _material(Color(0.55, 0.38, 0.24))
	var start := _world.LAKE_CENTER + Vector2(-_world.LAKE_RADIUS - 3.0, 0)
	var y: float = _world.WATER_LEVEL + 0.45
	for i in 12:
		var x := start.x + i * 1.0 + 0.5
		_add(_box(Vector3(0.9, 0.1, 2.4)), wood, Vector3(x, y, start.y))
	for i in range(0, 13, 3):
		for side in [-1.1, 1.1]:
			_add(_cylinder(0.1, 0.1, 1.6, 6), wood, Vector3(start.x + i, y - 0.6, start.y + side))


func _build_flower_valley(spot: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var colors := [Color(0.95, 0.3, 0.45), Color(1.0, 0.85, 0.2), Color(0.65, 0.45, 0.95), Color(1, 1, 1), Color(1.0, 0.55, 0.2)]
	var head := SphereMesh.new()
	head.radius = 0.2
	head.height = 0.24
	head.radial_segments = 6
	head.rings = 3
	var stem := _cylinder(0.015, 0.02, 0.5, 4)
	var heads := MultiMesh.new()
	heads.transform_format = MultiMesh.TRANSFORM_3D
	heads.use_colors = true
	heads.mesh = head
	heads.instance_count = 900
	var stems := MultiMesh.new()
	stems.transform_format = MultiMesh.TRANSFORM_3D
	stems.mesh = stem
	stems.instance_count = 900
	for i in 900:
		var r := sqrt(rng.randf()) * 20.0
		var a := rng.randf() * TAU
		var x := spot.x + cos(a) * r
		var z := spot.z + sin(a) * r
		var h := rng.randf_range(0.35, 0.6)
		var y: float = _world.height_at(x, z)
		stems.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(1, h / 0.5, 1)), Vector3(x, y + h * 0.5, z)))
		heads.set_instance_transform(i, Transform3D(Basis(), Vector3(x, y + h, z)))
		# Colours in drifts, like a planted meadow.
		var drift := int((a / TAU) * colors.size() + rng.randf_range(-0.4, 0.4) + colors.size()) % colors.size()
		heads.set_instance_color(i, colors[drift])
	var head_mat := StandardMaterial3D.new()
	head_mat.vertex_color_use_as_albedo = true
	head_mat.roughness = 0.6
	var heads_mi := MultiMeshInstance3D.new()
	heads_mi.multimesh = heads
	heads_mi.material_override = head_mat
	add_child(heads_mi)
	var stems_mi := MultiMeshInstance3D.new()
	stems_mi.multimesh = stems
	stems_mi.material_override = _material(Color(0.18, 0.4, 0.12))
	add_child(stems_mi)
	_butterflies(spot)


## A few fluttering butterflies over the flowers.
func _butterflies(spot: Vector3) -> void:
	var particles := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.12)
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	particles.mesh = quad
	particles.amount = 24
	particles.lifetime = 6.0
	particles.preprocess = 6.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(16, 0.6, 16)
	particles.direction = Vector3(1, 0.3, 0)
	particles.spread = 180.0
	particles.initial_velocity_min = 0.3
	particles.initial_velocity_max = 0.8
	particles.gravity = Vector3.ZERO
	particles.tangential_accel_min = -0.5
	particles.tangential_accel_max = 0.5
	var colors := Gradient.new()
	colors.set_color(0, Color(1.0, 0.6, 0.2))
	colors.set_color(1, Color(0.7, 0.5, 1.0))
	particles.color_initial_ramp = colors
	particles.position = spot + Vector3(0, 1.2, 0)
	add_child(particles)


func _build_stone_circle(spot: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var stone := _material(Color(0.62, 0.62, 0.6), 0.95)
	var moss := _material(Color(0.42, 0.5, 0.35), 0.95)
	for i in 9:
		var a := i * TAU / 9.0
		var p := spot + Vector3(cos(a), 0, sin(a)) * 8.0
		p.y = _world.height_at(p.x, p.z)
		var size := Vector3(rng.randf_range(0.9, 1.3), rng.randf_range(2.4, 3.4), 0.6)
		var block := _add(_box(size), stone if i % 3 else moss, p + Vector3(0, size.y * 0.5 - 0.2, 0))
		block.rotation = Vector3(rng.randf_range(-0.08, 0.08), -a + PI * 0.5, rng.randf_range(-0.08, 0.08))
		_solid(size, block.position, block.rotation.y)
	# A flat stone in the middle with magic sparkles over it.
	_add(_cylinder(1.4, 1.6, 0.4, 10), stone, spot + Vector3(0, 0.1, 0))
	var sparkles := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.7, 0.85, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.8, 1.0)
	mat.emission_energy_multiplier = 3.0
	quad.material = mat
	sparkles.mesh = quad
	sparkles.amount = 40
	sparkles.lifetime = 3.0
	sparkles.preprocess = 3.0
	sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparkles.emission_sphere_radius = 1.4
	sparkles.direction = Vector3.UP
	sparkles.spread = 20.0
	sparkles.initial_velocity_min = 0.3
	sparkles.initial_velocity_max = 0.7
	sparkles.gravity = Vector3.ZERO
	sparkles.position = spot + Vector3(0, 0.6, 0)
	add_child(sparkles)


func _build_windmill(spot: Vector3) -> void:
	var stone := _material(Color(0.86, 0.82, 0.74))
	var roof := _material(Color(0.55, 0.25, 0.2))
	var wood := _material(Color(0.5, 0.34, 0.22))
	var cloth := _material(Color(0.96, 0.94, 0.88))
	var base := spot - Vector3(0, 0.4, 0)
	_add(_cylinder(1.9, 2.6, 9.0, 16), stone, base + Vector3(0, 4.5, 0))
	_add(_cylinder(0.0, 2.4, 2.6, 16), roof, base + Vector3(0, 10.3, 0))
	_add(_box(Vector3(1.2, 2.0, 0.3)), wood, base + Vector3(0, 1.0, 2.45))   # Door
	_solid(Vector3(4.6, 10.0, 4.6), base + Vector3(0, 5.0, 0))
	# Sails on a hub facing the trail (+Z), turning slowly in _process.
	_sails = Node3D.new()
	_sails.position = base + Vector3(0, 8.4, 2.5)
	add_child(_sails)
	_add(_cylinder(0.3, 0.3, 0.5, 10), wood, Vector3.ZERO, _sails).rotation.x = PI * 0.5
	for i in 4:
		var arm := Node3D.new()
		arm.rotation.z = i * PI * 0.5
		_sails.add_child(arm)
		_add(_box(Vector3(0.18, 5.6, 0.12)), wood, Vector3(0, 2.9, 0.1), arm)
		_add(_box(Vector3(1.1, 4.2, 0.04)), cloth, Vector3(0.65, 3.4, 0.12), arm)


func _build_lookout(spot: Vector3) -> void:
	var wood := _material(Color(0.5, 0.34, 0.22))
	# A bench looking out over the countryside.
	var bench := Node3D.new()
	bench.position = spot + Vector3(2, 0, 2)
	bench.rotation.y = PI * 0.25
	add_child(bench)
	_add(_box(Vector3(2.2, 0.1, 0.5)), wood, Vector3(0, 0.5, 0), bench)
	_add(_box(Vector3(2.2, 0.5, 0.08)), wood, Vector3(0, 0.85, -0.22), bench)
	for x in [-0.9, 0.9]:
		_add(_box(Vector3(0.1, 0.5, 0.45)), wood, Vector3(x, 0.25, 0), bench)
	# A flag on a tall pole.
	_add(_cylinder(0.06, 0.08, 7.0, 8), _material(Color(0.9, 0.9, 0.88)), spot + Vector3(-2, 3.5, -1))
	var flag := _material(Color(0.95, 0.4, 0.6))
	flag.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add(_box(Vector3(1.6, 0.9, 0.03)), flag, spot + Vector3(-1.15, 6.4, -1))


func _build_wild_horses(spot: Vector3) -> void:
	# Three horses of the stable's coats, standing about in their meadow.
	var coats := [3, 4, 2]   # Grey, palomino, black (see stable_data.gd)
	var offsets := [Vector3(-4, 0, 1), Vector3(3, 0, -3), Vector3(5, 0, 4)]
	for i in 3:
		var horse := Horse.new()
		horse.with_rider = false
		var coat: Dictionary = Stable.HORSES[coats[i]]
		horse.coat_color = coat.body
		horse.points_color = coat.points
		horse.coat_strength = coat.strength
		var p: Vector3 = spot + offsets[i]
		p.y = _world.height_at(p.x, p.z)
		horse.position = p
		horse.rotation.y = i * 2.1 + 0.4
		add_child(horse)
		horse.set_physics_process(false)   # Scenery, not ridden
		horse.set_coat(coat.body, coat.points, coat.strength)
		horse.set_dirt(0.15)
		horse.stand()
		_solid(Vector3(1.0, 1.8, 2.4), p + Vector3(0, 0.9, 0), horse.rotation.y)
	# A hay rack for them.
	var wood := _material(Color(0.5, 0.34, 0.22))
	var hay := _material(Color(0.85, 0.72, 0.38), 1.0)
	_add(_box(Vector3(2.4, 0.9, 1.0)), wood, spot + Vector3(0, 0.45, -7))
	_add(_box(Vector3(2.2, 0.5, 0.9)), hay, spot + Vector3(0, 1.1, -7))
	_solid(Vector3(2.4, 1.4, 1.0), spot + Vector3(0, 0.7, -7))
