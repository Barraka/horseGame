@tool
extends Node3D
## Show jumping course: ride through START, jump the fences in order,
## then ride through FINISH. Each knocked rail costs 4 faults.
##
## The gates and fences are child nodes: drag and rotate them in the 3D
## view. Fences are jumped in their scene tree order; duplicate one
## (Ctrl+D) to add a fence, delete one to remove it.

signal status_changed(text: String)
signal announce(text: String)
signal finished(time: float, faults: int)

const Fence := preload("res://scripts/fence.gd")

@export var horse_path: NodePath
@export var clearance := 0.3   ## Hooves tuck up this far below the horse

enum State { READY, RIDING, DONE }

var state := State.READY
var next_fence := 0
var faults := 0
var time := 0.0
var fences: Array[Node3D] = []

var _horse: CharacterBody3D
var _last_pos: Vector3

@onready var start: Node3D = $StartGate
@onready var finish: Node3D = $FinishGate


func _ready() -> void:
	_number_fences()
	if Engine.is_editor_hint():
		child_order_changed.connect(_number_fences)
		return
	_horse = get_node(horse_path)
	_last_pos = _horse.global_position
	_update_status.call_deferred()


func _number_fences() -> void:
	fences.clear()
	for child in get_children():
		if child.get_script() == Fence:
			fences.append(child)
			child.number = fences.size()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var pos := _horse.global_position
	var from := Vector2(_last_pos.x, _last_pos.z)
	var to := Vector2(pos.x, pos.z)
	_last_pos = pos

	if _crossed(start, from, to):
		_reset()
		state = State.RIDING
		announce.emit("Go!")
	if state != State.RIDING:
		return

	time += delta
	if next_fence < fences.size():
		var fence := fences[next_fence]
		if _crossed(fence, from, to):
			var hooves: float = _horse.height_above_ground()
			var knocked := 0
			for rail in fence.rails:
				if hooves < rail.get_meta("height") - clearance:
					_knock_down(rail)
					knocked += 1
			if knocked:
				faults += 4
				announce.emit("Rail down! +4 faults")
			else:
				announce.emit("Clear!")
				var stable := get_node_or_null("/root/Stable")
				if stable:
					stable.train(stable.selected, "jumping", stable.CLEAR_FENCE_POINTS)
			next_fence += 1
	elif _crossed(finish, from, to):
		state = State.DONE
		var stable := get_node_or_null("/root/Stable")
		var prize: int = stable.COURSE_COINS + (stable.CLEAR_ROUND_COINS if faults == 0 else 0) if stable else 0
		if faults == 0:
			announce.emit("Clear round! %.1f s\n+%d coins" % [time, prize])
		else:
			announce.emit("Finished in %.1f s with %d faults\n+%d coins" % [time, faults, prize])
		if stable:
			stable.earn(prize)
			if faults == 0:
				stable.note("clear_round")
		finished.emit(time, faults)
	_update_status()


## Did the horse ride through this fence or gate, in its jumping direction
## (the node's forward, -Z), between two frames?
func _crossed(node: Node3D, from: Vector2, to: Vector2) -> bool:
	var center := Vector2(node.global_position.x, node.global_position.z)
	var forward := -node.global_basis.z
	var dir := Vector2(forward.x, forward.z).normalized()
	var before := (from - center).dot(dir)
	var after := (to - center).dot(dir)
	if not (before < 0.0 and after >= 0.0):
		return false
	var half_width: float = node.width * 0.5 + 0.5
	return absf((to - center).cross(dir)) < half_width


func _reset() -> void:
	next_fence = 0
	faults = 0
	time = 0.0
	for fence in fences:
		fence.reset_rails()


func _knock_down(rail: Node3D) -> void:
	var tween := create_tween()
	tween.tween_property(rail, "position:y", 0.08, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(rail, "rotation:y", 0.3, 0.35)


func _update_status() -> void:
	match state:
		State.READY:
			status_changed.emit("Show jumping\nRide through the green START gate")
		State.RIDING:
			var next := "Fence %d" % (next_fence + 1) if next_fence < fences.size() else "FINISH"
			status_changed.emit("Next: %s\nTime %.1f s   Faults %d" % [next, time, faults])
		State.DONE:
			status_changed.emit("Time %.1f s   Faults %d\nRide through START to go again" % [time, faults])
