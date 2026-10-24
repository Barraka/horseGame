extends CanvasLayer
## The map: a "Map" button (or Tab) opens a picture of the whole
## countryside seen from above, with the trail, the lake, the beach and the
## trees, the places you've found (and question marks where there are still
## places to find), the people with quests for you, Judge Clara, and an
## arrow for you and your horse. The game waits while the map is open.

@export var world_path: NodePath
@export var horse_path: NodePath
@export var quests_path: NodePath

const PIXELS := 160          ## The ground picture's width (3 m a pixel)
## The part of the world the map shows (x and z, in metres): the countryside,
## and the snowy mountains beyond the pass to the north.
const AREA := Rect2(-236.0, -446.0, 472.0, 682.0)
const ICE := Color(0.72, 0.86, 0.95)
const WATER := Color(0.36, 0.62, 0.85)
const DEEP_WATER := Color(0.24, 0.46, 0.75)
const GOLD := Color(1.0, 0.82, 0.3)
const QUEST := Color(1.0, 0.86, 0.2)
const INK := Color(0.16, 0.1, 0.2)

var _world: Node3D
var _horse: Node3D
var _quests: Node
var _ground: ImageTexture
var _trees := PackedVector2Array()
var _backdrop: Control
var _map: Control
var _button: Button
var _hidden: Array[CanvasLayer] = []
var _font: Font


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_world = get_node(world_path)
	_horse = get_node(horse_path)
	_quests = get_node_or_null(quests_path)
	_font = ThemeDB.fallback_font
	_build_ui()


func is_open() -> bool:
	return _backdrop.visible


func open() -> void:
	if is_open() or not visible:   # Hidden while taking photos
		return
	if not _ground:
		_draw_ground()
	_backdrop.visible = true
	_button.visible = false
	# Everything else on screen hides behind the map.
	_hidden.clear()
	for node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var other := node as CanvasLayer
		if other != self and other.visible:
			other.visible = false
			_hidden.append(other)
	get_tree().paused = true
	_map.queue_redraw()


func close() -> void:
	if not is_open():
		return
	_backdrop.visible = false
	_button.visible = true
	for other in _hidden:
		if is_instance_valid(other):
			other.visible = true
	_hidden.clear()
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_TAB:
		if is_open():
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY_ESCAPE and is_open():
		close()
		get_viewport().set_input_as_handled()


# --- The picture ------------------------------------------------------------------

## Paint the ground from above, once: grass, trail, sand, water, with the
## hills shaded as if lit from the top left. Trees are dotted on top.
func _draw_ground() -> void:
	var tall := roundi(PIXELS * AREA.size.y / AREA.size.x)
	var image := Image.create(PIXELS, tall, false, Image.FORMAT_RGB8)
	var step := AREA.size.x / PIXELS
	var heights := PackedFloat32Array()
	heights.resize((PIXELS + 1) * (tall + 1))
	for j in tall + 1:
		for i in PIXELS + 1:
			heights[j * (PIXELS + 1) + i] = _world.height_at(AREA.position.x + i * step, AREA.position.y + j * step)
	for j in tall:
		for i in PIXELS:
			var x := AREA.position.x + (i + 0.5) * step
			var z := AREA.position.y + (j + 0.5) * step
			var h := heights[j * (PIXELS + 1) + i]
			var color: Color
			if _world.is_on_ice(x, z):
				color = ICE
			elif _world.shore_distance(x, z) < 0.0 and h < _world.SEA_LEVEL:
				color = WATER.lerp(DEEP_WATER, clampf(-_world.shore_distance(x, z) / 30.0, 0.0, 1.0))
			elif _world.is_in_lake(x, z) and h < _world.WATER_LEVEL:
				color = WATER
			else:
				color = _world.ground_color(x, z)
				if _world.is_in_arena(x, z):
					color = Color(0.82, 0.72, 0.55)
				# Hilltops fade to a heathery brown, and light from the top
				# left makes slopes facing it brighter.
				color = color.lerp(Color(0.56, 0.52, 0.36), smoothstep(6.0, 24.0, h) * 0.6 * (1.0 - _world.snow_at(x, z)))
				var dx := heights[j * (PIXELS + 1) + i + 1] - h
				var dz := heights[(j + 1) * (PIXELS + 1) + i] - h
				var light := clampf(1.0 - (dx + dz) * 0.2, 0.65, 1.3)
				color = (color * light).lightened(0.08)
			image.set_pixel(i, j, color)
	_ground = ImageTexture.create_from_image(image)
	# Trees, from the world's planted woods (not bushes or rocks).
	_trees.clear()
	for child in _world.get_children():
		var trees := child as MultiMeshInstance3D
		if not trees or not trees.name.begins_with("Trees_") or "bush" in trees.name or "rock" in trees.name:
			continue
		for k in trees.multimesh.instance_count:
			var at := trees.multimesh.get_instance_transform(k).origin
			_trees.append(Vector2(at.x, at.z))


## Where a spot in the world is on the map (map up is ahead from the start, -Z).
func _to_map(world: Vector2) -> Vector2:
	var box := _map_rect()
	return box.position + (world - AREA.position) / AREA.size * box.size


## The biggest box of the map's shape that fits on screen.
func _map_rect() -> Rect2:
	var fit := minf(_map.size.x / AREA.size.x, _map.size.y / AREA.size.y)
	var size := AREA.size * fit
	return Rect2((_map.size - size) * 0.5, size)


func _draw_map() -> void:
	if not _ground:
		return
	var box := _map_rect()
	var scale_by := box.size.x / AREA.size.x
	_map.draw_texture_rect(_ground, box, false)
	_map.draw_rect(box, Color(0.3, 0.2, 0.12), false, 4.0)
	for tree in _trees:
		_map.draw_circle(_to_map(tree), maxf(2.2 * scale_by, 1.5), Color(0.12, 0.3, 0.1, 0.75))
	_label("Arena", _to_map(Vector2(_world.arena_center.x, _world.arena_center.z)), 14, Color(0.4, 0.28, 0.15), false)
	# Places: found ones by name, the rest a golden question mark.
	var places: Array = _world.PLACES
	var found: Array = Stable.discovered
	for place in places:
		var at := _to_map(place.pos)
		if place.id in found:
			_star(at, 11.0, GOLD)
			_label(place.name, at + Vector2(0, 22), 15, Color.WHITE, true)
		else:
			_map.draw_circle(at, 12.0, Color(1, 0.85, 0.3, 0.35))
			_label("?", at + Vector2(0, 7), 20, Color.WHITE, true)
	# People: a ! for a new quest, a ? when a reward is waiting.
	if _quests:
		for id in _quests.PEOPLE:
			var person: Dictionary = _quests.PEOPLE[id]
			var at := _to_map(person.pos)
			var topic: Dictionary = _quests._topic(id)
			var state := Stable.quest_state(topic.get("id", ""))
			_map.draw_circle(at, 6.0, INK)
			_map.draw_circle(at, 4.5, Color(0.98, 0.6, 0.75))
			if not topic.is_empty() and state != "active":
				_map.draw_circle(at + Vector2(0, -14), 9.0, QUEST)
				_label("?" if state == "ready" else "!", at + Vector2(0, -8), 16, INK, false)
	var judge: Vector2 = preload("res://scripts/competitions.gd").JUDGE.pos
	_map.draw_circle(_to_map(judge), 6.0, Color(0.55, 0.3, 0.85))
	# You, as an arrow pointing the way your horse faces.
	var here := Vector2(_horse.global_position.x, _horse.global_position.z)
	var ahead := -_horse.global_transform.basis.z
	var dir := Vector2(ahead.x, ahead.z).normalized()
	var side := Vector2(-dir.y, dir.x)
	var tip := _to_map(here)
	var arrow := PackedVector2Array([tip + dir * 16.0, tip - dir * 10.0 + side * 10.0, tip - dir * 5.0, tip - dir * 10.0 - side * 10.0])
	_map.draw_colored_polygon(arrow, Color.WHITE)
	_map.draw_polyline(arrow + PackedVector2Array([arrow[0]]), Color(0.85, 0.15, 0.35), 3.0)
	_label("You", tip + Vector2(0, 30), 15, Color.WHITE, true)


func _star(at: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for k in 10:
		var r := radius if k % 2 == 0 else radius * 0.45
		var a := -PI / 2 + k * PI / 5
		points.append(at + Vector2(cos(a), sin(a)) * r)
	_map.draw_colored_polygon(points, color)
	_map.draw_polyline(points + PackedVector2Array([points[0]]), INK, 1.5)


func _label(text: String, at: Vector2, font_size: int, color: Color, outline: bool) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var spot := at - Vector2(width * 0.5, 0)
	if outline:
		_map.draw_string_outline(_font, spot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0, 0, 0, 0.6))
	_map.draw_string(_font, spot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


# --- Buttons and the window ---------------------------------------------------------

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_button = _make_button("Map", open)
	root.add_child(_button)
	_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_button.position += Vector2(-136, 20)   # Left of the Stable button

	_backdrop = ColorRect.new()
	(_backdrop as ColorRect).color = Color(0.05, 0.04, 0.08, 0.7)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.visible = false
	root.add_child(_backdrop)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 20
	column.offset_right = -20
	column.offset_top = 14
	column.offset_bottom = -14
	column.add_theme_constant_override("separation", 8)
	_backdrop.add_child(column)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 24)
	column.add_child(top)
	var title := Label.new()
	title.text = "Map"
	title.add_theme_font_size_override("font_size", 30)
	top.add_child(title)
	var key := Label.new()
	key.text = "★ found   ?  still to find   !  someone needs help   ●  Judge Clara"
	key.add_theme_font_size_override("font_size", 16)
	key.modulate = Color(1, 0.95, 0.85, 0.85)
	top.add_child(key)
	top.add_child(_make_button("Close", close))
	_map = Control.new()
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.draw.connect(_draw_map)
	_map.resized.connect(_map.queue_redraw)
	column.add_child(_map)


func _make_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(120, 48)
	button.add_theme_font_size_override("font_size", 18)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.12, 0.45)
	style.set_corner_radius_all(14)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(action)
	return button
