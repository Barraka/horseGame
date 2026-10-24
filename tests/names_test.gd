extends SceneTree
## Naming horses: rename one in the stable, check the new name shows on the
## stable screen and is saved, that an empty name puts back the horse's own,
## and that buying a horse asks for its name. Puts the saved stable back
## afterwards. Run with: godot --headless --path . -s tests/names_test.gd

var ok := true
var frames := 0
var scene: Node
var saved := {}


func _check(what: String, passed: bool) -> void:
	print("%s: %s" % [what, "ok" if passed else "FAILED"])
	ok = ok and passed


func _process(_delta: float) -> bool:
	frames += 1
	var stable := root.get_node("Stable")
	if frames == 2:
		saved = {"names": stable.names.duplicate(), "bought": stable.bought.duplicate(), "coins": stable.coins,
			"growth": stable.growth.duplicate(), "selected": stable.selected, "rider": root.get_node("RiderData").saved}
		stable.names.clear()
		root.get_node("RiderData").saved = true
		scene = load("res://scenes/stable.tscn").instantiate()
		root.add_child(scene)
		return false
	if frames != 4:
		return false
	var index: int = scene._index
	var own: String = stable.HORSES[index].name
	scene.ask_name(index)
	_check("The name box opens", scene._name_dialog.visible)
	scene._name_edit.text = "  Buttercup  "
	scene._keep_name()
	_check("The new name is kept", stable.horse_name(index) == "Buttercup")
	_check("The stable shows it", scene._name_label.text == "Buttercup" and "Buttercup" in scene._ride_button.text)
	var config := ConfigFile.new()
	config.load(stable.SAVE_PATH)
	_check("The name is saved", config.get_value("stable", "names", {}).get(own, "") == "Buttercup")
	stable.rename(index, "")
	_check("An empty name puts back the horse's own", stable.horse_name(index) == own)
	stable.rename(index, "A very very long horse name")
	_check("Names are kept short", stable.horse_name(index).length() == stable.MAX_NAME)

	# Buying a foal asks for its name.
	var daisy := -1
	for i in stable.HORSES.size():
		if stable.HORSES[i].name == "Daisy":
			daisy = i
	stable.bought.erase("Daisy")
	stable.coins = 1000
	scene._shop._toggle()
	scene._shop._buy_horse(daisy)
	_check("Buying a horse asks for a name", scene._name_dialog.visible and "foal" in scene._name_title.text)
	scene._name_edit.text = "Clover"
	scene._keep_name()
	_check("The foal is named", stable.horse_name(daisy) == "Clover")

	stable.names = saved.names
	stable.bought = saved.bought
	stable.coins = saved.coins
	stable.growth = saved.growth
	stable.select(saved.selected)
	root.get_node("RiderData").saved = saved.rider
	print("RESULT: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
	return true
