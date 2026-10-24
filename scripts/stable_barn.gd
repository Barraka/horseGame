extends Node3D
## The stable building around the stable screen: a wooden barn with a
## cobbled aisle down the middle and stalls on both sides. Each horse you
## own stands in its own stall, looking out over the door, with its name
## on the door. The horse you're looking at stands in the aisle instead,
## so its stall is empty. Lanterns light it; the big doors at the far end
## are open to the meadow.
##
## Built in its own frame: the aisle runs along z, the horse in the aisle
## stands at the origin, and the stable screen turns the whole barn so the
## camera looks down the aisle.

const Horse := preload("res://scripts/horse.gd")
const Trees := preload("res://scripts/trees.gd")

const AISLE := 2.2          ## Half the aisle's width: the stall fronts are this far out
const WALL := 6.6           ## The outside walls, this far out
const STALL := 3.0          ## Stall width along the aisle
const STALL_Z := [-12.5, -9.5, -6.5, -3.5, -0.5, 2.5]   ## Stall centres, on each side
const FAR_END := -14.2      ## The far wall with the big doors
const NEAR_END := 9.5       ## The wall behind the camera
const EAVES := 3.4
const RIDGE := 6.0

var _horses := {}           ## Horse index -> the horse standing in its stall
var _plank: StandardMaterial3D
var _dark: StandardMaterial3D
var _straw: StandardMaterial3D


func _ready() -> void:
	_plank = _wood_material(Color(0.66, 0.47, 0.3))
	_dark = _wood_material(Color(0.4, 0.27, 0.17))
	_straw = _straw_material()
	_build_floor()
	_build_walls()
	_build_roof()
	for side in [-1.0, 1.0]:
		for i in STALL_Z.size():
			_build_stall(side, STALL_Z[i])
	_build_props()
	_build_lights()
	_build_outside()


## Put each owned horse in its stall, except the one shown in the aisle.
func fill_stalls(selected: int) -> void:
	var owned: Array[int] = Stable.owned_horses()
	for index in _horses.keys():
		if not index in owned:
			_horses[index].queue_free()
			_horses.erase(index)
	for slot in owned.size():
		var index := owned[slot]
		if slot >= STALL_Z.size() * 2:
			break
		if not _horses.has(index):
			_horses[index] = _stable_horse(index, slot)
		_horses[index].visible = index != selected
		_horses[index].set_dirt(1.0 - Stable.care[index].clean)
		var plate: Label3D = get_node_or_null("Plate%d" % slot)
		if plate:
			plate.text = Stable.HORSES[index].name


## Where a stall is: side -1 is on the left looking down the aisle.
func stall_spot(slot: int) -> Vector3:
	var side := -1.0 if slot % 2 == 0 else 1.0
	var z: float = STALL_Z[STALL_Z.size() - 1 - slot / 2]   # Nearest stalls first
	return Vector3(side * (AISLE + WALL) * 0.5, 0, z)


func _stable_horse(index: int, slot: int) -> Node3D:
	var horse := Horse.new()
	horse.with_rider = false
	horse.with_tack = false
	var spot := stall_spot(slot)
	horse.position = spot + Vector3(-signf(spot.x) * 0.3, 0, 0)
	horse.rotation.y = PI * 0.5 * signf(spot.x)   # Facing out over the door
	add_child(horse)
	horse.set_physics_process(false)
	horse.show_coat(Stable.HORSES[index])
	horse.stand()
	var plate := Label3D.new()
	plate.name = "Plate%d" % slot
	add_child(plate)
	plate.text = Stable.HORSES[index].name
	plate.font_size = 40
	plate.pixel_size = 0.0028
	plate.modulate = Color(1, 0.95, 0.8)
	plate.outline_size = 10
	plate.outline_modulate = Color(0.25, 0.15, 0.08)
	plate.position = Vector3(signf(spot.x) * (AISLE - 0.09), 0.98, spot.z)
	plate.rotation.y = -PI * 0.5 * signf(spot.x)
	return horse


# --- The building ---------------------------------------------------------------

func _build_floor() -> void:
	# Cobbles down the aisle, straw in the stalls.
	_box(Vector3(AISLE * 2.0, 0.04, NEAR_END - FAR_END), _cobbles_material(), Vector3(0, -0.02, (NEAR_END + FAR_END) * 0.5))
	for side in [-1.0, 1.0]:
		_box(Vector3(WALL - AISLE, 0.06, NEAR_END - FAR_END), _straw,
			Vector3(side * (AISLE + WALL) * 0.5, -0.01, (NEAR_END + FAR_END) * 0.5))
	# A rubber mat where the horse stands to be groomed.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.28, 0.27)
	mat.roughness = 0.9
	_box(Vector3(2.4, 0.02, 3.2), mat, Vector3(0, 0.005, 0))


func _build_walls() -> void:
	var length := NEAR_END - FAR_END
	var mid := (NEAR_END + FAR_END) * 0.5
	for side in [-1.0, 1.0]:
		# Long side walls with a row of small windows.
		_box(Vector3(0.2, EAVES, length), _plank, Vector3(side * WALL, EAVES * 0.5, mid))
		for z in STALL_Z:
			_window(Vector3(side * (WALL - 0.12), 2.3, z), side)
	# The near wall behind the camera.
	_box(Vector3(WALL * 2.0, EAVES, 0.2), _plank, Vector3(0, EAVES * 0.5, NEAR_END))
	# The far wall, with big double doors standing open onto the meadow.
	for side in [-1.0, 1.0]:
		_box(Vector3(WALL - 1.9, EAVES, 0.2), _plank, Vector3(side * (WALL + 1.9) * 0.5, EAVES * 0.5, FAR_END))
		# Each door swings out on its hinge at the edge of the doorway.
		var hinge := Node3D.new()
		hinge.position = Vector3(side * 1.9, 0, FAR_END - 0.1)
		hinge.rotation.y = side * 1.3
		add_child(hinge)
		_box(Vector3(1.9, 3.0, 0.1), _dark, Vector3(-side * 0.95, 1.5, 0)).reparent(hinge, false)
		for y in [0.6, 2.4]:   # Cross boards
			_box(Vector3(1.8, 0.14, 0.04), _plank, Vector3(-side * 0.95, y, 0.07)).reparent(hinge, false)
	_box(Vector3(3.8, 0.3, 0.3), _dark, Vector3(0, 3.15, FAR_END))
	# Gable ends above the walls.
	for z in [NEAR_END, FAR_END]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in [Vector3(-WALL, EAVES, z), Vector3(0, RIDGE, z), Vector3(WALL, EAVES, z)]:
			st.set_uv(Vector2(v.x * 0.3, v.y * 0.3))
			st.add_vertex(v)
		st.generate_normals()
		var gable := MeshInstance3D.new()
		gable.mesh = st.commit()
		gable.material_override = _plank_both_sides()
		add_child(gable)


func _window(pos: Vector3, side: float) -> void:
	_box(Vector3(0.14, 0.9, 1.3), _dark, pos)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.85, 0.93, 1.0)
	glass.emission_enabled = true
	glass.emission = Color(0.75, 0.85, 1.0)
	glass.emission_energy_multiplier = 1.4
	_box(Vector3(0.16, 0.7, 1.1), glass, pos)
	_box(Vector3(0.18, 0.06, 1.1), _dark, pos)   # Glazing bar
	_box(Vector3(0.18, 0.7, 0.06), _dark, pos)


func _build_roof() -> void:
	var length := NEAR_END - FAR_END + 1.0
	var mid := (NEAR_END + FAR_END) * 0.5
	var slope := Vector2(WALL + 0.6, RIDGE - EAVES + 0.3)
	for side in [-1.0, 1.0]:
		var roof := _box(Vector3(slope.length(), 0.15, length), _plank_both_sides(), Vector3(side * slope.x * 0.5, EAVES + slope.y * 0.5 - 0.15, mid))
		roof.rotation.z = -side * atan2(slope.y, slope.x)
	# Beams across, and posts holding them at every stall corner.
	for i in STALL_Z.size() + 1:
		var z: float = STALL_Z[0] - STALL * 0.5 + i * STALL
		_box(Vector3(WALL * 2.0, 0.22, 0.22), _dark, Vector3(0, EAVES - 0.1, z))
		_box(Vector3(0.12, RIDGE - EAVES, 0.12), _dark, Vector3(0, (EAVES + RIDGE) * 0.5 - 0.1, z))
		for side in [-1.0, 1.0]:
			_box(Vector3(0.2, EAVES, 0.2), _dark, Vector3(side * AISLE, EAVES * 0.5, z))
	_box(Vector3(0.2, 0.25, length), _dark, Vector3(0, RIDGE - 0.15, mid))


## A stall front on the aisle: a solid lower half and bars above, with a
## door in the middle. Straw inside, a hay rack and a water bucket.
func _build_stall(side: float, z: float) -> void:
	var x := side * AISLE
	var bars := StandardMaterial3D.new()
	bars.albedo_color = Color(0.15, 0.15, 0.16)
	bars.metallic = 0.6
	bars.roughness = 0.4
	# Panels either side of the door, then the door (lower: horses look over it).
	for end in [-1.0, 1.0]:
		var pz: float = z + end * (STALL * 0.5 - 0.45)
		_box(Vector3(0.1, 1.25, 0.8), _plank, Vector3(x, 0.63, pz))
		_box(Vector3(0.12, 0.08, 0.8), _dark, Vector3(x, 1.27, pz))
		for b in 4:
			_box(Vector3(0.03, 0.95, 0.03), bars, Vector3(x, 1.75, pz - 0.3 + b * 0.2))
		_box(Vector3(0.1, 0.06, 0.8), _dark, Vector3(x, 2.25, pz))
	_box(Vector3(0.1, 1.15, 1.3), _plank, Vector3(x, 0.6, z))
	_box(Vector3(0.12, 0.08, 1.3), _dark, Vector3(x, 1.2, z))
	_box(Vector3(0.13, 1.0, 0.07), _dark, Vector3(x, 0.45, z - 0.15)).rotation.x = 0.85   # The door's brace
	_box(Vector3(0.04, 0.24, 0.8), _dark, Vector3(x - side * 0.06, 0.98, z))   # Name board
	# Wall between this stall and the next.
	for end in [-1.0, 1.0]:
		_box(Vector3(WALL - AISLE, 1.5, 0.1), _plank, Vector3(side * (AISLE + WALL) * 0.5, 0.75, z + end * STALL * 0.5))
	# Hay rack on the back wall and a bucket in the corner.
	var hay := _straw_material(Color(0.82, 0.7, 0.36))
	_box(Vector3(0.5, 0.5, 1.0), _dark, Vector3(side * (WALL - 0.35), 1.5, z + 0.6))
	_box(Vector3(0.45, 0.35, 0.9), hay, Vector3(side * (WALL - 0.35), 1.75, z + 0.6))
	var bucket := CylinderMesh.new()
	bucket.top_radius = 0.2
	bucket.bottom_radius = 0.16
	bucket.height = 0.35
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color(0.25, 0.45, 0.8)
	blue.roughness = 0.5
	_mesh(bucket, blue, Vector3(side * (WALL - 0.4), 0.2, z - 1.05))


func _build_props() -> void:
	var hay := _straw_material(Color(0.86, 0.74, 0.4))
	# Hay bales stacked by the near wall and the far doors.
	for p in [Vector3(-1.3, 0.25, 7.6), Vector3(-0.4, 0.25, 8.4), Vector3(-1.2, 0.75, 8.1), Vector3(1.4, 0.25, -13.0)]:
		var bale := _box(Vector3(1.0, 0.5, 0.6), hay, p)
		bale.rotation.y = p.x * 0.4
		for t in [-0.25, 0.25]:   # Twine
			var twine := StandardMaterial3D.new()
			twine.albedo_color = Color(0.7, 0.25, 0.2)
			_box(Vector3(0.03, 0.52, 0.62), twine, Vector3(t, 0, 0)).reparent(bale, false)
	# A saddle on a stand and bridles on hooks at the near end.
	var stand := Node3D.new()
	stand.position = Vector3(1.6, 0, 7.8)
	add_child(stand)
	_box(Vector3(0.1, 0.9, 0.1), _dark, Vector3(0, 0.45, 0)).reparent(stand, false)
	_box(Vector3(0.6, 0.08, 0.4), _dark, Vector3(0, 0.05, 0)).reparent(stand, false)
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.45, 0.24, 0.12)
	leather.roughness = 0.5
	var seat := SphereMesh.new()
	seat.radius = 0.32
	seat.height = 0.3
	_mesh(seat, leather, Vector3(0, 0.98, 0)).reparent(stand, false)
	# A wheelbarrow of straw and a pitchfork against a post.
	var barrow := Node3D.new()
	barrow.position = Vector3(-1.3, 0, -10.8)
	barrow.rotation.y = 0.4
	add_child(barrow)
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.25, 0.5, 0.35)
	_box(Vector3(0.7, 0.35, 1.0), green, Vector3(0, 0.45, 0)).reparent(barrow, false)
	_box(Vector3(0.6, 0.12, 0.9), _straw, Vector3(0, 0.62, 0)).reparent(barrow, false)
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.2
	wheel.bottom_radius = 0.2
	wheel.height = 0.08
	var turn := _mesh(wheel, _dark, Vector3(0, 0.2, -0.6))
	turn.reparent(barrow, false)
	turn.rotation.z = PI * 0.5
	var fork := _box(Vector3(0.04, 1.6, 0.04), _plank, Vector3(-2.0, 0.8, -8.1))
	fork.rotation.z = 0.12


func _build_lights() -> void:
	# Warm lanterns hanging from the beams down the aisle.
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.85, 0.55)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.75, 0.4)
	glow.emission_energy_multiplier = 3.0
	var lamp := SphereMesh.new()
	lamp.radius = 0.12
	lamp.height = 0.3
	for z in [-11.0, -5.0, 1.0, 6.5]:
		_mesh(lamp, glow, Vector3(0, 2.75, z))
		_box(Vector3(0.02, 0.5, 0.02), _dark, Vector3(0, 3.05, z))
		var light := OmniLight3D.new()
		light.position = Vector3(0, 2.6, z)
		light.light_color = Color(1.0, 0.8, 0.55)
		light.light_energy = 1.3
		light.omni_range = 8.0
		add_child(light)
	# Daylight spilling in through the open doors.
	var door_light := OmniLight3D.new()
	door_light.position = Vector3(0, 2.2, FAR_END + 1.5)
	door_light.light_color = Color(0.9, 0.95, 1.0)
	door_light.light_energy = 1.5
	door_light.omni_range = 9.0
	add_child(door_light)


## Grass, trees and a fence outside the far doors.
func _build_outside() -> void:
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.36, 0.62, 0.22)
	grass.roughness = 0.95
	_box(Vector3(120, 0.02, 80), grass, Vector3(0, -0.05, FAR_END - 40.0))
	for i in 7:
		var tree := MeshInstance3D.new()
		tree.mesh = Trees.grow(["oak", "birch", "poplar", "blossom"][i % 4], 900 + i)
		tree.position = Vector3(-14.0 + i * 4.7, 0, FAR_END - 14.0 - (i % 3) * 5.0)
		tree.scale = Vector3.ONE * 1.2
		add_child(tree)
	for i in 9:
		_box(Vector3(0.12, 1.2, 0.12), _plank, Vector3(-8.0 + i * 2.0, 0.6, FAR_END - 7.0))
	for h in [0.5, 1.0]:
		_box(Vector3(16.2, 0.1, 0.06), _plank, Vector3(0, h, FAR_END - 7.0))


# --- Materials and pieces -----------------------------------------------------

## Planks: vertical boards with dark gaps and a soft grain.
func _wood_material(color: Color) -> StandardMaterial3D:
	var image := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.04
	for y in 128:
		for x in 128:
			var board := x % 32
			var grain := noise.get_noise_2d(x * 3.0 + (x / 32) * 50.0, y * 0.3) * 0.12
			var shade := 0.92 + grain + ((x / 32) % 2) * 0.05
			if board == 0:
				shade = 0.45   # Gap between boards
			image.set_pixel(x, y, Color(shade, shade, shade))
	image.generate_mipmaps()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.albedo_texture = ImageTexture.create_from_image(image)
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.6, 0.6, 0.6)
	mat.roughness = 0.85
	return mat


func _plank_both_sides() -> StandardMaterial3D:
	var mat: StandardMaterial3D = _plank.duplicate()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _straw_material(color := Color(0.85, 0.72, 0.42)) -> StandardMaterial3D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	image.fill(Color(0.75, 0.75, 0.75))
	for i in 220:   # Short strands every which way
		var at := Vector2(rng.randf() * 64, rng.randf() * 64)
		var dir := Vector2.RIGHT.rotated(rng.randf() * TAU)
		var shade := rng.randf_range(0.7, 1.15)
		for t in 8:
			var p := at + dir * t
			image.set_pixel(posmod(int(p.x), 64), posmod(int(p.y), 64), Color(shade, shade, shade))
	image.generate_mipmaps()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.albedo_texture = ImageTexture.create_from_image(image)
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(1.5, 1.5, 1.5)
	mat.roughness = 1.0
	return mat


## Rounded cobbles in rows.
func _cobbles_material() -> StandardMaterial3D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var shades := []
	for i in 64:
		shades.append(rng.randf_range(0.8, 1.05))
	for y in 64:
		for x in 64:
			var row := y / 16
			var cx := (x + (8 if row % 2 else 0)) % 64
			var cell := Vector2(cx % 16 - 7.5, y % 16 - 7.5)
			var d := maxf(absf(cell.x), absf(cell.y)) + cell.length() * 0.3
			var shade: float = shades[(row * 4 + cx / 16) % 64] * (1.0 - smoothstep(6.0, 9.5, d) * 0.55)
			image.set_pixel(x, y, Color(shade, shade, shade))
	image.generate_mipmaps()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.6, 0.56)
	mat.albedo_texture = ImageTexture.create_from_image(image)
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.9, 0.9, 0.9)
	mat.roughness = 0.9
	return mat


func _box(size: Vector3, material: Material, pos: Vector3) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _mesh(box, material, pos)


func _mesh(mesh: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	add_child(mi)
	return mi
