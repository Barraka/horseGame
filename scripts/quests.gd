extends Node3D
## People around the countryside who ask for help: jump a clear round,
## gather apples, deliver a letter, gallop, pick flowers, find a lost
## horseshoe. Ride up to someone to talk. A gold "!" above their head means
## they have a quest; a "?" means you can collect your reward from them.
## Progress is saved with the stable.

const Rider := preload("res://scripts/rider.gd")
const World := preload("res://scripts/world.gd")
const TALK_DISTANCE := 5.0
const PICK_DISTANCE := 2.6     ## How close to ride to pick something up
const GALLOP_GOAL := 500.0     ## Metres for Ben's quest

## The people: where they stand (x, z) and how they look (rider.gd options).
const PEOPLE := {
	"lily": {"name": "Lily", "pos": Vector2(-8, 8),
		"look": {"body": 0, "skin": 1, "hair": 1, "hair_color": 0, "outfit": 1, "helmet": 3},
		"chat": "Have fun riding! The arena is always open."},
	"tom": {"name": "Farmer Tom", "pos": Vector2(-116, 30),
		"look": {"body": 1, "skin": 2, "hair": 5, "hair_color": 1, "outfit": 2, "helmet": 0},
		"chat": "The windmill grinds our flour. Lovely day for a ride!"},
	"rosa": {"name": "Rosa", "pos": Vector2(60, 64),
		"look": {"body": 0, "skin": 3, "hair": 0, "hair_color": 2, "outfit": 3, "helmet": 0},
		"chat": "I love watching the sparkles on the lake."},
	"ben": {"name": "Ben", "pos": Vector2(116, -108),
		"look": {"body": 1, "skin": 4, "hair": 2, "hair_color": 2, "outfit": 0, "helmet": 0},
		"chat": "The wild horses are friendly if you're gentle."},
	"mia": {"name": "Mia", "pos": Vector2(31, 158),
		"look": {"body": 0, "skin": 0, "hair": 3, "hair_color": 4, "outfit": 3, "helmet": 0},
		"chat": "Every flower in this valley is a different colour!"},
	"sam": {"name": "Old Sam", "pos": Vector2(-60, 140),
		"look": {"body": 1, "skin": 1, "hair": 4, "hair_color": 0, "outfit": 2, "helmet": 0},
		"chat": "These stones have stood here longer than anyone remembers."},
}

## The quests. "giver" offers it, "turn_in" (the giver unless given) hands
## out the reward. "needs" is a quest that must be finished first.
const QUESTS := [
	{"id": "clear_round", "giver": "lily", "reward": 50, "kind": "clear_round",
		"ask": "Hi! I teach jumping here. Can you jump a clear round in the arena, with no poles down?",
		"goal": "Jump a clear round in the arena",
		"thanks": "A clear round! You and your horse make a great team."},
	{"id": "apples", "giver": "tom", "reward": 40, "kind": "collect", "item": "apple", "count": 6,
		"ask": "Oh dear, my cart tipped over and the apples rolled all along the trail! Could you gather 6 of them?",
		"goal": "Gather apples on the trail",
		"thanks": "All my apples! Here, take some coins for your trouble."},
	{"id": "letter", "giver": "rosa", "turn_in": "ben", "reward": 35, "kind": "deliver",
		"ask": "Could you take this letter to Ben at the Wild Horse Meadow, past the hills?",
		"goal": "Take Rosa's letter to Ben at the Wild Horse Meadow",
		"thanks": "A letter from Rosa? Thank you for riding all this way!"},
	{"id": "gallop", "giver": "ben", "needs": "letter", "reward": 40, "kind": "gallop",
		"ask": "Your horse looks fast! Can you gallop 500 metres? Press 4 or E to gallop.",
		"goal": "Gallop 500 m",
		"thanks": "What a gallop! The wild horses were watching you."},
	{"id": "flowers", "giver": "mia", "reward": 45, "kind": "collect", "item": "flower", "count": 8,
		"ask": "I'm making a flower crown. Could you pick 8 flowers around the valley for me?",
		"goal": "Pick flowers in Flower Valley",
		"thanks": "They're beautiful! I'll make a crown for your horse too."},
	{"id": "horseshoe", "giver": "sam", "reward": 60, "kind": "collect", "item": "horseshoe", "count": 1,
		"ask": "Long ago I lost a golden horseshoe up at the Hilltop Lookout. Could you look for it?",
		"goal": "Find the golden horseshoe at the Hilltop Lookout",
		"thanks": "My golden horseshoe! I never thought I'd see it again."},
]

@export var world_path: NodePath
@export var horse_path: NodePath
@export var course_path: NodePath

var _world: World
var _horse: CharacterBody3D
var _people := {}     ## Person id -> {"node", "marker"}
var _items := {}      ## Quest id -> Array of item nodes (null once picked up)
var _talking := ""    ## Who the dialog is open for
var _waved_off := {}  ## People told "Not now", until the rider rides away
var _last_pos: Vector3
var _time := 0.0

var _dialog: PanelContainer
var _who: Label
var _words: Label
var _buttons: HBoxContainer
var _tracker: Label
var _toast: Label
var _toast_tween: Tween


func _ready() -> void:
	_world = get_node(world_path)
	_horse = get_node(horse_path)
	var course := get_node_or_null(course_path)
	if course:
		course.finished.connect(_on_course_finished)
	_last_pos = _horse.global_position
	for id in PEOPLE:
		_build_person(id)
	for quest in QUESTS:
		if quest.kind == "collect":
			_build_items(quest)
	_build_ui()
	_refresh()


func _process(delta: float) -> void:
	_time += delta
	var at := _horse.global_position
	var moved := Vector2(at.x - _last_pos.x, at.z - _last_pos.z).length()
	_last_pos = at

	# Galloping counts towards Ben's quest.
	if Stable.quest_state("gallop") == "active" and _horse.current_gait == 4 and moved < 2.0:
		var done: float = Stable.quests.gallop.progress + moved
		if done >= GALLOP_GOAL:
			_ready_to_hand_in(_quest("gallop"))
		else:
			Stable.quests.gallop.progress = done
			_update_tracker()

	# Things to pick up.
	for id in _items:
		if Stable.quest_state(id) != "active":
			continue
		var items: Array = _items[id]
		for i in items.size():
			var item: Node3D = items[i]
			if item == null:
				continue
			item.rotation.y += 1.5 * delta
			item.position.y = item.get_meta("y") + sin(_time * 2.5 + i) * 0.12
			if Vector2(at.x - item.position.x, at.z - item.position.z).length() < PICK_DISTANCE:
				_pick_up(_quest(id), i)

	# People: bob their markers, turn to the rider, and talk when close.
	var nearest := ""
	var nearest_d := INF
	for id in _people:
		var person: Dictionary = _people[id]
		var node: Node3D = person.node
		var marker: Label3D = person.marker
		marker.position.y = 2.9 + sin(_time * 3.0) * 0.1
		var d := Vector2(at.x - node.position.x, at.z - node.position.z).length()
		if d < 14.0:
			var face := atan2(at.x - node.position.x, at.z - node.position.z)
			node.rotation.y = lerp_angle(node.rotation.y, face, 1.0 - exp(-4.0 * delta))
		if d > 10.0:
			_waved_off.erase(id)
		if d < nearest_d:
			nearest = id
			nearest_d = d
	if nearest_d < TALK_DISTANCE and not _waved_off.has(nearest):
		if _talking != nearest:
			_talk(nearest)
	elif _talking != "" and (nearest != _talking or nearest_d > TALK_DISTANCE + 2.0):
		_close_dialog()


# --- Quest logic ----------------------------------------------------------------

func _quest(id: String) -> Dictionary:
	for quest in QUESTS:
		if quest.id == id:
			return quest
	return {}


func _turn_in(quest: Dictionary) -> String:
	return quest.get("turn_in", quest.giver)


## The quest someone wants to talk about first: a reward to hand out, then
## a quest to offer, then one they're waiting on.
func _topic(person: String) -> Dictionary:
	for quest in QUESTS:
		if _turn_in(quest) == person and Stable.quest_state(quest.id) == "ready":
			return quest
	for quest in QUESTS:
		if quest.giver == person and Stable.quest_state(quest.id) == "" \
				and (not quest.has("needs") or Stable.quest_state(quest.needs) == "done"):
			return quest
	for quest in QUESTS:
		if quest.giver == person and Stable.quest_state(quest.id) == "active":
			return quest
	return {}


func _accept(quest: Dictionary) -> void:
	var progress: Variant = null
	match quest.kind:
		"collect": progress = []
		"gallop": progress = 0.0
	if quest.kind == "deliver":
		Stable.set_quest(quest.id, "ready")
	else:
		Stable.set_quest(quest.id, "active", progress)
	_show_toast("New quest: " + quest.goal)
	_close_dialog()
	_waved_off[quest.giver] = true
	_refresh()


func _ready_to_hand_in(quest: Dictionary) -> void:
	Stable.set_quest(quest.id, "ready", Stable.quests[quest.id].progress)
	_show_toast("Quest done! Go back to %s" % PEOPLE[_turn_in(quest)].name)
	_refresh()


func _hand_in(quest: Dictionary) -> void:
	Stable.set_quest(quest.id, "done")
	Stable.earn(quest.reward)
	_show_toast("+%d coins!" % quest.reward)
	var person := _turn_in(quest)
	_close_dialog()
	_refresh()
	# Straight on to the next thing this person has to say, if anything.
	if not _topic(person).is_empty():
		_talk(person)
	else:
		_waved_off[person] = true


func _pick_up(quest: Dictionary, index: int) -> void:
	var items: Array = _items[quest.id]
	items[index].queue_free()
	items[index] = null
	var taken: Array = Stable.quests[quest.id].progress
	taken.append(index)
	if taken.size() >= quest.count:
		_ready_to_hand_in(quest)
	else:
		Stable.set_quest(quest.id, "active", taken)
		_show_toast("%s: %d of %d" % [quest.item.capitalize() + "s", taken.size(), quest.count])
		_update_tracker()


func _on_course_finished(_time_taken: float, faults: int) -> void:
	if faults == 0 and Stable.quest_state("clear_round") == "active":
		_ready_to_hand_in(_quest("clear_round"))


## Show each person's marker, the items of active quests and the tracker.
func _refresh() -> void:
	for id in _people:
		var marker: Label3D = _people[id].marker
		var topic := _topic(id)
		var state := Stable.quest_state(topic.get("id", ""))
		marker.visible = state == "ready" or state == ""
		marker.text = "?" if state == "ready" else "!"
		if topic.is_empty():
			marker.visible = false
	for id in _items:
		var active := Stable.quest_state(id) == "active"
		var taken: Array = Stable.quests[id].progress if active else []
		var items: Array = _items[id]
		for i in items.size():
			if items[i] != null:
				items[i].visible = active and not i in taken
	_update_tracker()


func _update_tracker() -> void:
	var lines: Array[String] = []
	for quest in QUESTS:
		match Stable.quest_state(quest.id):
			"active":
				var line: String = quest.goal
				if quest.kind == "collect" and quest.count > 1:
					line += " (%d of %d)" % [Stable.quests[quest.id].progress.size(), quest.count]
				elif quest.kind == "gallop":
					line += " (%d m)" % int(Stable.quests[quest.id].progress)
				lines.append(line)
			"ready":
				if quest.kind == "deliver":
					lines.append(quest.goal)
				else:
					lines.append("Go back to %s" % PEOPLE[_turn_in(quest)].name)
	_tracker.text = "Quests\n" + "\n".join(lines) if not lines.is_empty() else ""
	_tracker.get_parent().visible = not lines.is_empty()


# --- Talking --------------------------------------------------------------------

func _talk(person: String) -> void:
	_talking = person
	_who.text = PEOPLE[person].name
	for child in _buttons.get_children():
		child.queue_free()
	var quest := _topic(person)
	var state := Stable.quest_state(quest.get("id", ""))
	if quest.is_empty():
		_words.text = PEOPLE[person].chat
		_add_button("Bye!", _wave_off.bind(person))
	elif state == "ready":
		_words.text = quest.thanks
		_add_button("Collect %d coins" % quest.reward, _hand_in.bind(quest), true)
	elif state == "":
		_words.text = quest.ask
		_add_button("Yes, I'll help!", _accept.bind(quest), true)
		_add_button("Not now", _wave_off.bind(person))
	else:
		_words.text = "How's it going? " + quest.goal + "."
		_add_button("On my way!", _wave_off.bind(person))
	_dialog.visible = true


func _wave_off(person: String) -> void:
	_waved_off[person] = true
	_close_dialog()


func _close_dialog() -> void:
	_talking = ""
	_dialog.visible = false


# --- Building -------------------------------------------------------------------

func _ground(pos: Vector2) -> Vector3:
	return Vector3(pos.x, _world.height_at(pos.x, pos.y), pos.y)


func _build_person(id: String) -> void:
	var info: Dictionary = PEOPLE[id]
	var node := Node3D.new()
	node.name = info.name
	node.position = _ground(info.pos)
	add_child(node)
	var rider := Rider.new()
	node.add_child(rider)
	rider.build(info.look)
	rider.set_pose("stand")
	# Something solid, so horses stop instead of walking through people.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	body.add_child(shape)
	node.add_child(body)
	var marker := Label3D.new()
	marker.font_size = 160
	marker.pixel_size = 0.008
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.modulate = Color(1.0, 0.82, 0.25)
	marker.outline_size = 24
	marker.outline_modulate = Color(0.45, 0.25, 0.05)
	marker.no_depth_test = true
	marker.fixed_size = false
	node.add_child(marker)
	var name_tag := Label3D.new()
	name_tag.text = info.name
	name_tag.font_size = 48
	name_tag.pixel_size = 0.006
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.outline_size = 10
	name_tag.position.y = 2.0
	node.add_child(name_tag)
	_people[id] = {"node": node, "marker": marker}


## Where a quest's things lie: apples along the trail by the windmill,
## flowers around the valley, the horseshoe up at the lookout.
func _item_spots(quest: Dictionary) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	match quest.item:
		"apple":
			# Spread along the trail on both sides of where it passes the windmill.
			var start: Vector2 = PEOPLE.tom.pos
			var nearest := 0
			for i in _world.trail_points.size():
				if _world.trail_points[i].distance_to(start) < _world.trail_points[nearest].distance_to(start):
					nearest = i
			for k in quest.count:
				var i: int = wrapi(nearest + (k - quest.count / 2) * 22 + 6, 0, _world.trail_points.size())
				var p: Vector2 = _world.trail_points[i]
				var next: Vector2 = _world.trail_points[wrapi(i + 1, 0, _world.trail_points.size())]
				var side := (next - p).orthogonal().normalized() * (1.0 if k % 2 == 0 else -1.0)
				spots.append(p + side * 0.8)
		"flower":
			var centre: Vector2 = World.PLACES[1].pos
			for k in quest.count:
				var angle: float = TAU * k / quest.count + 0.3
				spots.append(centre + Vector2(cos(angle), sin(angle)) * (11.0 + 5.0 * (k % 2)))
		"horseshoe":
			spots.append(World.PLACES[4].pos + Vector2(5, -4))
	return spots


func _build_items(quest: Dictionary) -> void:
	var items: Array = []
	for spot in _item_spots(quest):
		var item := _make_item(quest.item)
		var ground := _ground(spot)
		item.position = ground
		item.set_meta("y", ground.y + 0.9)
		add_child(item)
		items.append(item)
	_items[quest.id] = items


func _make_item(kind: String) -> Node3D:
	var item := Node3D.new()
	var glow := func(color: Color, strength: float) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = strength
		m.roughness = 0.4
		return m
	var green: StandardMaterial3D = glow.call(Color(0.3, 0.65, 0.2), 0.2)
	match kind:
		"apple":
			var apple := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.2
			sphere.height = 0.38
			apple.mesh = sphere
			apple.material_override = glow.call(Color(0.85, 0.12, 0.1), 0.35)
			item.add_child(apple)
			var leaf := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.12, 0.02, 0.06)
			leaf.mesh = box
			leaf.material_override = green
			leaf.position = Vector3(0.06, 0.2, 0)
			item.add_child(leaf)
		"flower":
			var stem := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.015
			cyl.bottom_radius = 0.015
			cyl.height = 0.4
			stem.mesh = cyl
			stem.material_override = green
			stem.position.y = -0.2
			item.add_child(stem)
			var colors := [Color(1, 0.45, 0.7), Color(1, 0.85, 0.3), Color(0.7, 0.55, 1), Color(1, 1, 1)]
			var petal_mat: StandardMaterial3D = glow.call(colors[randi() % colors.size()], 0.4)
			for k in 6:
				var petal := MeshInstance3D.new()
				var s := SphereMesh.new()
				s.radius = 0.07
				s.height = 0.05
				petal.mesh = s
				petal.material_override = petal_mat
				var a := TAU * k / 6.0
				petal.position = Vector3(cos(a) * 0.08, 0.0, sin(a) * 0.08)
				item.add_child(petal)
			var middle := MeshInstance3D.new()
			var m := SphereMesh.new()
			m.radius = 0.05
			m.height = 0.06
			middle.mesh = m
			middle.material_override = glow.call(Color(1, 0.8, 0.2), 0.5)
			item.add_child(middle)
		"horseshoe":
			var shoe := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.14
			torus.outer_radius = 0.22
			shoe.mesh = torus
			var gold: StandardMaterial3D = glow.call(Color(1.0, 0.78, 0.25), 0.8)
			gold.metallic = 0.9
			shoe.material_override = gold
			shoe.rotation.x = PI / 2
			shoe.scale = Vector3(1.0, 1.0, 1.25)
			item.add_child(shoe)
	# A thin golden beam and a soft glow, so things can be spotted from a distance.
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.albedo_color = Color(1.0, 0.85, 0.4, 0.3)
	var beam := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.06
	tube.bottom_radius = 0.12
	tube.height = 6.0
	tube.radial_segments = 8
	beam.mesh = tube
	beam.material_override = beam_mat
	beam.position.y = 3.0
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	item.add_child(beam)
	var light := OmniLight3D.new()
	light.light_color = Color(1, 0.9, 0.6)
	light.light_energy = 0.6
	light.omni_range = 2.5
	item.add_child(light)
	return item


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	_dialog = PanelContainer.new()
	_dialog.add_theme_stylebox_override("panel", _style(Color(0.1, 0.07, 0.14, 0.82)))
	root.add_child(_dialog)
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dialog.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dialog.position.y -= 100
	_dialog.visible = false
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_dialog.add_child(column)
	_who = _label("", 24)
	_who.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	column.add_child(_who)
	_words = _label("", 20)
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD
	_words.custom_minimum_size.x = 520
	column.add_child(_words)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 14)
	column.add_child(_buttons)

	var tracker_panel := PanelContainer.new()
	tracker_panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.06, 0.12, 0.45)))
	tracker_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tracker_panel)
	tracker_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tracker_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tracker_panel.position += Vector2(-20, 176)   # Under the keyboard help
	_tracker = _label("", 16)
	_tracker.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tracker_panel.add_child(_tracker)

	_toast = _label("", 30)
	_toast.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_toast.add_theme_constant_override("outline_size", 10)
	root.add_child(_toast)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.position.y -= 40
	_toast.modulate.a = 0.0


func _show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _add_button(text: String, action: Callable, main := false) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(180, 56)
	button.add_theme_font_size_override("font_size", 20)
	var style := _style(Color(1, 0.97, 0.9, 0.95) if main else Color(1, 1, 1, 0.15))
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, style)
	if main:
		for state in ["font_color", "font_hover_color", "font_pressed_color"]:
			button.add_theme_color_override(state, Color(0.2, 0.15, 0.25))
	button.pressed.connect(action)
	_buttons.add_child(button)


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	label.add_theme_constant_override("outline_size", 6)
	return label


func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(16)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style
