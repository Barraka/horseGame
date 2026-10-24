extends SceneTree
## Opens the stable and checks the stable building: every horse you own
## stands in a stall with its name on the door, except the one in the
## aisle, and browsing swaps which stall is empty. Run with:
## godot --headless --path . -s tests/stable_test.gd

var scene: Node
var frames := 0
var ok := true
var riderless := false
var first := -1


func _check(what: String, passed: bool) -> void:
	print("%s: %s" % [what, "ok" if passed else "FAILED"])
	ok = ok and passed


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 2:
		riderless = not root.get_node("RiderData").saved
		root.get_node("RiderData").saved = true
		scene = load("res://scenes/stable.tscn").instantiate()
		root.add_child(scene)
	elif frames == 5:
		var stable := root.get_node("Stable")
		var barn: Node3D = scene._barn
		var owned: Array[int] = stable.owned_horses()
		first = scene._index
		_check("Every owned horse has a stall", barn._horses.size() == mini(owned.size(), barn.STALL_Z.size() * 2))
		_check("The horse in the aisle isn't also in its stall", not barn._horses[first].visible)
		var others := owned.filter(func(i): return i != first)
		_check("The others stand in their stalls", others.all(func(i): return barn._horses[i].visible))
		var plate: Label3D = barn.get_node("Plate%d" % owned.find(others[0]))
		_check("Name on the stall door", plate.text == stable.HORSES[others[0]].name)
		scene._browse(1)
	elif frames == 7:
		var barn: Node3D = scene._barn
		_check("After browsing, the first horse is back in its stall", barn._horses[first].visible)
		_check("And the new one's stall is empty", not barn._horses[scene._index].visible)
		scene._browse(-1)   # Leave the same horse picked
		root.get_node("Stable").select(first)
		if riderless:
			root.get_node("RiderData").saved = false
		print("RESULT: ", "PASS" if ok else "FAIL")
		quit(0 if ok else 1)
		return true
	return false
