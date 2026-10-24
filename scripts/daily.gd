extends Node
## Daily surprises (an autoload, "Daily"): every day brings three small
## tasks, picked from the list below by the date, like feeding carrots,
## riding a kilometre or jumping five times. Each one done earns coins and
## a sticker for the sticker book; doing all three opens a surprise box
## with bonus coins and a rare sticker. A little note pops up whenever a
## task is done, wherever you are. Saved in user://daily.cfg.
##
## The game tells this what's happening through Stable.note() (feeding,
## riding, jumping...), so nothing else needs to know about it.

signal changed

const Stickers := preload("res://scripts/stickers.gd")
const SAVE_PATH := "user://daily.cfg"
const PER_DAY := 3
const BOX_COINS := 50
const SPARE_COINS := 10        ## Instead of a sticker, once you have them all
## The tasks: what to do, which Stable.note() counts for it, how much, and
## the coins. "needs" leaves a task out when it can't be done yet.
const TASKS := [
	{"id": "feed", "text": "Give your horses 3 carrots", "kind": "feed", "goal": 3, "coins": 15},
	{"id": "pet", "text": "Give a horse 5 pats", "kind": "pet", "goal": 5, "coins": 10},
	{"id": "brush", "text": "Brush the mud off a horse", "kind": "brush", "goal": 0.6, "coins": 15},
	{"id": "ride", "text": "Ride 1 km", "kind": "ride", "goal": 1000, "coins": 20},
	{"id": "ride_far", "text": "Ride 2 km", "kind": "ride", "goal": 2000, "coins": 30},
	{"id": "gallop", "text": "Gallop 300 m", "kind": "gallop", "goal": 300, "coins": 20},
	{"id": "jump", "text": "Jump 5 times", "kind": "jump", "goal": 5, "coins": 15},
	{"id": "jump_more", "text": "Jump 12 times", "kind": "jump", "goal": 12, "coins": 25},
	{"id": "clear", "text": "Jump a clear round in the arena", "kind": "clear_round", "goal": 1, "coins": 25},
	{"id": "trick", "text": "Ask your horse for 2 tricks", "kind": "trick", "goal": 2, "coins": 20, "needs": "trick"},
	{"id": "compete", "text": "Ride in one of Judge Clara's competitions", "kind": "compete", "goal": 1, "coins": 25},
	{"id": "podium", "text": "Win a rosette for 1st, 2nd or 3rd", "kind": "podium", "goal": 1, "coins": 30},
	{"id": "quest", "text": "Help someone with a quest", "kind": "quest", "goal": 1, "coins": 25, "needs": "quest"},
	{"id": "discover", "text": "Find a new place", "kind": "discover", "goal": 1, "coins": 25, "needs": "discover"},
]

var enabled := true            ## Off in the automatic tests (see _ready)
var day := ""                  ## The date today's tasks are for
var today: Array = []          ## Today's tasks: {"id", "progress", "done"}
var box_opened := false
var stickers: Array = []       ## Sticker ids you have, in the order you got them
var new_stickers: Array = []   ## Got since the sticker book was last looked at

var _dirty := false
var _save_wait := 0.0
var _toast: PanelContainer
var _toast_text: Label
var _toast_sticker: Control
var _toast_id := ""
var _toast_time := 0.0
var _clock := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The automatic tests run as a script instead of the game; there the
	# daily tasks would add coins and throw their coin counts out.
	enabled = get_tree().get_script() == null
	_load()
	refresh_day()
	var stable := get_node_or_null("/root/Stable")
	if stable:
		stable.did.connect(_on_did)
	_build_toast()


func _process(delta: float) -> void:
	_clock += delta
	if _toast.visible:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time, 0.0, 1.0)
		_toast_sticker.queue_redraw()
		if _toast_time <= 0.0:
			_toast.visible = false
	_save_wait -= delta
	if _dirty and _save_wait <= 0.0:
		_save()
	if fmod(_clock, 10.0) < delta:
		refresh_day()   # Past midnight while playing


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _dirty:
			_save()


static func date_today() -> String:
	return Time.get_date_string_from_system()


## A new day? Then three new tasks.
func refresh_day(date := "") -> void:
	if date == "":
		date = date_today()
	if date == day and not today.is_empty():
		return
	day = date
	box_opened = false
	today.clear()
	var pool: Array = TASKS.filter(_possible)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(day)
	# Not two of the same kind on one day.
	while today.size() < PER_DAY and not pool.is_empty():
		var task: Dictionary = pool.pop_at(rng.randi() % pool.size())
		if today.any(func(t): return task_info(t.id).kind == task.kind):
			continue
		today.append({"id": task.id, "progress": 0.0, "done": false})
	_save()
	changed.emit()


func _possible(task: Dictionary) -> bool:
	var stable := get_node_or_null("/root/Stable")
	if not stable or not task.has("needs"):
		return true
	match task.needs:
		"trick":
			return stable.hearts(stable.selected) >= 1
		"quest":
			return stable.quests.values().filter(func(q): return q.state == "done").size() < preload("res://scripts/quests.gd").QUESTS.size()
		"discover":
			return stable.discovered.size() < preload("res://scripts/world.gd").PLACES.size()
	return true


static func task_info(id: String) -> Dictionary:
	for task in TASKS:
		if task.id == id:
			return task
	return {}


func done_count() -> int:
	return today.filter(func(t): return t.done).size()


func box_ready() -> bool:
	return done_count() == today.size() and not today.is_empty() and not box_opened


## Something happened that a task might count.
func _on_did(kind: String, amount: float) -> void:
	if not enabled:
		return
	for t in today:
		if t.done:
			continue
		var info := task_info(t.id)
		if info.kind != kind:
			continue
		t.progress = minf(t.progress + amount, info.goal)
		_dirty = true
		if t.progress >= info.goal:
			_complete(t, info)
	if _dirty and _save_wait <= 0.0:
		_save_wait = 3.0


func _complete(t: Dictionary, info: Dictionary) -> void:
	t.done = true
	var sticker := _give_sticker(false)
	var stable := get_node_or_null("/root/Stable")
	if stable:
		stable.earn(info.coins + (SPARE_COINS if sticker == "" else 0))
	var text := "Daily task done!\n%s   +%d coins" % [info.text, info.coins]
	if sticker != "":
		text += "\nNew sticker: %s" % Stickers.sticker_name(sticker)
	if box_ready():
		text += "\nAll done today: open your surprise in the stable!"
	_show_toast(text, sticker)
	_save()
	changed.emit()


## Open the surprise box: bonus coins and a rare sticker. Returns the
## sticker (or "" when you have every one).
func open_box() -> String:
	if not box_ready():
		return ""
	box_opened = true
	var sticker := _give_sticker(true)
	var stable := get_node_or_null("/root/Stable")
	if stable:
		stable.earn(BOX_COINS + (SPARE_COINS if sticker == "" else 0))
	_save()
	changed.emit()
	return sticker


## A sticker you don't have yet: a rare one from the box (or a common one
## once you have every rare one).
func _give_sticker(rare: bool) -> String:
	var choices: Array = (Stickers.RARE.keys() if rare else Stickers.COMMON.keys()).filter(func(id): return not id in stickers)
	if choices.is_empty() and rare:
		choices = Stickers.COMMON.keys().filter(func(id): return not id in stickers)
	if choices.is_empty():
		return ""
	var id: String = choices[randi() % choices.size()]
	stickers.append(id)
	new_stickers.append(id)
	return id


# --- Saving ---------------------------------------------------------------------

func _save() -> void:
	_dirty = false
	_save_wait = 3.0
	var config := ConfigFile.new()
	config.set_value("daily", "day", day)
	config.set_value("daily", "today", today)
	config.set_value("daily", "box_opened", box_opened)
	config.set_value("stickers", "have", stickers)
	config.set_value("stickers", "new", new_stickers)
	config.save(SAVE_PATH)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	day = config.get_value("daily", "day", "")
	today = config.get_value("daily", "today", [])
	box_opened = config.get_value("daily", "box_opened", false)
	stickers = config.get_value("stickers", "have", [])
	new_stickers = config.get_value("stickers", "new", [])
	# Forget tasks from an older version of the list.
	today = today.filter(func(t): return not task_info(t.id).is_empty())


# --- The note that pops up ------------------------------------------------------------

func _show_toast(text: String, sticker: String) -> void:
	_toast_text.text = text
	_toast_id = sticker
	_toast_sticker.visible = sticker != ""
	_toast.visible = true
	_toast_time = 5.0
	var sound := get_node_or_null("/root/Sound")
	if sound:
		sound.play("discover", -6.0)


func _build_toast() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_toast = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.18, 0.88)
	style.set_corner_radius_all(18)
	style.content_margin_left = 18
	style.content_margin_right = 22
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.border_color = Color(1.0, 0.8, 0.35)
	style.set_border_width_all(2)
	_toast.add_theme_stylebox_override("panel", style)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	layer.add_child(_toast)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.position.y += 150
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_toast.add_child(row)
	_toast_sticker = Control.new()
	_toast_sticker.custom_minimum_size = Vector2(72, 72)
	_toast_sticker.draw.connect(func():
		if _toast_id != "":
			Stickers.draw(_toast_sticker, _toast_id, _toast_sticker.size * 0.5, 32.0, true, _clock))
	row.add_child(_toast_sticker)
	_toast_text = Label.new()
	_toast_text.add_theme_font_size_override("font_size", 19)
	_toast_text.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	_toast_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_toast_text)
