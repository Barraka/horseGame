extends Node3D
## Competitions: Judge Clara by the arena runs a show jumping competition
## and a trail race, each with a Bronze, Silver and Gold cup. Three other
## riders enter every cup, and they get better from one cup to the next.
## Every place wins a rosette and coins; winning a cup wins its trophy and
## opens the next cup. Results are saved with the stable.
##
## Show jumping uses the arena's course: the other riders have already
## jumped, and you have to beat their times (fewest faults first). The race
## follows the trail from the arena towards Flower Valley, through
## checkpoints, against the other riders on their horses.

const Rider := preload("res://scripts/rider.gd")
const Horse := preload("res://scripts/horse.gd")
const Gate := preload("res://scripts/gate.gd")
const Portrait := preload("res://scripts/portrait.gd")
const CHECK_COLOR := Color(0.35, 0.8, 1.0)   ## Race checkpoints are sky blue, unlike the golden places to find
const TALK_DISTANCE := 5.0

const JUDGE := {"name": "Judge Clara", "pos": Vector2(12, 7),
	"look": {"body": 0, "skin": 4, "hair": 1, "hair_color": 2, "outfit": 1, "helmet": 0}}
const EVENTS := {"jumping": "Show jumping", "race": "Trail race"}
const CUPS := ["Bronze cup", "Silver cup", "Gold cup"]
const CUP_COLORS := [Color(0.85, 0.55, 0.3), Color(0.82, 0.85, 0.9), Color(1.0, 0.8, 0.25)]
const PLACES := ["1st", "2nd", "3rd", "4th"]
const ROSETTES := ["gold", "silver", "bronze", "pink"]
const ROSETTE_COLORS := [Color(1.0, 0.78, 0.2), Color(0.8, 0.83, 0.88), Color(0.82, 0.5, 0.25), Color(1.0, 0.55, 0.75)]
const PRIZES := [[50, 30, 20, 10], [80, 45, 25, 10], [120, 60, 30, 10]]   ## Coins by cup and place

## The other riders in each cup: their horse (a coat from stable_data.gd),
## their show jumping round (time, faults) and their race speed in m/s.
## A level 1 horse galloping well averages about 9.5 m/s over the race,
## so the Gold cup needs a trained horse.
const RIVALS := [
	[
		{"name": "Ella", "horse": "Buttercup", "coat": 4, "jump": [27.0, 0], "speed": 7.6,
			"look": {"body": 0, "skin": 1, "hair": 0, "hair_color": 0, "outfit": 1, "helmet": 3}},
		{"name": "Noah", "horse": "Pebble", "coat": 3, "jump": [23.5, 4], "speed": 8.2,
			"look": {"body": 1, "skin": 3, "hair": 2, "hair_color": 2, "outfit": 0, "helmet": 1}},
		{"name": "Zoe", "horse": "Clover", "coat": 1, "jump": [25.0, 0], "speed": 7.9,
			"look": {"body": 0, "skin": 2, "hair": 1, "hair_color": 3, "outfit": 3, "helmet": 4}},
	],
	[
		{"name": "Ruby", "horse": "Starlight", "coat": 7, "jump": [21.0, 0], "speed": 8.9,
			"look": {"body": 0, "skin": 0, "hair": 1, "hair_color": 3, "outfit": 0, "helmet": 5}},
		{"name": "Leo", "horse": "Thunder", "coat": 2, "jump": [19.0, 4], "speed": 9.4,
			"look": {"body": 1, "skin": 1, "hair": 4, "hair_color": 1, "outfit": 2, "helmet": 2}},
		{"name": "Ivy", "horse": "Willow", "coat": 9, "jump": [22.5, 0], "speed": 9.1,
			"look": {"body": 0, "skin": 4, "hair": 3, "hair_color": 5, "outfit": 1, "helmet": 3}},
	],
	[
		{"name": "Grace", "horse": "Majesty", "coat": 8, "jump": [18.0, 0], "speed": 10.2,
			"look": {"body": 0, "skin": 2, "hair": 0, "hair_color": 2, "outfit": 1, "helmet": 1}},
		{"name": "Max", "horse": "Comet", "coat": 0, "jump": [17.2, 0], "speed": 10.8,
			"look": {"body": 1, "skin": 0, "hair": 2, "hair_color": 0, "outfit": 0, "helmet": 2}},
		{"name": "Chloe", "horse": "Aurora", "coat": 11, "jump": [16.0, 4], "speed": 10.5,
			"look": {"body": 0, "skin": 3, "hair": 1, "hair_color": 4, "outfit": 3, "helmet": 4}},
	],
]

const RACE_START := Vector2(4, 16)   ## The race starts on the trail nearest here...
const RACE_METRES := 700             ## ...and runs this far along it
const CHECK_EVERY := 50              ## A checkpoint every this many metres
const CHECK_RADIUS := 10.0           ## How close to ride past a checkpoint
const COUNTDOWN := 3.0
const LANES := [-2.4, 2.4, 4.8]      ## Where the other riders start, beside you

@export var world_path: NodePath
@export var horse_path: NodePath
@export var course_path: NodePath
@export var quests_path: NodePath

var event := ""   ## The competition being ridden now, or ""
var cup := 0

var _world: Node3D
var _horse: CharacterBody3D
var _course: Node3D
var _quests: Node
var _judge: Node3D
var _cup_marker: Node3D
var _talking := false
var _waved_off := false
var _time := 0.0
var _jump_results: Array = []   ## The other riders' rounds: {"name", "time", "faults"}
var _race := {}                 ## The race being ridden (see _start_race)

var _dialog: PanelContainer
var _words: Label
var _buttons: HBoxContainer
var _status: Label
var _status_panel: PanelContainer
var _big: Label
var _results: PanelContainer
var _results_text: Label
var _results_title: Label
var _results_words: Label   ## What Judge Clara says about how it went
var _results_ok: Button


func _ready() -> void:
	_world = get_node(world_path)
	_horse = get_node(horse_path)
	_course = get_node_or_null(course_path)
	_quests = get_node_or_null(quests_path)
	if _course:
		_course.finished.connect(_on_course_finished)
	_build_judge()
	_build_ui()


func _process(delta: float) -> void:
	_time += delta
	_cup_marker.position.y = 2.75 + sin(_time * 3.0) * 0.1
	_cup_marker.rotation.y += delta
	if event == "race":
		_race_step(delta)
	elif event == "jumping":
		_status.text = "%s · %s\n%s" % [EVENTS.jumping, CUPS[cup], _jumping_to_beat()]

	# Talk to the judge when close (and not already competing).
	var at := _horse.global_position
	var d := Vector2(at.x - _judge.position.x, at.z - _judge.position.z).length()
	if d < 14.0:
		var face := atan2(at.x - _judge.position.x, at.z - _judge.position.z)
		_judge.rotation.y = lerp_angle(_judge.rotation.y, face, 1.0 - exp(-4.0 * delta))
	if d > 10.0:
		_waved_off = false
	if d < TALK_DISTANCE and event == "" and not _waved_off and not _results.visible:
		if not _talking:
			_talk()
	elif _talking and d > TALK_DISTANCE + 2.0:
		_close_dialog()


## The cup someone would enter next in an event: the first not yet won,
## or the Gold cup again once they're all won.
func next_cup(which: String) -> int:
	for i in CUPS.size():
		if Stable.best_place(which, i) != 1:
			return i
	return CUPS.size() - 1


func enter(which: String, which_cup: int) -> void:
	_close_dialog()
	_waved_off = true
	event = which
	cup = which_cup
	_status_panel.visible = true
	if _quests:
		_quests.busy = true
	if which == "jumping":
		_jump_results.clear()
		for rival in RIVALS[cup]:
			_jump_results.append({"name": "%s on %s" % [rival.name, rival.horse],
				"time": rival.jump[0] + randf_range(-0.8, 0.8), "faults": rival.jump[1]})
		if _course:
			_course.state = _course.State.READY
		_say("The other riders have jumped.\nRide through START when you're ready!")
	else:
		_start_race()


## Stop the competition without a result (or after one).
func give_up() -> void:
	if event == "race":
		_end_race()
	event = ""
	_status_panel.visible = false
	if _quests:
		_quests.busy = false


func _jumping_to_beat() -> String:
	var best: Dictionary = _jump_results[0]
	for r in _jump_results:
		if r.faults < best.faults or (r.faults == best.faults and r.time < best.time):
			best = r
	var faults: String = "clear" if best.faults == 0 else "%d faults" % best.faults
	return "To beat: %s, %.1f s %s" % [best.name.get_slice(" ", 0), best.time, faults]


func _on_course_finished(time: float, faults: int) -> void:
	if event != "jumping":
		return
	var entries: Array = _jump_results.duplicate()
	entries.append({"name": "You", "time": time, "faults": faults, "you": true})
	entries.sort_custom(func(a, b): return a.faults < b.faults or (a.faults == b.faults and a.time < b.time))
	var lines: Array[String] = []
	var place := 0
	for i in entries.size():
		var e: Dictionary = entries[i]
		if e.has("you"):
			place = i + 1
		var faults_text: String = "clear" if e.faults == 0 else "%d faults" % e.faults
		lines.append("%s   %s   %.1f s, %s" % [PLACES[i], e.name, e.time, faults_text])
	var tip := "Try for a clear round: every pole down costs 4 faults." if faults > 0 \
		else "Ride a little faster between the fences, and jumping training helps too."
	_finish(place, lines, tip)


## Hand out the rosette, coins and maybe a trophy, and show the results
## with a word from Judge Clara. `tip` is advice for next time.
func _finish(place: int, lines: Array[String], tip := "") -> void:
	var which := event
	var which_cup := cup
	give_up()
	var prize: int = PRIZES[which_cup][place - 1]
	var trophy := Stable.record_result(which, which_cup, place)
	Stable.earn(prize)
	var text := "\n".join(lines) + "\n\n"
	text += "You won a %s rosette and %d coins!" % [ROSETTES[place - 1], prize]
	if trophy:
		text += "\nThe %s trophy is yours!" % CUPS[which_cup]
		if which_cup + 1 < CUPS.size():
			text += "\nNow you can enter the %s." % CUPS[which_cup + 1]
	_results_words.text = _feedback(place, which_cup, trophy, tip)
	_results_ok.text = "Hooray!" if place <= 3 else "I'll try again!"
	_results_title.text = "%s · %s" % [EVENTS[which], CUPS[which_cup]]
	_results_title.add_theme_color_override("font_color", ROSETTE_COLORS[place - 1])
	_results_text.text = text
	_results.visible = true


## What Judge Clara says after a competition.
func _feedback(place: int, which_cup: int, trophy: bool, tip: String) -> String:
	var horse: String = Stable.horse_name(Stable.selected)
	match place:
		1:
			if trophy:
				return "Wonderful riding! You and %s were the best today. The %s is yours!" % [horse, CUPS[which_cup]]
			return "Wonderful riding! You and %s were the best today." % horse
		2:
			return "So close! Just a little more and you'll win. " + tip
		3:
			return "Well ridden, and a rosette for you! " + tip
	return "Don't worry, every rider starts somewhere. You'll do better next time! " + tip


# --- The race -----------------------------------------------------------------

func _trail_point(i: float) -> Vector2:
	var points: PackedVector2Array = _world.trail_points
	var a := points[wrapi(floori(i), 0, points.size())]
	var b := points[wrapi(floori(i) + 1, 0, points.size())]
	return a.lerp(b, i - floorf(i))


func _trail_direction(i: float) -> Vector2:
	return (_trail_point(i + 2.0) - _trail_point(i - 2.0)).normalized()


## A point on the ground beside the trail, `along` metres into the race.
func _race_spot(along: float, side: float) -> Vector3:
	var i: float = _race.start + along
	var p := _trail_point(i) + _trail_direction(i).orthogonal() * side
	return Vector3(p.x, _world.height_at(p.x, p.y), p.y)


## The yaw that faces a node (-Z forward) along the trail.
func _trail_yaw(along: float) -> float:
	var dir := _trail_direction(_race.start + along)
	return atan2(-dir.x, -dir.y)


func _start_race() -> void:
	var points: PackedVector2Array = _world.trail_points
	var start := 0
	for i in points.size():
		if points[i].distance_to(RACE_START) < points[start].distance_to(RACE_START):
			start = i
	_race = {"start": start, "time": 0.0, "countdown": COUNTDOWN, "next": 1, "progress": 0.0,
		"rivals": [], "gates": []}
	# Start and finish gates across the trail, and the next checkpoint's beam.
	for g in [[0.0, "START", Color(0.2, 0.7, 0.3)], [float(RACE_METRES), "FINISH", Color(0.85, 0.2, 0.2)]]:
		var gate := Gate.new()
		gate.text = g[1]
		gate.color = g[2]
		gate.width = 9.0
		add_child(gate)
		gate.global_position = _race_spot(g[0], 0.0)
		gate.rotation.y = _trail_yaw(g[0])
		_race.gates.append(gate)
	_race.beam = _make_beam()
	add_child(_race.beam)
	_place_beam()
	# The other riders line up beside you.
	for k in RIVALS[cup].size():
		var info: Dictionary = RIVALS[cup][k]
		var rival := Horse.new()
		rival.rider_look = info.look
		rival.tack = {"pad": k + 1, "trim": k, "saddle": 1, "bridle": 1, "wraps": k + 2}
		add_child(rival)
		rival.set_physics_process(false)   # Moved along the trail below, not ridden
		rival.show_coat(Stable.HORSES[info.coat])
		rival.set_body_shape(Stable.body_shape(info.coat))
		rival.set_tack(rival.tack)
		rival.set_dirt(0.0)
		_race.rivals.append({"horse": rival, "along": 0.0, "speed": 0.0, "lane": LANES[k],
			"pace": info.speed * randf_range(0.97, 1.03), "phase": randf() * TAU, "time": 0.0,
			"name": "%s on %s" % [info.name, info.horse]})
		_move_rival(_race.rivals[k], 0.0)
		rival.stand()
	# And so do you.
	_horse.global_position = _race_spot(1.0, 0.0) + Vector3.UP * 0.1
	_horse.rotation.y = _trail_yaw(1.0)
	_horse.speed = 0.0
	_horse.velocity = Vector3.ZERO
	_horse.energy = 1.0
	_horse.set_gait(0)
	_horse.set_physics_process(false)
	_horse.stand()


func _race_step(delta: float) -> void:
	if _race.countdown > 0.0:
		_race.countdown -= delta
		_big.text = str(ceili(_race.countdown)) if _race.countdown > 0.0 else "Go!"
		_big.modulate.a = 1.0
		if _race.countdown <= 0.0:
			_horse.set_physics_process(true)
			_horse.set_gait(3)
		_status.text = "%s · %s\nGet ready..." % [EVENTS.race, CUPS[cup]]
		return
	_big.modulate.a = maxf(_big.modulate.a - delta, 0.0)
	_race.time += delta

	for rival in _race.rivals:
		var target: float = rival.pace * (1.0 + 0.04 * sin(_race.time * 0.4 + rival.phase))
		if rival.along >= RACE_METRES:
			if rival.time == 0.0:
				rival.time = _race.time
			target = 0.0 if rival.along > RACE_METRES + 20.0 else 3.0   # Slow down after the line
		rival.speed = move_toward(rival.speed, target, 3.5 * delta)
		rival.along += rival.speed * delta
		_move_rival(rival, delta)

	# The checkpoint's rings ripple outwards.
	for k in 2:
		var ring: Node3D = _race.beam.get_node("Ring%d" % k)
		var t := fmod(_race.time * 0.6 + k * 0.5, 1.0)
		ring.scale = Vector3.ONE * (0.6 + 0.5 * t)
		ring.transparency = t

	# How far along the trail you are, and the checkpoints you've passed.
	var at := Vector2(_horse.global_position.x, _horse.global_position.z)
	var best: float = _race.progress
	var best_d := INF
	for k in range(-30, 31):
		var along: float = clampf(_race.progress + k, 0.0, RACE_METRES)
		var d := _trail_point(_race.start + along).distance_to(at)
		if d < best_d:
			best_d = d
			best = along
	if best_d < 25.0:
		_race.progress = best
	var check := mini(_race.next * CHECK_EVERY, RACE_METRES)
	var spot := _race_spot(check, 0.0)
	if Vector2(spot.x, spot.z).distance_to(at) < CHECK_RADIUS:
		if check >= RACE_METRES:
			_finish_race()
			return
		_race.next += 1
		_place_beam()

	var ahead := 0
	for rival in _race.rivals:
		if rival.along > _race.progress:
			ahead += 1
	var checks := ceili(float(RACE_METRES) / CHECK_EVERY)
	_status.text = "%s · %s\nCheckpoint %d of %d   %.1f s   %s place" % [EVENTS.race, CUPS[cup],
		_race.next, checks, _race.time, PLACES[ahead]]


func _move_rival(rival: Dictionary, delta: float) -> void:
	var horse: Horse = rival.horse
	horse.global_position = _race_spot(rival.along, rival.lane)
	horse.rotation.y = _trail_yaw(rival.along)
	horse.speed = rival.speed
	horse.current_gait = 0
	for g in range(Horse.GAITS.size() - 1, 0, -1):
		if rival.speed >= (Horse.GAITS[g - 1].speed + Horse.GAITS[g].speed) * 0.5:
			horse.current_gait = g
			break
	if delta > 0.0:
		horse._animate(delta)


func _finish_race() -> void:
	var entries: Array = [{"name": "You", "time": _race.time, "you": true}]
	for rival in _race.rivals:
		# Riders still racing finish at their own pace.
		var time: float = rival.time if rival.time > 0.0 else _race.time + (RACE_METRES - rival.along) / rival.pace
		entries.append({"name": rival.name, "time": time})
	entries.sort_custom(func(a, b): return a.time < b.time)
	var lines: Array[String] = []
	var place := 0
	for i in entries.size():
		if entries[i].has("you"):
			place = i + 1
		lines.append("%s   %s   %.1f s" % [PLACES[i], entries[i].name, entries[i].time])
	_finish(place, lines, "Galloping trains speed, and long rides train stamina, so your horse can gallop for longer.")


func _end_race() -> void:
	for rival in _race.rivals:
		rival.horse.queue_free()
	for gate in _race.gates:
		gate.queue_free()
	_race.beam.queue_free()
	_race.clear()
	_horse.set_physics_process(true)
	_big.modulate.a = 0.0


func _place_beam() -> void:
	var along := mini(_race.next * CHECK_EVERY, RACE_METRES)
	var checkpoint: Node3D = _race.beam
	checkpoint.global_position = _race_spot(along, 0.0)
	checkpoint.rotation.y = _trail_yaw(along)
	# The last checkpoint is the FINISH gate, so it needs no flags of its own.
	var last := along >= RACE_METRES
	checkpoint.get_node("Arch").visible = not last
	for side in ["Front", "Back"]:
		var label: Label3D = checkpoint.get_node("Arch/" + side)
		label.text = str(_race.next)


## The next checkpoint: a sky blue arch with its number over the trail, a
## pulsing ring to ride through and a blue beam to spot it from afar (the
## places to find, quest things and the judge use gold).
func _make_beam() -> Node3D:
	var node := Node3D.new()
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color(CHECK_COLOR, 0.4)
	var beam := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.15
	tube.bottom_radius = 0.15
	tube.height = 26.0
	tube.radial_segments = 8
	beam.mesh = tube
	beam.material_override = glow
	beam.position.y = 3.8 + 13.0   # Rising from the banner, so the number shows
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(beam)
	for k in 2:
		var ring := MeshInstance3D.new()
		ring.name = "Ring%d" % k
		var torus := TorusMesh.new()
		torus.inner_radius = CHECK_RADIUS * 0.5 - 0.25
		torus.outer_radius = CHECK_RADIUS * 0.5
		torus.rings = 48
		ring.mesh = torus
		ring.material_override = glow
		ring.position.y = 0.2
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(ring)

	# Blue and white poles either side of the trail, and a numbered banner.
	var arch := Node3D.new()
	arch.name = "Arch"
	node.add_child(arch)
	var blue := StandardMaterial3D.new()
	blue.albedo_color = CHECK_COLOR.darkened(0.25)
	blue.emission_enabled = true
	blue.emission = CHECK_COLOR
	blue.emission_energy_multiplier = 0.3
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.95, 0.97, 1.0)
	var half := CHECK_RADIUS * 0.5
	for x in [-half, half]:
		for k in 6:
			var stripe := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.09
			cyl.bottom_radius = 0.09
			cyl.height = 0.5
			stripe.mesh = cyl
			stripe.material_override = blue if k % 2 == 0 else white
			stripe.position = Vector3(x, 0.25 + 0.5 * k, 0)
			arch.add_child(stripe)
	var banner := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(CHECK_RADIUS, 1.0, 0.05)
	banner.mesh = box
	banner.material_override = blue
	banner.position.y = 3.2
	arch.add_child(banner)
	for side in [["Front", 0.04, 0.0], ["Back", -0.04, PI]]:
		var label := Label3D.new()
		label.name = side[0]
		label.font_size = 96
		label.pixel_size = 0.009
		label.outline_size = 16
		label.position = Vector3(0, 3.2, side[1])
		label.rotation.y = side[2]
		arch.add_child(label)
	return node


# --- Judge Clara ----------------------------------------------------------------

func _talk() -> void:
	_talking = true
	for child in _buttons.get_children():
		child.queue_free()
	_words.text = "Welcome to the Meadow Cups! Pick a competition. Win a cup to open the next, harder one."
	for which in EVENTS:
		var next := next_cup(which)
		_add_button("%s\n%s" % [EVENTS[which], CUPS[next]], enter.bind(which, next), true)
	_add_button("Not now", func():
		_waved_off = true
		_close_dialog())
	_dialog.visible = true


func _close_dialog() -> void:
	_talking = false
	_dialog.visible = false


func _build_judge() -> void:
	_judge = Node3D.new()
	_judge.name = "Judge"
	_judge.position = Vector3(JUDGE.pos.x, _world.height_at(JUDGE.pos.x, JUDGE.pos.y), JUDGE.pos.y)
	add_child(_judge)
	var rider := Rider.new()
	_judge.add_child(rider)
	rider.build(JUDGE.look)
	rider.set_pose("stand")
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	body.add_child(shape)
	_judge.add_child(body)
	var name_tag := Label3D.new()
	name_tag.text = JUDGE.name
	name_tag.font_size = 48
	name_tag.pixel_size = 0.006
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.outline_size = 10
	name_tag.position.y = 2.0
	_judge.add_child(name_tag)
	# A little gold cup floating above, so the judge is easy to spot.
	_cup_marker = _make_cup(CUP_COLORS[2])
	_judge.add_child(_cup_marker)
	# A table with the cups on it.
	var table := MeshInstance3D.new()
	var top := BoxMesh.new()
	top.size = Vector3(1.8, 0.08, 0.7)
	table.mesh = top
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.25, 0.35, 0.75)
	table.material_override = cloth
	table.position = _judge.position + Vector3(1.6, 0.8, 0)
	add_child(table)
	var skirt := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.75, 0.78, 0.65)
	skirt.mesh = box
	skirt.material_override = cloth
	skirt.position = _judge.position + Vector3(1.6, 0.39, 0)
	add_child(skirt)
	for i in CUPS.size():
		var trophy := _make_cup(CUP_COLORS[i])
		trophy.scale = Vector3.ONE * (0.8 + 0.15 * i)
		trophy.position = _judge.position + Vector3(1.0 + 0.6 * i, 0.84, 0)
		add_child(trophy)
	var solid := StaticBody3D.new()
	var table_shape := CollisionShape3D.new()
	var table_box := BoxShape3D.new()
	table_box.size = Vector3(1.8, 0.9, 0.7)
	table_shape.shape = table_box
	solid.add_child(table_shape)
	solid.position = _judge.position + Vector3(1.6, 0.45, 0)
	add_child(solid)


## A trophy cup: a bowl on a stem and base, about 40 cm tall.
func _make_cup(color: Color) -> Node3D:
	var node := Node3D.new()
	var metal := StandardMaterial3D.new()
	metal.albedo_color = color
	metal.metallic = 0.9
	metal.roughness = 0.25
	metal.emission_enabled = true
	metal.emission = color
	metal.emission_energy_multiplier = 0.25
	for part in [[0.12, 0.12, 0.04, 0.02], [0.03, 0.03, 0.14, 0.11], [0.16, 0.05, 0.2, 0.28]]:
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = part[0]
		cyl.bottom_radius = part[1]
		cyl.height = part[2]
		mi.mesh = cyl
		mi.material_override = metal
		mi.position.y = part[3]
		node.add_child(mi)
	for side in [-1, 1]:
		var handle := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.045
		torus.outer_radius = 0.07
		handle.mesh = torus
		handle.material_override = metal
		handle.rotation.x = PI / 2
		handle.position = Vector3(0.16 * side, 0.3, 0)
		node.add_child(handle)
	return node


# --- On-screen ------------------------------------------------------------------

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
	var talk_row := HBoxContainer.new()
	talk_row.add_theme_constant_override("separation", 16)
	_dialog.add_child(talk_row)
	var face := Portrait.new()
	face.custom_minimum_size = Vector2(120, 120)
	talk_row.add_child(face)
	face.show_person(JUDGE.look)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	talk_row.add_child(column)
	var who := _label(JUDGE.name, 24)
	who.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	column.add_child(who)
	_words = _label("", 20)
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD
	_words.custom_minimum_size.x = 520
	column.add_child(_words)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 14)
	column.add_child(_buttons)

	# While competing: what's happening, and a way out.
	_status_panel = PanelContainer.new()
	_status_panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.06, 0.12, 0.55)))
	root.add_child(_status_panel)
	_status_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_status_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_status_panel.position.y += 80
	_status_panel.visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_status_panel.add_child(row)
	_status = _label("", 18)
	_status.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	row.add_child(_status)
	var stop := Button.new()
	stop.text = "Give up"
	stop.focus_mode = Control.FOCUS_NONE
	stop.add_theme_font_size_override("font_size", 16)
	var stop_style := _style(Color(1, 1, 1, 0.15))
	for state in ["normal", "hover", "pressed"]:
		stop.add_theme_stylebox_override(state, stop_style)
	stop.pressed.connect(give_up)
	row.add_child(stop)

	_big = _label("", 120)
	_big.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_big.add_theme_constant_override("outline_size", 16)
	root.add_child(_big)
	_big.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_big.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_big.grow_vertical = Control.GROW_DIRECTION_BOTH
	_big.position.y -= 80
	_big.modulate.a = 0.0

	_results = PanelContainer.new()
	_results.add_theme_stylebox_override("panel", _style(Color(0.1, 0.07, 0.14, 0.88)))
	root.add_child(_results)
	_results.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_results.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_results.grow_vertical = Control.GROW_DIRECTION_BOTH
	_results.visible = false
	var results_column := VBoxContainer.new()
	results_column.add_theme_constant_override("separation", 14)
	_results.add_child(results_column)
	# Judge Clara's face and what she says, then the results.
	var judge_row := HBoxContainer.new()
	judge_row.add_theme_constant_override("separation", 16)
	results_column.add_child(judge_row)
	var face_back := PanelContainer.new()
	face_back.add_theme_stylebox_override("panel", _style(Color(1, 0.95, 0.85, 0.15)))
	judge_row.add_child(face_back)
	var judge_face := Portrait.new()
	judge_face.custom_minimum_size = Vector2(140, 140)
	face_back.add_child(judge_face)
	judge_face.show_person(JUDGE.look)
	var speech := VBoxContainer.new()
	speech.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	judge_row.add_child(speech)
	var judge_name := _label(JUDGE.name, 22)
	judge_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	judge_name.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	speech.add_child(judge_name)
	_results_words = _label("", 20)
	_results_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_results_words.autowrap_mode = TextServer.AUTOWRAP_WORD
	_results_words.custom_minimum_size.x = 380
	speech.add_child(_results_words)
	_results_title = _label("", 28)
	results_column.add_child(_results_title)
	_results_text = _label("", 20)
	_results_text.custom_minimum_size.x = 480
	results_column.add_child(_results_text)
	var ok_row := HBoxContainer.new()
	ok_row.alignment = BoxContainer.ALIGNMENT_CENTER
	results_column.add_child(ok_row)
	var ok := Button.new()
	_results_ok = ok
	ok.focus_mode = Control.FOCUS_NONE
	ok.custom_minimum_size = Vector2(180, 56)
	ok.add_theme_font_size_override("font_size", 22)
	var ok_style := _style(Color(1, 0.97, 0.9, 0.95))
	for state in ["normal", "hover", "pressed"]:
		ok.add_theme_stylebox_override(state, ok_style)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		ok.add_theme_color_override(state, Color(0.2, 0.15, 0.25))
	ok.pressed.connect(func(): _results.visible = false)
	ok_row.add_child(ok)


func _say(text: String) -> void:
	if _quests:
		_quests._show_toast(text)


func _add_button(text: String, action: Callable, main := false) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(170, 64)
	button.add_theme_font_size_override("font_size", 18)
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
