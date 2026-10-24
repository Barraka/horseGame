extends SceneTree
## The grooming salon: buys a face marking, then grooms the ridden horse
## (ribbon braids, a tail bow, a blaze, stockings and rainbow glitter),
## rides it through every gait and checks the coat shows the markings and
## the braids and bow stay on the neck and tail. Run with:
## godot --headless --path . -s tests/salon_test.gd

const GROOMED := {"face": 3, "legs": 4, "mane": 2, "tail": 1, "ribbon": 2, "glitter": 4}

var main: Node
var frames := 0
var saved_tack: Dictionary
var saved_coins: int
var saved_bought: Array
var ok := true
var worst_braid := 0.0
var worst_bow := 0.0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	var stable := root.get_node("Stable")
	var horse: Node3D = main.get_node("Horse")
	var options: Dictionary = preload("res://scripts/tack.gd").OPTIONS
	if frames == 2:
		saved_tack = stable.tack[stable.selected].duplicate()
		saved_coins = stable.coins
		saved_bought = stable.bought_tack.duplicate()
		# Buying: not owned until paid for, then owned.
		stable.coins = 100
		var before: bool = stable.owns_tack("face", 3, options)
		var bought: bool = stable.buy_tack("face", 3, options)
		print("Blaze owned before: %s, bought: %s, coins left: %d" % [before, bought, stable.coins])
		ok = ok and not before and bought and stable.owns_tack("face", 3, options) and stable.coins == 60
		var config: Dictionary = saved_tack.duplicate()
		config.merge(GROOMED, true)
		stable.set_tack(stable.selected, config)
		horse.set_tack(stable.tack[stable.selected])
	if frames < 3:
		return false
	horse.set_gait(mini(frames / 60, 4))
	var tack: Node3D = horse.get_node("Visual/Tack")
	var marks: Dictionary = horse._tack_marks()
	var to_global := func(p: Vector3) -> Vector3: return tack.get_parent().to_global(p)
	for i in tack._braids.size():
		var crest: Vector3 = to_global.call(marks["crest_%d" % i])
		worst_braid = maxf(worst_braid, tack._braids[i].global_position.distance_to(crest))
	worst_bow = maxf(worst_bow, tack._tail_bow.global_position.distance_to(to_global.call(marks.dock)))
	if frames == 330:
		var coat: ShaderMaterial = horse._coat_material
		var shown := [coat.get_shader_parameter("face_marking"), coat.get_shader_parameter("leg_marking"),
			coat.get_shader_parameter("glitter"), coat.get_shader_parameter("glitter_rainbow")]
		print("Coat shows face, legs, glitter, rainbow: ", shown)
		print("Braids: %d with %d bows, tail bow: %s" % [tack._braids.size(), tack._bows.size(), tack._tail_bow != null])
		print("Furthest braid from the crest: %.2f m, bow from the tail: %.2f m" % [worst_braid, worst_bow])
		ok = ok and shown == [3, 4, 1.0, true] and tack._braids.size() == 7 and tack._bows.size() == 7
		ok = ok and worst_braid < 0.1 and worst_bow < 0.1
		print("RESULT: ", "PASS" if ok else "FAIL")
		stable.coins = saved_coins
		stable.bought_tack = saved_bought
		stable.set_tack(stable.selected, saved_tack)   # Saves it all
		quit(0 if ok else 1)
		return true
	return false
