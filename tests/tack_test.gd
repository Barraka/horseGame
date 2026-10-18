extends SceneTree
## Dresses the ridden horse in chosen tack, rides it through every gait and
## checks the tack is saved for that horse and stays on it: the bridle on
## the head, the wraps on the legs. Run with:
## godot --headless --path . -s tests/tack_test.gd

const CHOICE := {"pad": 2, "trim": 1, "saddle": 3, "bridle": 4, "wraps": 5}

var main: Node
var frames := 0
var saved_tack: Dictionary
var saved_training: Dictionary
var ok := true
var worst := 0.0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	var stable := root.get_node("Stable")
	var horse: Node3D = main.get_node("Horse")
	if frames == 2:
		saved_tack = stable.tack[stable.selected].duplicate()
		saved_training = stable.training[stable.selected].duplicate()
		stable.set_tack(stable.selected, CHOICE)
		horse.set_tack(stable.tack[stable.selected])
	if frames < 3:
		return false
	# A few seconds in each gait.
	horse.set_gait(mini(frames / 60, 4))
	# The bridle and wraps must stay within reach of the points they follow.
	var tack: Node3D = horse.get_node("Visual/Tack")
	var nose: Vector3 = tack.get_parent().to_global(horse._tack_marks().nose)
	var noseband: Vector3 = tack._rings.noseband.global_position
	worst = maxf(worst, noseband.distance_to(nose))
	for leg in tack._wraps:
		ok = ok and leg.global_position.y < horse.global_position.y + 1.0
	if frames == 330:
		var config := ConfigFile.new()
		config.load(stable.SAVE_PATH)
		var stored: Dictionary = config.get_value("tack", str(stable.selected), {})
		print("Saved tack: ", stored)
		print("Built tack: ", tack.config)
		print("Furthest noseband from nose: %.2f m" % worst)
		ok = ok and stored == CHOICE and tack.config == CHOICE and worst < 0.4
		print("RESULT: ", "PASS" if ok else "FAIL")
		stable.training[stable.selected] = saved_training
		stable.set_tack(stable.selected, saved_tack)   # Saves both
		quit(0 if ok else 1)
		return true
	return false
