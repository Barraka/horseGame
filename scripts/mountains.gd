extends Node3D
## The snowy mountains north of the hills (see world.gd): the three places
## to find there, the Frozen Lake, the Mountain Hut and the Frozen Falls,
## a snowman, poles marking the track through the valley, and snow falling
## around you while you're up there (heavier when it would rain below).
## explore.gd adds the places' name boards and discovers them.

const World := preload("res://scripts/world.gd")
const Rocks := preload("res://scripts/rocks.gd")
const POLE_GAP := 14.0       ## Metres between the track's marker poles

@export var world_path: NodePath

var _world: World
var _rng := RandomNumberGenerator.new()
var _snowfall: GPUParticles3D
var _windows: StandardMaterial3D   # The hut's windows, glowing at night
var _hut_light: OmniLight3D
var _sky: Node


func _ready() -> void:
	_world = get_node(world_path)
	_sky = get_node_or_null("../SkyCycle")
	_rng.seed = 31
	for place in World.PLACES:
		var spot := _ground(place.pos)
		match place.id:
			"frozen_lake": _build_frozen_lake(spot)
			"hut": _build_hut(spot)
			"falls": _build_falls(spot)
	_build_poles()
	_build_pass_sign()
	_snowfall = _snow_particles()
	add_child(_snowfall)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var at := camera.global_position
	var snowy := World.snow_at(at.x, at.z)
	var rain: float = _sky.rain if _sky else 0.0
	if _sky and "snow_zone" in _sky:
		_sky.snow_zone = snowy
	_snowfall.global_position = at + Vector3(0, 9, 0) - camera.global_basis.z * 5.0
	_snowfall.amount_ratio = clampf((0.35 + rain * 0.65) * snowy, 0.0, 1.0)
	_snowfall.emitting = snowy > 0.15
	if _windows:
		var night: float = 1.0 - _sky.daylight() if _sky else 0.0
		_windows.emission_energy_multiplier = lerpf(0.6, 3.0, night)
		_hut_light.light_energy = lerpf(0.0, 1.6, night)


func _ground(pos: Vector2) -> Vector3:
	return Vector3(pos.x, _world.height_at(pos.x, pos.y), pos.y)


# --- The places -------------------------------------------------------------------

func _build_frozen_lake(spot: Vector3) -> void:
	var ice := MeshInstance3D.new()
	ice.name = "Ice"
	ice.mesh = _cylinder(World.ICE_RADIUS + 1.5, World.ICE_RADIUS + 1.5, 0.08, 48)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/ice.gdshader")
	var grain := NoiseTexture2D.new()
	grain.seamless = true
	grain.width = 256
	grain.height = 256
	var noise := FastNoiseLite.new()
	noise.frequency = 0.03
	noise.fractal_octaves = 4
	grain.noise = noise
	mat.set_shader_parameter("grain", grain)
	mat.set_shader_parameter("radius", World.ICE_RADIUS + 1.5)
	ice.material_override = mat
	ice.position = Vector3(spot.x, World.ICE_LEVEL + 0.02, spot.z)
	add_child(ice)
	# Snowy rocks round the shore, and a little wooden bench to sit on.
	for i in 12:
		var a := i * TAU / 12.0 + _rng.randf_range(-0.2, 0.2)
		if absf(wrapf(a - 2.4, -PI, PI)) < 0.5:
			continue   # Keep the track's side clear
		var p := Vector2(spot.x, spot.z) + Vector2(cos(a), sin(a)) * (World.ICE_RADIUS + _rng.randf_range(3.0, 6.0))
		var size := _rng.randf_range(0.8, 1.8)
		_rock(500 + i, Vector3(1.2, 0.7, 1.0), _ground(p) - Vector3(0, size * 0.3, 0), a, size)
	var bench := Node3D.new()
	bench.position = _ground(Vector2(spot.x - 22.0, spot.z + 18.0))
	bench.rotation.y = -0.85
	add_child(bench)
	var wood := _material(Color(0.42, 0.28, 0.17))
	_add(_box(Vector3(1.8, 0.08, 0.45)), wood, Vector3(0, 0.48, 0), bench)
	_add(_box(Vector3(1.8, 0.4, 0.06)), wood, Vector3(0, 0.78, -0.2), bench)
	_add(_box(Vector3(1.8, 0.05, 0.4)), _material(Color(0.95, 0.96, 1.0), 0.6), Vector3(0, 0.54, 0.02), bench)
	for side in [-0.75, 0.75]:
		_add(_box(Vector3(0.08, 0.48, 0.4)), wood, Vector3(side, 0.24, 0), bench)


func _build_hut(spot: Vector3) -> void:
	var hut := Node3D.new()
	hut.name = "MountainHut"
	hut.position = spot + Vector3(0, -0.2, 0)
	hut.rotation.y = -1.15   # Facing the track
	add_child(hut)
	var log_mat := _material(Color(0.5, 0.33, 0.19))
	var dark := _material(Color(0.3, 0.2, 0.12))
	var snow := _material(Color(0.94, 0.96, 1.0), 0.55)
	var stone := _material(Color(0.5, 0.5, 0.52))
	const W := 6.0
	const D := 4.6
	const LOGS := 8
	const LOG := 0.32
	_add(_box(Vector3(W + 0.6, 0.5, D + 0.6)), stone, Vector3(0, 0.25, 0), hut)
	# Log walls, with the ends sticking out at the corners. The front has a
	# door and two windows.
	for i in LOGS:
		var y := 0.5 + LOG * 0.5 + i * LOG * 0.92
		for side in [-1.0, 1.0]:
			var along := _add(_cylinder(LOG * 0.5, LOG * 0.5, W + 0.7, 8), log_mat, Vector3(0, y, side * D * 0.5), hut)
			along.rotation.z = PI / 2
			if side > 0.0 and i < 6:
				along.visible = false   # The front, built in pieces below
			var across := _add(_cylinder(LOG * 0.5, LOG * 0.5, D + 0.7, 8), log_mat, Vector3(side * W * 0.5, y + LOG * 0.46, 0), hut)
			across.rotation.x = PI / 2
		if i < 6:
			# The front in pieces, leaving gaps for the door and windows.
			var gaps := [Vector2(-0.55, 0.55)]
			if i >= 2 and i <= 4:
				gaps = [Vector2(-2.25, -1.25), Vector2(-0.55, 0.55), Vector2(1.25, 2.25)]
			var from := -W * 0.5 - 0.35
			for gap in gaps + [Vector2(W * 0.5 + 0.35, 0.0)]:
				var to: float = gap.x
				if to > from:
					var front := _add(_cylinder(LOG * 0.5, LOG * 0.5, to - from, 8), log_mat, Vector3((from + to) * 0.5, y, D * 0.5), hut)
					front.rotation.z = PI / 2
				from = gap.y
	var top := 0.5 + LOGS * LOG * 0.92
	# Gables and roof: two steep slopes thick with snow, and icicles along
	# the eaves.
	var gable := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(-W * 0.5, 0, 0), Vector3(0, 1.9, 0), Vector3(W * 0.5, 0, 0)]:
		st.add_vertex(v)
	st.generate_normals()
	gable = st.commit()
	for side in [-1.0, 1.0]:
		var end := _add(gable, log_mat, Vector3(0, top, side * D * 0.5), hut)
		end.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in [-1.0, 1.0]:
		var slope := Node3D.new()
		slope.position = Vector3(side * W * 0.25, top + 0.95, 0)
		slope.rotation.z = -side * atan2(1.9, W * 0.5)
		hut.add_child(slope)
		var length := Vector2(W * 0.5, 1.9).length() + 0.6
		_add(_box(Vector3(length, 0.16, D + 1.2)), dark, Vector3(0, 0.1, 0), slope)
		_add(_box(Vector3(length + 0.1, 0.32, D + 1.3)), snow, Vector3(0, 0.32, 0), slope)
		for k in 9:
			var icicle := _add(_cylinder(0.0, 0.06, _rng.randf_range(0.25, 0.6), 5), _ice_material(), Vector3(0, 0, 0), hut)
			var drop: float = icicle.mesh.height
			icicle.position = Vector3(side * (W * 0.5 + 0.35), top - 0.15 - drop * 0.5, -D * 0.5 - 0.3 + k * (D + 0.6) / 8.0)
	_add(_box(Vector3(0.4, 0.2, D + 1.4)), snow, Vector3(0, top + 1.95, 0), hut)
	# Chimney, with smoke.
	_add(_box(Vector3(0.7, 1.6, 0.7)), stone, Vector3(-1.4, top + 1.6, -0.9), hut)
	_add(_box(Vector3(0.8, 0.18, 0.8)), snow, Vector3(-1.4, top + 2.45, -0.9), hut)
	var smoke := _smoke_particles()
	smoke.position = Vector3(-1.4, top + 2.6, -0.9)
	hut.add_child(smoke)
	# Door, windows that glow at night, a lantern.
	_add(_box(Vector3(0.95, 1.85, 0.08)), dark, Vector3(0, 1.45, D * 0.5 + 0.12), hut)
	_add(_sphere(0.05), _material(Color(0.85, 0.7, 0.3), 0.3), Vector3(0.32, 1.4, D * 0.5 + 0.18), hut)
	_windows = _material(Color(1.0, 0.85, 0.5), 0.4)
	_windows.emission_enabled = true
	_windows.emission = Color(1.0, 0.75, 0.4)
	for x in [-1.75, 1.75]:
		_add(_box(Vector3(0.9, 0.75, 0.05)), _windows, Vector3(x, 1.65, D * 0.5 + 0.1), hut)
		_add(_box(Vector3(1.05, 0.08, 0.12)), dark, Vector3(x, 1.25, D * 0.5 + 0.14), hut)
		_add(_box(Vector3(0.05, 0.75, 0.07)), dark, Vector3(x, 1.65, D * 0.5 + 0.13), hut)
		_add(_box(Vector3(1.0, 0.07, 0.2)), snow, Vector3(x, 1.3, D * 0.5 + 0.2), hut)
	_hut_light = OmniLight3D.new()
	_hut_light.light_color = Color(1.0, 0.75, 0.45)
	_hut_light.omni_range = 7.0
	_hut_light.position = Vector3(0, 2.0, D * 0.5 + 1.0)
	hut.add_child(_hut_light)
	# A woodpile by the wall, a sled, and a little porch step.
	_add(_box(Vector3(1.6, 0.25, 1.0)), stone, Vector3(0, 0.12, D * 0.5 + 0.8), hut)
	for row in 4:
		for k in 6 - row:
			var piece := _add(_cylinder(0.14, 0.14, 0.9, 7), _material(Color(0.6, 0.45, 0.3)), Vector3(W * 0.5 + 0.7, 0.62 + row * 0.25, -1.2 + k * 0.3 + row * 0.15), hut)
			piece.rotation.x = PI / 2
	_add(_box(Vector3(0.6, 0.12, 2.0)), snow, Vector3(W * 0.5 + 0.7, 1.62, -0.45), hut)
	var sled := Node3D.new()
	sled.position = Vector3(-W * 0.5 - 0.5, 0.75, 1.2)
	sled.rotation.z = 1.2
	hut.add_child(sled)
	var red := _material(Color(0.78, 0.15, 0.13), 0.5)
	_add(_box(Vector3(0.06, 0.6, 1.5)), red, Vector3(0, 0, 0), sled)
	for side in [-0.25, 0.25]:
		_add(_box(Vector3(0.2, 0.05, 1.6)), _material(Color(0.25, 0.25, 0.28), 0.3), Vector3(0.12, side * 1.2, 0), sled)
	_solid(Vector3(W + 0.6, 4.0, D + 0.6), hut.position + Vector3(0, 2.0, 0), hut.rotation.y)
	_build_snowman(hut.to_global(Vector3(4.5, 0, D * 0.5 + 4.0)))


## A snowman with a carrot nose, a red scarf and a little hat.
func _build_snowman(at: Vector3) -> void:
	var man := Node3D.new()
	man.name = "Snowman"
	man.position = Vector3(at.x, _world.height_at(at.x, at.z) - 0.1, at.z)
	man.rotation.y = 0.6
	add_child(man)
	var snow := _material(Color(0.95, 0.97, 1.0), 0.6)
	var coal := _material(Color(0.08, 0.08, 0.09), 0.4)
	var y := 0.0
	for radius in [0.62, 0.45, 0.32]:
		y += radius * 0.85
		_add(_sphere(radius), snow, Vector3(0, y, 0), man)
		y += radius * 0.85
	var head := y - 0.32 * 0.85
	var nose := _add(_cylinder(0.0, 0.05, 0.28, 6), _material(Color(1.0, 0.5, 0.12), 0.6), Vector3(0, head, 0.42), man)
	nose.rotation.x = PI / 2
	for side in [-0.11, 0.11]:
		_add(_sphere(0.035), coal, Vector3(side, head + 0.1, 0.28), man)
	for k in 3:
		_add(_sphere(0.04), coal, Vector3(0, 1.0 + k * 0.17, 0.43 - absf(k - 1) * 0.02), man)
	var scarf := TorusMesh.new()
	scarf.inner_radius = 0.24
	scarf.outer_radius = 0.34
	_add(scarf, _material(Color(0.85, 0.15, 0.2), 0.8), Vector3(0, head - 0.3, 0), man)
	var tail := _add(_box(Vector3(0.14, 0.4, 0.04)), _material(Color(0.85, 0.15, 0.2), 0.8), Vector3(0.18, head - 0.5, 0.26), man)
	tail.rotation.z = 0.25
	_add(_cylinder(0.24, 0.24, 0.04, 16), coal, Vector3(0, head + 0.3, 0), man)
	_add(_cylinder(0.16, 0.17, 0.3, 16), coal, Vector3(0, head + 0.45, 0), man)
	var twig := _material(Color(0.32, 0.22, 0.14))
	for side in [-1.0, 1.0]:
		var arm := _add(_cylinder(0.018, 0.03, 0.8, 5), twig, Vector3(side * 0.62, 1.3, 0), man)
		arm.rotation.z = side * 1.0


func _build_falls(spot: Vector3) -> void:
	# A cliff of dark rock at the back, with a waterfall frozen down its
	# face into a frozen pool.
	var back := spot + Vector3(0, 0, -8.0)
	var face := back.z + 2.2
	for i in 7:
		var x := (i - 3) * 3.6 + _rng.randf_range(-0.6, 0.6)
		var size := _rng.randf_range(4.5, 6.0) * (1.25 - absf(i - 3) * 0.1)
		var p := Vector3(back.x + x, _world.height_at(back.x + x, back.z) - size * 0.15, back.z - _rng.randf_range(0.0, 1.5))
		var rock := _rock(600 + i, Vector3(1.0, 1.9, 0.8), p, _rng.randf_range(-0.3, 0.3), size)
		rock.material_override = _cliff_material()
	var ground := _world.height_at(back.x, face)
	var top := Vector3(back.x, ground + 9.5, face)
	var ice := _ice_material()
	for k in 30:
		var x := _rng.randf_range(-3.5, 3.5)
		var length := _rng.randf_range(5.5, 9.5) * (1.0 - absf(x) / 6.0)
		var r := _rng.randf_range(0.35, 0.9)
		var column := _add(_cylinder(r * 1.2, r * 0.5, length, 8), ice, top + Vector3(x, -length * 0.5, _rng.randf_range(-0.3, 0.6)))
		column.rotation.x = _rng.randf_range(-0.1, 0.04)
		column.rotation.z = _rng.randf_range(-0.05, 0.05)
	# Bulges of ice where it piled up at the bottom, long icicles from the
	# top, and the frozen pool.
	for k in 8:
		var bulge := _add(_sphere(_rng.randf_range(0.7, 1.3)), ice, Vector3(back.x + _rng.randf_range(-3.0, 3.0), ground + 0.3, face + _rng.randf_range(0.3, 1.2)))
		bulge.scale = Vector3(1.3, 0.7, 1.0)
	for k in 16:
		var length := _rng.randf_range(0.8, 2.6)
		_add(_cylinder(0.14, 0.0, length, 6), ice, top + Vector3(_rng.randf_range(-5.5, 5.5), 0.6 - length * 0.5, _rng.randf_range(-0.2, 0.5)))
	var pool := _add(_cylinder(5.0, 5.2, 0.1, 32), ice, Vector3(spot.x, _world.height_at(spot.x, spot.z - 2.0) + 0.05, spot.z - 2.0))
	pool.material_override = _ice_material(0.05)
	# The ice glows a little blue.
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.6, 0.8, 1.0)
	glow.light_energy = 0.8
	glow.omni_range = 9.0
	glow.position = top + Vector3(0, -4.0, 3.0)
	add_child(glow)
	_solid(Vector3(20.0, 16.0, 4.0), Vector3(back.x, ground + 8.0, back.z - 0.5))


## Poles with red tops either side of the track, so you can find your way.
func _build_poles() -> void:
	var wood := _material(Color(0.45, 0.32, 0.2))
	var red := _material(Color(0.85, 0.15, 0.12), 0.5)
	var left := 0.0
	var side := 1.0
	for i in World.SNOW_TRACK.size() - 1:
		var a: Vector2 = World.SNOW_TRACK[i]
		var b: Vector2 = World.SNOW_TRACK[i + 1]
		var length := a.distance_to(b)
		while left < length:
			var p := a.lerp(b, left / length) + (b - a).normalized().orthogonal() * 2.6 * side
			var at := _ground(p)
			_add(_cylinder(0.05, 0.06, 1.6, 6), wood, at + Vector3(0, 0.8, 0))
			_add(_cylinder(0.055, 0.055, 0.35, 6), red, at + Vector3(0, 1.45, 0))
			side = -side
			left += POLE_GAP
		left -= length


## A signpost at the foot of the pass.
func _build_pass_sign() -> void:
	var p := Vector2(World.PASS_X + 5.0, -205.0)
	var at := _ground(p)
	var wood := _material(Color(0.45, 0.32, 0.2))
	_add(_cylinder(0.08, 0.09, 2.4, 8), wood, at + Vector3(0, 1.2, 0))
	var board := _add(_box(Vector3(1.9, 0.5, 0.08)), _material(Color(0.62, 0.45, 0.28)), at + Vector3(0, 2.0, 0))
	board.rotation.y = 0.1
	var text := Label3D.new()
	text.text = "Snowy Mountains ↑"
	text.font_size = 40
	text.pixel_size = 0.0045
	text.modulate = Color(0.2, 0.12, 0.06)
	text.outline_size = 0
	text.position = Vector3(0, 0, 0.05)
	board.add_child(text)
	var back_text := text.duplicate() as Label3D
	back_text.rotation.y = PI
	back_text.text = "Meadows ↓"
	back_text.position = Vector3(0, 0, -0.05)
	board.add_child(back_text)
	_add(_box(Vector3(2.0, 0.08, 0.14)), _material(Color(0.95, 0.96, 1.0), 0.6), at + Vector3(0, 2.29, 0)).rotation.y = 0.1


# --- Snowfall and smoke -------------------------------------------------------------

func _snow_particles() -> GPUParticles3D:
	var flakes := GPUParticles3D.new()
	flakes.name = "Snowfall"
	flakes.amount = 500 if OS.has_feature("mobile") else 1400
	flakes.lifetime = 6.0
	flakes.preprocess = 4.0
	flakes.local_coords = false
	flakes.emitting = false
	flakes.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 30, 60))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(22, 3, 22)
	process.direction = Vector3(0.2, -1, 0.1)
	process.spread = 25.0
	process.initial_velocity_min = 1.2
	process.initial_velocity_max = 2.0
	process.gravity = Vector3(0, -0.3, 0)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.6
	process.turbulence_noise_scale = 3.0
	process.scale_min = 0.6
	process.scale_max = 1.3
	flakes.process_material = process
	var flake := QuadMesh.new()
	flake.size = Vector2(0.07, 0.07)
	flake.material = _soft_dot(Color(1, 1, 1, 0.9))
	flakes.draw_pass_1 = flake
	flakes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return flakes


func _smoke_particles() -> GPUParticles3D:
	var smoke := GPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.amount = 24
	smoke.lifetime = 5.0
	smoke.preprocess = 5.0
	smoke.local_coords = false
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.3, 1, 0)
	process.spread = 12.0
	process.initial_velocity_min = 0.6
	process.initial_velocity_max = 0.9
	process.gravity = Vector3(0.15, 0.05, 0)
	process.scale_min = 0.8
	process.scale_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 2.2))
	var grow_texture := CurveTexture.new()
	grow_texture.curve = grow
	process.scale_curve = grow_texture
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.5))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	process.color_ramp = fade_texture
	smoke.process_material = process
	var puff := QuadMesh.new()
	puff.size = Vector2(0.9, 0.9)
	var mat := _soft_dot(Color(0.82, 0.82, 0.85, 0.6))
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	puff.material = mat
	smoke.draw_pass_1 = puff
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return smoke


## A round, soft-edged billboard for flakes and puffs.
func _soft_dot(color: Color) -> StandardMaterial3D:
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 32
	dot.height = 32
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = ramp
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = dot
	mat.albedo_color = color
	return mat


# --- Building blocks ----------------------------------------------------------------

## Dark, damp rock for the cliff, with just a dusting of snow on ledges.
func _cliff_material() -> ShaderMaterial:
	var mat: ShaderMaterial = Rocks.material().duplicate()
	mat.set_shader_parameter("snow_cover", 0.45)
	mat.set_shader_parameter("tint", Color(0.55, 0.55, 0.62))
	return mat


func _ice_material(roughness := 0.12) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.58, 0.78, 0.96, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = roughness
	mat.metallic_specular = 0.8
	mat.rim_enabled = true
	mat.rim = 0.4
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.6, 0.85)
	mat.emission_energy_multiplier = 0.25
	return mat


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
	mesh.rings = 1
	return mesh


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return mesh


func _rock(seed: int, stretch: Vector3, pos: Vector3, yaw: float, size: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Rocks.grow(seed, stretch, 0.22, 3)
	mi.position = pos
	mi.rotation.y = yaw
	mi.scale = Vector3.ONE * size
	add_child(mi)
	return mi


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
