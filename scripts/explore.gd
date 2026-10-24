extends Node3D
## Things to find in the countryside: the lake and the other places listed
## in world.gd's PLACES. Each place has a landmark, a name board and,
## until it is found, a golden light beam that can be seen from far away.
## Riding up to a place discovers it; the count is saved with the stable.

const Horse := preload("res://scripts/horse.gd")
const World := preload("res://scripts/world.gd")
const Rocks := preload("res://scripts/rocks.gd")
const FIND_DISTANCE := 15.0

@export var world_path: NodePath
@export var horse_path: NodePath
@export var hud_path: NodePath

var _world: World
var _horse: Node3D
var _hud: Node
var _beams := {}   ## Place id -> its light beam
var _sails: Node3D
var _grain: NoiseTexture2D


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
	Stable.earn(Stable.PLACE_COINS)
	var title: String = ("the " if place.get("the", false) else "") + place.name
	var found := Stable.discovered.size()
	var total: int = _world.PLACES.size()
	if _hud:
		if found == total:
			_hud.show_message("You found %s!\nYou've found every place!" % title)
		else:
			_hud.show_message("You found %s!\n%d of %d places   +%d coins" % [title, found, total, Stable.PLACE_COINS])
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


## Wood with a grain running along it, tinted `color`.
func _wood(color: Color) -> StandardMaterial3D:
	var mat := _material(color)
	if _grain == null:
		var noise := FastNoiseLite.new()
		noise.frequency = 0.05
		noise.fractal_octaves = 3
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.72, 0.68, 0.64))
		ramp.set_color(1, Color(1.08, 1.04, 1.0))
		_grain = NoiseTexture2D.new()
		_grain.noise = noise
		_grain.color_ramp = ramp
		_grain.seamless = true
	mat.albedo_texture = _grain
	mat.uv1_scale = Vector3(0.25, 3.0, 1.0)   # Stretched into long streaks
	return mat


## A lumpy rock or standing stone (rocks.gd).
func _rock(seed: int, stretch: Vector3, pos: Vector3, yaw := 0.0, size := 1.0, detail := 3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Rocks.grow(seed, stretch, 0.22, detail)
	mi.position = pos
	mi.rotation.y = yaw
	mi.scale = Vector3.ONE * size
	add_child(mi)
	return mi


## A rustic post-and-rail fence along a list of points.
func _fence(points: Array, wood: Material) -> void:
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var length := a.distance_to(b)
		var mid := (a + b) * 0.5
		var yaw := atan2(b.x - a.x, b.z - a.z)
		var post := _add(_cylinder(0.08, 0.1, 1.3, 6), wood, a + Vector3(0, 0.55, 0))
		post.rotation.z = randf_range(-0.04, 0.04)
		for h in [0.55, 1.0]:
			var rail := _add(_cylinder(0.05, 0.05, length + 0.2, 5), wood, mid + Vector3(0, h, 0))
			rail.rotation = Vector3(PI * 0.5, yaw, 0)
		_solid(Vector3(0.2, 1.4, length), mid + Vector3(0, 0.7, 0), yaw)
	_add(_cylinder(0.08, 0.1, 1.3, 6), wood, points[-1] + Vector3(0, 0.55, 0))


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
	var cattail := _material(Color(0.38, 0.24, 0.14), 1.0)
	for i in 90:
		var a := rng.randf() * TAU
		var r := _world.LAKE_RADIUS + rng.randf_range(-3.0, 1.0)
		var p := _world.LAKE_CENTER + Vector2(cos(a), sin(a)) * r
		if _world.trail_at(p.x, p.y) > 0.0 or (a > 2.6 and a < 3.4):
			continue   # Leave the jetty and the trail side open
		# A clump of three stalks, one with a brown cattail.
		for k in 3:
			var foot := Vector3(p.x + rng.randf_range(-0.25, 0.25), 0, p.y + rng.randf_range(-0.25, 0.25))
			foot.y = _world.height_at(foot.x, foot.z)
			var stalk := _add(reed, reed_mat, foot + Vector3(0, 0.7, 0))
			stalk.rotation = Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
			stalk.scale.y = rng.randf_range(0.8, 1.25)
			if k == 0:
				_add(_cylinder(0.05, 0.05, 0.3, 6), cattail, Vector3(0, 0.6, 0), stalk)


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
	var flowers := MultiMesh.new()
	flowers.transform_format = MultiMesh.TRANSFORM_3D
	flowers.use_colors = true
	flowers.mesh = _world.flower_mesh()
	flowers.instance_count = 1400
	for i in flowers.instance_count:
		var r := sqrt(rng.randf()) * 20.0
		var a := rng.randf() * TAU
		var x := spot.x + cos(a) * r
		var z := spot.z + sin(a) * r
		var s := rng.randf_range(1.7, 2.5)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
		flowers.set_instance_transform(i, Transform3D(b, Vector3(x, _world.height_at(x, z) - 0.02, z)))
		# Colours in drifts, like a planted meadow.
		var drift := int((a / TAU) * colors.size() + rng.randf_range(-0.4, 0.4) + colors.size()) % colors.size()
		flowers.set_instance_color(i, colors[drift])
	var flowers_mi := MultiMeshInstance3D.new()
	flowers_mi.multimesh = flowers
	flowers_mi.material_override = _world.flower_material()
	flowers_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flowers_mi)
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
	var tops := []
	for i in 9:
		var a := i * TAU / 9.0
		var p := spot + Vector3(cos(a), 0, sin(a)) * 8.0
		p.y = _world.height_at(p.x, p.z) - 0.3
		var height := rng.randf_range(2.6, 3.6)
		var stone := _rock(31 + i, Vector3(1.3, height / Rocks.HEIGHT, 0.7), p, -a + PI * 0.5)
		stone.rotation.x = rng.randf_range(-0.06, 0.06)
		stone.rotation.z = rng.randf_range(-0.06, 0.06)
		_solid(Vector3(1.2, height, 0.7), p + Vector3(0, height * 0.5, 0), stone.rotation.y)
		tops.append(p + Vector3(0, height - 0.1, 0))
	# Two pairs of stones carry a lintel across their tops.
	for pair in [[0, 1], [4, 5]]:
		var from: Vector3 = tops[pair[0]]
		var to: Vector3 = tops[pair[1]]
		var lintel := _rock(60 + pair[0], Vector3(from.distance_to(to) + 1.2, 0.7 / Rocks.HEIGHT, 0.8), (from + to) * 0.5)
		lintel.rotation.y = -atan2(to.z - from.z, to.x - from.x)
		lintel.position.y = minf(from.y, to.y) - 0.05
	# A fallen stone, half in the grass.
	var fallen := spot + Vector3(11, 0, 4)
	fallen.y = _world.height_at(fallen.x, fallen.z) - 0.25
	_rock(77, Vector3(3.0, 0.9, 1.2), fallen, 0.6)
	# The flat stone in the middle.
	_rock(80, Vector3(3.2, 0.55, 2.6), spot - Vector3(0, 0.05, 0))
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
	var plaster := _material(Color(0.93, 0.89, 0.8))
	var roof := _material(Color(0.5, 0.24, 0.2))
	var wood := _wood(Color(0.55, 0.38, 0.24))
	var dark_wood := _wood(Color(0.36, 0.24, 0.16))
	var cloth := _material(Color(0.97, 0.95, 0.9))
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var glass := _material(Color(0.35, 0.5, 0.6), 0.2)
	var base := spot - Vector3(0, 0.4, 0)
	# A stone foot, the white tower and a shingled cap.
	for i in 14:
		var a := i * TAU / 14.0
		_rock(200 + i, Vector3(1.3, 1.0, 0.9), base + Vector3(cos(a), 0.0, sin(a)) * 2.55, -a)
	_add(_cylinder(1.9, 2.5, 9.0, 20), plaster, base + Vector3(0, 4.5, 0))
	_add(_cylinder(2.1, 2.1, 0.25, 20), dark_wood, base + Vector3(0, 9.0, 0))
	var cap := _add(_cylinder(0.05, 2.35, 2.8, 20), roof, base + Vector3(0, 10.5, 0))
	cap.material_override = _shingles(Color(0.5, 0.24, 0.2))
	# A wooden gallery round the middle, with a railing.
	_add(_cylinder(3.3, 3.3, 0.15, 24), wood, base + Vector3(0, 4.6, 0))
	for i in 24:
		var a := i * TAU / 24.0
		_add(_box(Vector3(0.08, 0.9, 0.08)), dark_wood, base + Vector3(cos(a) * 3.2, 5.1, sin(a) * 3.2))
		var brace := _add(_box(Vector3(0.08, 1.6, 0.08)), dark_wood, base + Vector3(cos(a) * 2.6, 3.9, sin(a) * 2.6))
		brace.rotation = Vector3(0, -a, 0.6)
	var ring := TorusMesh.new()
	ring.inner_radius = 3.15
	ring.outer_radius = 3.25
	ring.rings = 32
	_add(ring, dark_wood, base + Vector3(0, 5.55, 0))
	# Door with a frame, and little windows.
	_add(_box(Vector3(1.5, 2.3, 0.2)), dark_wood, base + Vector3(0, 1.15, 2.4))
	_add(_box(Vector3(1.2, 2.0, 0.25)), wood, base + Vector3(0, 1.0, 2.42))
	for w in [[0.0, 6.8, 0.0], [PI * 0.5, 2.6, 0.0], [-PI * 0.5, 2.6, 0.0], [PI * 0.5, 7.0, 0.0]]:
		var window := Node3D.new()
		window.position = base + Vector3(0, w[1], 0)
		window.rotation.y = w[0]
		add_child(window)
		var r: float = 2.42 - (w[1] / 9.0) * 0.6 + 0.05
		_add(_box(Vector3(0.75, 0.95, 0.12)), dark_wood, Vector3(0, 0, r), window)
		_add(_box(Vector3(0.55, 0.75, 0.14)), glass, Vector3(0, 0, r), window)
	_solid(Vector3(4.6, 10.0, 4.6), base + Vector3(0, 5.0, 0))
	# Sails on a hub facing the trail (+Z), turning slowly in _process: a
	# long stock with a lattice frame and cloth on each.
	_sails = Node3D.new()
	_sails.position = base + Vector3(0, 8.4, 2.7)
	add_child(_sails)
	_add(_cylinder(0.32, 0.32, 0.6, 12), dark_wood, Vector3.ZERO, _sails).rotation.x = PI * 0.5
	for i in 4:
		var arm := Node3D.new()
		arm.rotation.z = i * PI * 0.5
		_sails.add_child(arm)
		_add(_box(Vector3(0.2, 6.0, 0.14)), wood, Vector3(0, 3.1, 0.1), arm)
		for b in 8:
			_add(_box(Vector3(1.4, 0.06, 0.06)), wood, Vector3(0.7, 1.4 + b * 0.62, 0.14), arm)
		_add(_box(Vector3(0.06, 4.5, 0.06)), wood, Vector3(1.38, 3.6, 0.14), arm)
		_add(_box(Vector3(1.25, 4.3, 0.02)), cloth, Vector3(0.68, 3.65, 0.19), arm)
	# Flour sacks by the door and a cart.
	var sack := _material(Color(0.86, 0.8, 0.66), 1.0)
	for p in [Vector3(1.6, 0, 3.2), Vector3(2.1, 0, 2.8), Vector3(1.85, 0.55, 3.0)]:
		var bag := _add(_sphere_mesh(0.35, 0.6), sack, base + p + Vector3(0, 0.3, 0))
		bag.rotation.y = p.x
	var cart := Node3D.new()
	cart.position = base + Vector3(-3.6, 0.0, 3.4)
	cart.rotation.y = 0.5
	add_child(cart)
	_add(_box(Vector3(1.4, 0.5, 2.2)), wood, Vector3(0, 0.75, 0), cart)
	for side in [-0.8, 0.8]:
		var wheel := _add(_cylinder(0.5, 0.5, 0.1, 14), dark_wood, Vector3(side, 0.5, 0), cart)
		wheel.rotation.z = PI * 0.5
	_add(_box(Vector3(0.08, 0.08, 1.6)), dark_wood, Vector3(0.3, 0.55, 1.8), cart)
	_add(_box(Vector3(0.08, 0.08, 1.6)), dark_wood, Vector3(-0.3, 0.55, 1.8), cart)
	_solid(Vector3(1.8, 1.2, 2.4), cart.position + Vector3(0, 0.6, 0), cart.rotation.y)


## Roof shingles: rows of darker lines round a cone.
func _shingles(color: Color) -> StandardMaterial3D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var row := y % 8
			var offset := 4 if (y / 8) % 2 == 0 else 0
			var shade := 1.0
			if row == 7 or (x + offset) % 8 == 0:
				shade = 0.62
			elif row > 4:
				shade = 0.85
			image.set_pixel(x, y, Color(shade, shade, shade))
	image.generate_mipmaps()
	var mat := _material(color)
	mat.albedo_texture = ImageTexture.create_from_image(image)
	mat.uv1_scale = Vector3(6, 5, 1)
	return mat


func _sphere_mesh(radius: float, height: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 6
	return mesh


func _build_lookout(spot: Vector3) -> void:
	var wood := _wood(Color(0.5, 0.34, 0.22))
	# Rocks poking out of the hilltop.
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in 7:
		var a := i * TAU / 7.0 + rng.randf_range(-0.3, 0.3)
		var p := spot + Vector3(cos(a), 0, sin(a)) * rng.randf_range(8.5, 10.5)   # Clear of Old Sam's horseshoe
		p.y = _world.height_at(p.x, p.z) - 0.3
		var size := rng.randf_range(1.2, 2.4)
		_rock(400 + i, Vector3(1.4, 0.8, 1.1), p, rng.randf() * TAU, size)
		_solid(Vector3(1.2, 1.0, 1.0) * size, p + Vector3(0, 0.4 * size, 0))
	# A bench looking out over the countryside.
	var bench := Node3D.new()
	bench.position = spot + Vector3(2, 0, 2)
	bench.rotation.y = PI * 0.25
	add_child(bench)
	_add(_box(Vector3(2.2, 0.1, 0.5)), wood, Vector3(0, 0.5, 0), bench)
	_add(_box(Vector3(2.2, 0.35, 0.08)), wood, Vector3(0, 0.85, -0.22), bench)
	for x in [-0.9, 0.9]:
		_add(_box(Vector3(0.1, 0.5, 0.45)), wood, Vector3(x, 0.25, 0), bench)
	# A brass telescope on a wooden tripod.
	var brass := _material(Color(0.85, 0.65, 0.3), 0.3)
	brass.metallic = 0.8
	var scope := Node3D.new()
	scope.position = spot + Vector3(-1.5, 0, 3.0)
	scope.rotation.y = 0.8
	add_child(scope)
	for i in 3:
		var leg := _add(_cylinder(0.03, 0.04, 1.5, 5), wood, Vector3(cos(i * TAU / 3) * 0.3, 0.7, sin(i * TAU / 3) * 0.3), scope)
		leg.rotation = Vector3(sin(i * TAU / 3) * 0.2, 0, -cos(i * TAU / 3) * 0.2)
	var tube := _add(_cylinder(0.07, 0.11, 1.1, 12), brass, Vector3(0, 1.5, 0.2), scope)
	tube.rotation.x = PI * 0.5 - 0.15
	# A flag on a tall pole, rippling in the wind.
	_add(_cylinder(0.06, 0.08, 7.0, 8), _material(Color(0.92, 0.92, 0.9)), spot + Vector3(-2, 3.5, -1))
	_add(_sphere_mesh(0.12, 0.24), brass, spot + Vector3(-2, 7.05, -1))
	var cloth := PlaneMesh.new()
	cloth.size = Vector2(1.8, 1.0)
	cloth.orientation = PlaneMesh.FACE_Z
	cloth.subdivide_width = 12
	cloth.subdivide_depth = 4
	var flag_mat := ShaderMaterial.new()
	flag_mat.shader = preload("res://shaders/flag.gdshader")
	_add(cloth, flag_mat, spot + Vector3(-1.05, 6.4, -1))


func _build_wild_horses(spot: Vector3) -> void:
	# Three horses of the stable's coats, standing about in their meadow.
	var coats := [3, 4, 2]   # Grey, palomino, black (see stable_data.gd)
	var offsets := [Vector3(-4, 0, 1), Vector3(3, 0, -3), Vector3(5, 0, 4)]
	for i in 3:
		var horse := Horse.new()
		horse.with_rider = false
		var coat: Dictionary = Stable.HORSES[coats[i]]
		horse.with_tack = false   # Wild horses
		var p: Vector3 = spot + offsets[i]
		p.y = _world.height_at(p.x, p.z)
		horse.position = p
		horse.rotation.y = i * 2.1 + 0.4
		add_child(horse)
		horse.set_physics_process(false)   # Scenery, not ridden
		horse.show_coat(coat)
		horse.set_dirt(0.15)
		horse.stand()
		_solid(Vector3(1.0, 1.8, 2.4), p + Vector3(0, 0.9, 0), horse.rotation.y)
	# A hay rack for them.
	var wood := _material(Color(0.5, 0.34, 0.22))
	var hay := _material(Color(0.85, 0.72, 0.38), 1.0)
	_add(_box(Vector3(2.4, 0.9, 1.0)), wood, spot + Vector3(0, 0.45, -7))
	_add(_box(Vector3(2.2, 0.5, 0.9)), hay, spot + Vector3(0, 1.1, -7))
	_solid(Vector3(2.4, 1.4, 1.0), spot + Vector3(0, 0.7, -7))
	# A water trough, and a rustic fence round most of the meadow, open
	# towards the trail.
	var trough := _wood(Color(0.42, 0.3, 0.2))
	_add(_box(Vector3(2.6, 0.6, 0.8)), trough, spot + Vector3(6, 0.3, -4))
	var water := _material(Color(0.35, 0.55, 0.7), 0.05)
	_add(_box(Vector3(2.4, 0.05, 0.6)), water, spot + Vector3(6, 0.56, -4))
	_solid(Vector3(2.6, 1.0, 0.8), spot + Vector3(6, 0.5, -4))
	var opening := atan2(-spot.z, -spot.x)   # Towards the world centre
	var fence_wood := _wood(Color(0.48, 0.34, 0.22))
	var points := []
	for i in 23:
		var a := opening + 0.45 + i * (TAU - 0.9) / 22.0
		var p := spot + Vector3(cos(a), 0, sin(a)) * 13.0
		p.y = _world.height_at(p.x, p.z)
		if _world.trail_at(p.x, p.z) > 0.0:   # Leave the trail open
			if points.size() > 1:
				_fence(points, fence_wood)
			points = []
			continue
		points.append(p)
	if points.size() > 1:
		_fence(points, fence_wood)
