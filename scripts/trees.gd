@tool
extends RefCounted
## Trees and bushes made in code. A tree is a trunk that splits into
## branches (tapering tubes of bark), with leaf clusters at the branch
## ends: cards with a leafy cut-out picture, lit as soft balls and swaying
## (see foliage.gdshader). Each kind below grows differently, and a few
## variants of each are grown from different seeds, so no two groves look
## the same. world.gd places them.
##
## Every mesh has two surfaces: bark, then leaves. UV2.x on the leaves is
## how high up the tree they are (0 to 1), for the wind.

const KINDS := {
	# Broad and spreading, the most common tree.
	"oak": {"height": 1.9, "radius": 0.3, "depth": 3, "children": 4, "spread": 0.95, "up": 0.35,
		"shrink": 0.72, "length": 2.4, "cluster": 1.6, "cards": 24, "card": 1.6,
		"leaves": [Color(0.3, 0.52, 0.16), Color(0.36, 0.58, 0.18)], "bark": Color(0.36, 0.27, 0.2)},
	# Slender with a white trunk and small, light leaves.
	"birch": {"height": 4.2, "radius": 0.14, "depth": 3, "children": [4, 3], "spread": 0.6, "up": 0.6,
		"shrink": 0.65, "length": 1.7, "cluster": 1.15, "cards": 16, "card": 1.15,
		"leaves": [Color(0.52, 0.7, 0.24), Color(0.6, 0.74, 0.28)], "bark": Color(0.9, 0.88, 0.84)},
	# Tall and narrow, like a green flame.
	"poplar": {"height": 1.6, "radius": 0.2, "depth": 2, "children": [12, 2], "spread": 0.3, "up": 1.4,
		"shrink": 0.4, "length": 6.5, "cluster": 1.0, "cards": 18, "card": 1.15,
		"leaves": [Color(0.26, 0.48, 0.14), Color(0.32, 0.55, 0.16)], "bark": Color(0.4, 0.34, 0.27)},
	# Like a small oak, covered in pink and white flowers.
	"blossom": {"height": 1.6, "radius": 0.2, "depth": 3, "children": 4, "spread": 1.0, "up": 0.4,
		"shrink": 0.7, "length": 2.0, "cluster": 1.45, "cards": 22, "card": 1.4,
		"leaves": [Color(1.0, 0.72, 0.84), Color(1.0, 0.86, 0.92), Color(0.98, 0.62, 0.78)], "bark": Color(0.3, 0.22, 0.2)},
	# An oak in autumn colours, for a splash of gold and red here and there.
	"autumn": {"height": 1.9, "radius": 0.26, "depth": 3, "children": 4, "spread": 0.9, "up": 0.4,
		"shrink": 0.72, "length": 2.2, "cluster": 1.5, "cards": 24, "card": 1.5,
		"leaves": [Color(0.95, 0.55, 0.12), Color(0.85, 0.3, 0.1), Color(0.95, 0.75, 0.2)], "bark": Color(0.33, 0.25, 0.2)},
	# Hanging curtains of leaves; grows by the lake.
	"willow": {"height": 2.4, "radius": 0.32, "depth": 2, "children": 5, "spread": 0.85, "up": 0.6,
		"shrink": 0.7, "length": 2.2, "cluster": 0.9, "cards": 10, "card": 1.0,
		"leaves": [Color(0.5, 0.66, 0.24), Color(0.56, 0.7, 0.28)], "bark": Color(0.35, 0.3, 0.24)},
	# Pines are grown separately: a straight trunk with rings of drooping branches.
	"pine": {"height": 9.0, "radius": 0.25, "leaves": [Color(0.2, 0.42, 0.25), Color(0.25, 0.48, 0.28)],
		"bark": Color(0.33, 0.24, 0.18)},
	# Palms grow on the beach: a leaning, curving trunk with a crown of long fronds.
	"palm": {"height": 6.5, "radius": 0.2, "leaves": [Color(0.3, 0.55, 0.18), Color(0.38, 0.6, 0.2)],
		"bark": Color(0.55, 0.45, 0.33)},
	# Bushes: a few leaf clusters on the ground, some with flowers.
	"bush": {"leaves": [Color(0.24, 0.46, 0.14), Color(0.3, 0.52, 0.16)]},
	"flower_bush": {"leaves": [Color(0.22, 0.44, 0.14)],
		"flowers": [Color(0.95, 0.45, 0.62), Color(0.98, 0.96, 0.95), Color(0.7, 0.55, 0.95)]},
}

static var _materials := {}   ## Texture name -> foliage ShaderMaterial
static var _bark_material: ShaderMaterial

var _kind: Dictionary
var _name := ""
var _atlas := true             ## Leaf cards use the leaves-and-flowers texture
var _rng := RandomNumberGenerator.new()
var _bark := SurfaceTool.new()
var _leaves := SurfaceTool.new()
var _top := 1.0                ## Roughly how tall the tree grows, for UV2
var _detail := 1.0             ## Fewer leaf cards on tablets


## Grow one variant of a kind of tree (or bush) as a mesh.
static func grow(kind: String, seed: int) -> ArrayMesh:
	var maker := new()
	return maker._grow(kind, seed)


func _grow(kind: String, seed: int) -> ArrayMesh:
	_kind = KINDS[kind]
	_name = kind
	_rng.seed = seed
	_atlas = kind != "willow"
	var tree := Engine.get_main_loop() as SceneTree
	var settings: Node = tree.root.get_node_or_null("Settings") if tree else null
	_detail = settings.tree_detail() if settings else 1.0
	_bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	_leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var texture := "leaves"
	match kind:
		"pine":
			texture = "needles"
			_atlas = false
			_grow_pine()
		"palm":
			texture = "frond"
			_atlas = false
			_grow_palm()
		"bush", "flower_bush":
			_grow_bush(kind == "flower_bush")
		_:
			_top = _kind.height + _kind.length * 1.6
			var lean := Vector3(_rng.randf_range(-0.12, 0.12), 1, _rng.randf_range(-0.12, 0.12)).normalized()
			# The trunk itself, then the crown's branches from its top.
			var top: Vector3 = lean * _kind.height
			_tube(Vector3.ZERO, top, _kind.radius * 1.25, _kind.radius, 8)
			_branch(top, lean, _kind.length, _kind.radius, 1)
	if kind == "willow":
		texture = "strands"   # The curtains; its few leaf clusters share it
		_atlas = false
	var mesh := ArrayMesh.new()
	if not kind.ends_with("bush"):   # Bushes have no bark
		_bark.generate_tangents()
		_bark.commit(mesh)
		mesh.surface_set_material(0, bark_material())
	_leaves.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, foliage_material(texture))
	return mesh


## A branch from `from` heading along `dir`, with a slight bend halfway.
## It splits into smaller branches until the tree's depth, then ends in
## leaves.
func _branch(from: Vector3, dir: Vector3, length: float, radius: float, depth: int) -> void:
	var bend := (dir + _random_unit() * 0.25 + Vector3.UP * 0.1).normalized()
	var mid := from + dir * length * 0.5
	var end := mid + bend * length * 0.5
	var sides := 6 if depth <= 1 else 4
	if radius > 0.03:
		_tube(from, mid, radius, radius * 0.8, sides)
		_tube(mid, end, radius * 0.8, radius * 0.6, sides)
	if depth >= _kind.depth:
		if _name == "willow":
			_strands(end)
		else:
			_cluster(end, _kind.cluster * _rng.randf_range(0.85, 1.15), _kind.cards, _kind.card)
			if length > 1.0:   # Some leaves further down long branches too
				_cluster(from.lerp(end, 0.55), _kind.cluster * 0.75, int(_kind.cards * 0.6), _kind.card * 0.9)
		return
	# How many branches split off: the same at every level, or one number
	# per level.
	var count: int = _kind.children[depth - 1] if _kind.children is Array else _kind.children
	if depth == _kind.depth - 1:   # Leaves on the inner branches too, so crowns are full
		_cluster(end, _kind.cluster * 0.9, int(_kind.cards * 0.7), _kind.card)
	var turn := _rng.randf() * TAU
	for i in count:
		var along := float(i + 1) / count if _name == "poplar" and depth == 1 else _rng.randf_range(0.55, 1.0)
		var start := from.lerp(end, along)
		# Spread round the branch, tilted out by `spread` and lifted by `up`.
		var side := _perpendicular(bend).rotated(bend, turn + i * TAU / count + _rng.randf_range(-0.3, 0.3))
		var child: Vector3 = (bend * cos(_kind.spread) + side * sin(_kind.spread) + Vector3.UP * _kind.up).normalized()
		var child_length: float = length * _kind.shrink * _rng.randf_range(0.8, 1.15)
		if _name == "poplar" and depth == 1:
			child_length = 1.0 + (1.0 - along) * 0.8   # Shorter at the top
			start = from.lerp(end, 0.12 + along * 0.85)
		_branch(start, child, child_length, radius * 0.55, depth + 1)


## A pine: a straight trunk with rings of drooping, needle-covered
## branches, longer at the bottom, and a pointed top.
func _grow_pine() -> void:
	var height: float = _kind.height * _rng.randf_range(0.85, 1.15)
	_top = height
	_tube(Vector3.ZERO, Vector3.UP * height, _kind.radius, 0.04, 7)
	var y := 1.6
	while y < height - 0.3:
		var t := (y - 1.6) / (height - 1.6)
		var reach := lerpf(2.6, 0.35, t) * _rng.randf_range(0.85, 1.1)
		var count := 7 if t < 0.6 else 5
		var turn := _rng.randf() * TAU
		for i in count:
			var a := turn + i * TAU / count + _rng.randf_range(-0.25, 0.25)
			var out := Vector3(cos(a), 0, sin(a))
			var droop := Vector3.DOWN * reach * 0.35
			var tip := Vector3(0, y, 0) + out * reach + droop
			if reach > 1.0:
				_tube(Vector3(0, y, 0), tip, 0.05, 0.015, 3)
			# Needle cards along the branch, facing mostly up.
			var cards := maxi(2, int(reach * 3.0 * _detail))
			for c in cards:
				var along := (c + 0.6) / cards
				var at := Vector3(0, y, 0).lerp(tip, along) + Vector3.UP * 0.12
				var size := lerpf(1.45, 0.95, along) * clampf(reach, 0.6, 1.6)
				var facing := (Vector3.UP * 1.4 + out * 0.4 + _random_unit() * 0.35).normalized()
				var shade := lerpf(0.6, 1.0, along) * lerpf(0.9, 1.08, t)
				_card(at, facing, out, size, _leaf_color() * shade, (at - Vector3(0, y - 0.6, 0)).normalized())
		y += lerpf(0.75, 0.5, t) * _rng.randf_range(0.85, 1.15)
	# The tip.
	var tip := Vector3(0, height, 0)
	for c in 3:
		var a := c * TAU / 3.0
		_card(tip + Vector3(0, -0.3, 0), Vector3(cos(a), 0.6, sin(a)).normalized(), Vector3.UP, 0.9, _leaf_color(), Vector3.UP)


## A palm: a trunk leaning one way and curving back up, in short ringed
## pieces, with a crown of long arching fronds and a few coconuts.
func _grow_palm() -> void:
	var height: float = _kind.height * _rng.randf_range(0.8, 1.2)
	_top = height + 1.0
	var lean := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized() * _rng.randf_range(0.25, 0.5)
	var at := Vector3.ZERO
	var pieces := 9
	for i in pieces:
		var t := (i + 1.0) / pieces
		# Leans out low down, then curves back towards upright.
		var next := Vector3(lean.x * sin(t * PI * 0.8) * height * 0.45, t * height, lean.z * sin(t * PI * 0.8) * height * 0.45)
		_tube(at, next, lerpf(_kind.radius * 1.3, _kind.radius * 0.8, i / float(pieces)), lerpf(_kind.radius * 1.3, _kind.radius * 0.8, t), 7)
		at = next
	var fronds := 11
	for i in fronds:
		var a := i * TAU / fronds + _rng.randf_range(-0.2, 0.2)
		var out := Vector3(cos(a), 0, sin(a))
		var length := _rng.randf_range(2.6, 3.4)
		var rise := _rng.randf_range(0.3, 0.9)
		var across := Vector3(-out.z, 0, out.x)
		var color := _leaf_color()
		var steps := 6
		var prev := at
		for k in steps:
			var t1 := (k + 1.0) / steps
			# An arch: up and out, then drooping down at the tip.
			var p := at + out * length * t1 + Vector3.UP * (rise * sin(t1 * PI * 0.7) - t1 * t1 * 1.4)
			var w0 := 0.62 * sin(maxf(k / float(steps), 0.08) * PI * 0.92 + 0.15)
			var w1 := 0.62 * sin(t1 * PI * 0.92 + 0.15)
			var corners := [prev - across * w0, prev + across * w0, p + across * w1, p - across * w1]
			var uvs := [Vector2(0, k / float(steps)), Vector2(1, k / float(steps)), Vector2(1, t1), Vector2(0, t1)]
			var normal := (Vector3.UP + out * 0.3).normalized()
			for c in [0, 1, 2, 0, 2, 3]:
				_leaves.set_color(color * lerpf(0.8, 1.05, uvs[c].y))
				_leaves.set_normal(normal)
				_leaves.set_uv(uvs[c])
				_leaves.set_uv2(Vector2(clampf(corners[c].y / _top, 0.0, 1.0) * (0.6 + uvs[c].y), 0))
				_leaves.add_vertex(corners[c])
			prev = p
	# Coconuts, as small brown leaf-free balls of bark.
	for i in _rng.randi_range(2, 4):
		var a := _rng.randf() * TAU
		var nut := at + Vector3(cos(a) * 0.22, -0.25, sin(a) * 0.22)
		_tube(nut + Vector3.DOWN * 0.12, nut + Vector3.UP * 0.12, 0.13, 0.11, 6)


## A bush: a few overlapping leaf clusters sitting on the ground, and for
## a flowering bush, flowers dotted over the outside.
func _grow_bush(flowering: bool) -> void:
	_top = 1.6
	var clusters := _rng.randi_range(3, 5)
	for i in clusters:
		var a := i * TAU / clusters + _rng.randf_range(-0.4, 0.4)
		var r := _rng.randf_range(0.55, 0.8)
		var centre := Vector3(cos(a) * 0.45, r * 0.75, sin(a) * 0.45)
		_cluster(centre, r, int(14 * r), 0.8)
	if flowering:
		var flower: Color = _kind.flowers[_rng.randi() % _kind.flowers.size()]
		for i in int(26 * _detail):
			var dir := _random_unit()
			dir.y = absf(dir.y) * 0.8 + 0.2
			dir = dir.normalized()
			var at := Vector3(0, 0.55, 0) + dir * Vector3(1.05, 0.75, 1.05) * _rng.randf_range(0.85, 1.0)
			_card(at, dir, _perpendicular(dir), 0.3, flower * _rng.randf_range(0.9, 1.05), dir, "flower")


## A cluster of leaf cards in a rough ball round `centre`. Cards deep
## inside are darker, as if shaded by the leaves around them.
func _cluster(centre: Vector3, radius: float, cards: int, size: float) -> void:
	for i in maxi(3, int(cards * _detail)):
		var offset := _random_unit() * pow(_rng.randf(), 0.5) * radius
		offset.y *= 0.75
		var at := centre + offset
		var out := offset.normalized() if offset.length() > 0.01 else Vector3.UP
		var facing := (out + _random_unit() * 0.7).normalized()
		var depth := offset.length() / radius
		var shade := lerpf(0.55, 1.05, depth) * lerpf(0.85, 1.05, clampf(offset.y / radius * 0.5 + 0.5, 0.0, 1.0))
		var picture := "flower" if _name == "blossom" and _rng.randf() < 0.5 else ""
		_card(at, facing, _random_unit(), size * _rng.randf_range(0.8, 1.2), _leaf_color() * shade, (out + Vector3.UP * 0.3).normalized(), picture)


## Willow curtains: long strips of leaves hanging from a branch end.
func _strands(end: Vector3) -> void:
	_cluster(end, 0.7, int(_kind.cards), 0.8)
	for i in 11:
		var a := i * TAU / 11.0 + _rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0, sin(a))
		var top := end + out * _rng.randf_range(0.2, 0.8)
		var length := _rng.randf_range(1.8, 3.0)
		var bottom := top + Vector3.DOWN * length + out * 0.35
		var across := Vector3(-out.z, 0, out.x) * 0.35
		var normal := (out + Vector3.UP * 0.2).normalized()
		var color := _leaf_color()
		var corners := [top - across, top + across, bottom + across, bottom - across]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		var shades := [1.0, 1.0, 0.8, 0.8]
		for k in [0, 1, 2, 0, 2, 3]:
			_leaves.set_color(color * shades[k])
			_leaves.set_normal(normal)
			_leaves.set_uv(uvs[k])
			_leaves.set_uv2(Vector2(1.6 - shades[k], 0))   # Ends swing more
			_leaves.add_vertex(corners[k])


## One leaf card: a square at `at` facing `facing`, turned so `toward`
## runs along it. The normal points out of the crown (`normal`), not out of
## the card, so the crown is lit smoothly. `picture` "flower" uses the
## flowers half of the texture instead of the leaves half.
func _card(at: Vector3, facing: Vector3, toward: Vector3, size: float, color: Color, normal: Vector3, picture := "") -> void:
	var u := (toward - facing * toward.dot(facing))
	u = u.normalized() if u.length() > 0.01 else _perpendicular(facing)
	var v := facing.cross(u)
	var h := size * 0.5
	var corners := [at - u * h - v * h, at + u * h - v * h, at + u * h + v * h, at - u * h + v * h]
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for k in [0, 1, 2, 0, 2, 3]:
		_leaves.set_color(color)
		_leaves.set_normal(normal)
		if _atlas:
			_leaves.set_uv(uvs[k] * Vector2(0.5, 1) + (Vector2(0.5, 0) if picture == "flower" else Vector2.ZERO))
		else:
			_leaves.set_uv(uvs[k])
		_leaves.set_uv2(Vector2(clampf(corners[k].y / _top, 0.0, 1.0), 0))
		_leaves.add_vertex(corners[k])


## A tapering tube of bark from `from` to `to`. UV.x goes round, UV.y is
## height in metres so the bark pattern lines up between pieces.
func _tube(from: Vector3, to: Vector3, r0: float, r1: float, sides: int) -> void:
	var axis := (to - from).normalized()
	var a := _perpendicular(axis)
	var b := axis.cross(a)
	var color: Color = _kind.bark
	var ring := func(centre: Vector3, r: float, i: int) -> Array:
		var angle := i * TAU / sides
		var out := a * cos(angle) + b * sin(angle)
		return [centre + out * r, out]
	for i in sides:
		var quad := [ring.call(from, r0, i), ring.call(from, r0, i + 1), ring.call(to, r1, i + 1), ring.call(to, r1, i)]
		var uvs := [Vector2(float(i) / sides, from.y), Vector2(float(i + 1) / sides, from.y),
			Vector2(float(i + 1) / sides, to.y), Vector2(float(i) / sides, to.y)]
		for k in [0, 2, 1, 0, 3, 2]:
			_bark.set_color(color)
			_bark.set_normal(quad[k][1])
			_bark.set_uv(uvs[k])
			_bark.add_vertex(quad[k][0])


func _leaf_color() -> Color:
	var colors: Array = _kind.leaves
	return colors[_rng.randi() % colors.size()] * _rng.randf_range(0.92, 1.06)


func _random_unit() -> Vector3:
	return Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()


static func _perpendicular(axis: Vector3) -> Vector3:
	var other := Vector3.RIGHT if absf(axis.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	return axis.cross(other).normalized()


static func bark_material() -> ShaderMaterial:
	if _bark_material == null:
		_bark_material = ShaderMaterial.new()
		_bark_material.shader = preload("res://shaders/bark.gdshader")
		var noise := FastNoiseLite.new()
		noise.frequency = 0.02
		noise.fractal_octaves = 3
		var texture := NoiseTexture2D.new()
		texture.noise = noise
		texture.seamless = true
		_bark_material.set_shader_parameter("grain", texture)
	return _bark_material


static func foliage_material(picture: String) -> ShaderMaterial:
	if not _materials.has(picture):
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/foliage.gdshader")
		var image: Image
		match picture:
			"needles": image = _needles_image(128)
			"strands": image = _strands_image(64, 256)
			"frond": image = _frond_image(64, 256)
			_: image = _leaves_image(128)
		image.generate_mipmaps()
		mat.set_shader_parameter("leaves", ImageTexture.create_from_image(image))
		_materials[picture] = mat
	return _materials[picture]


## Leaves and flowers side by side, in greys (each tree's colours tint
## them). Left: a spray of leaves pointing out from the middle. Right: a
## bunch of little five-petal flowers, for blossom trees and flowering
## bushes.
static func _leaves_image(size: int) -> Image:
	var image := Image.create(size * 2, size, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var leaves := []
	for i in 40:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 0.36
		leaves.append([Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * d, a + rng.randf_range(-0.6, 0.6), rng.randf_range(0.7, 1.0)])
	var flowers := []
	for i in 18:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 0.36
		flowers.append([Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * d, rng.randf() * TAU, rng.randf_range(0.05, 0.075)])
	for y in size:
		for x in size:
			var p := Vector2((x + 0.5) / size, (y + 0.5) / size)
			var c := Color(0, 0, 0, 0)
			for leaf in leaves:
				var local: Vector2 = (p - leaf[0]).rotated(-leaf[1])
				var e := (local.x / 0.1) ** 2 + (local.y / 0.045) ** 2
				if e < 1.0:
					var vein := 0.82 if absf(local.y) < 0.005 else 1.0
					var g: float = leaf[2] * lerpf(1.0, 0.8, e) * vein
					c = Color(g, g, g, 1.0)
			image.set_pixel(x, y, c)
			c = Color(0, 0, 0, 0)
			for flower in flowers:
				var local: Vector2 = p - flower[0]
				var r: float = flower[2]
				var petals := r * (0.62 + 0.38 * cos(5.0 * (local.angle() + flower[1])))
				if local.length() < petals:
					var g := lerpf(1.0, 0.85, local.length() / r)
					if local.length() < r * 0.22:
						g = 0.55   # The middle
					c = Color(g, g, g, 1.0)
			image.set_pixel(x + size, y, c)
	return image


## A twig with rows of needles either side, for pines.
static func _needles_image(size: int) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var p := Vector2((x + 0.5) / size - 0.5, (y + 0.5) / size - 0.5)
			var c := Color(0, 0, 0, 0)
			var outline := 0.42 - absf(p.y) * 0.5   # A pointed oval of needles
			if absf(p.x) < outline and absf(p.y) < 0.46:
				# Needles slant forward from the middle rib.
				var slant := fmod(absf(p.x) * 1.2 + p.y + 10.0, 0.045)
				if slant < 0.018 or absf(p.x) < 0.012:
					var g := lerpf(1.0, 0.7, absf(p.x) / maxf(outline, 0.01))
					c = Color(g, g, g, 1.0)
			image.set_pixel(x, y, c)
	return image


## A palm frond: a stem down the middle with long thin leaflets slanting
## out to both sides, running from the trunk (top) to the tip (bottom).
static func _frond_image(width: int, height: int) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var p := Vector2((x + 0.5) / width - 0.5, (y + 0.5) / height)
			var c := Color(0, 0, 0, 0)
			var side := absf(p.x)
			if side < 0.02:
				c = Color(0.85, 0.85, 0.7, 1.0)
			elif side < 0.5:
				# Leaflets: thin stripes slanting back towards the tip.
				var stripe := fmod(p.y * 28.0 - side * 3.0 + 10.0, 1.0)
				if stripe < 0.42 and side < 0.48 - stripe * 0.15:
					var g := lerpf(1.0, 0.7, side * 2.0)
					c = Color(g, g, g, 1.0)
			image.set_pixel(x, y, c)
	return image


## A hanging string of small leaves, for willows.
static func _strands_image(width: int, height: int) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var p := Vector2((x + 0.5) / width - 0.5, (y + 0.5) / height)
			var c := Color(0, 0, 0, 0)
			for strand in [-0.25, 0.0, 0.25]:
				var sway: float = strand + sin(p.y * 6.0 + strand * 9.0) * 0.04
				var row := fmod(p.y * 22.0 + strand * 3.0, 1.0)
				var leaf_x := absf(p.x - sway)
				var w := 0.09 * sin(row * PI) * (1.0 - p.y * 0.4)
				if leaf_x < w or leaf_x < 0.012:
					var g := lerpf(1.0, 0.75, leaf_x / 0.1)
					c = Color(g, g, g, 1.0)
			image.set_pixel(x, y, c)
	return image
