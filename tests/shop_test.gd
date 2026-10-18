extends SceneTree
## Earns coins, buys a horse and a tack colour in the stable's shop, and
## checks they are paid for, saved, and show up in the stable; also that
## the shop refuses when there aren't enough coins. Puts the saved game
## back as it was afterwards. Run with:
## godot --headless --path . -s tests/shop_test.gd

var frames := 0
var scene: Node
var saved := {}
var ok := true


func _check(what: String, passed: bool) -> void:
	print("%s: %s" % [what, "ok" if passed else "FAILED"])
	ok = ok and passed


func _process(_delta: float) -> bool:
	frames += 1
	var stable := root.get_node("Stable")
	if frames == 2:
		saved = {"coins": stable.coins, "bought": stable.bought.duplicate(),
			"tack": stable.bought_tack.duplicate(), "selected": stable.selected,
			"horse_tack": stable.tack.duplicate(true), "riderless": not root.get_node("RiderData").saved}
		root.get_node("RiderData").saved = true
		stable.coins = 0
		stable.bought.clear()
		stable.bought_tack.clear()
		scene = load("res://scenes/stable.tscn").instantiate()
		root.add_child(scene)
	if frames != 4:
		return false

	var storm: int = -1
	for i in stable.HORSES.size():
		if stable.HORSES[i].name == "Storm":
			storm = i
	var shop: Node = scene._shop
	shop._toggle()
	shop._buy_horse(storm)
	_check("Can't buy Storm with no coins", not stable.owns(storm) and stable.coins == 0)

	# Ride 1 km and finish a clear round.
	for i in 40:
		stable.ride(stable.selected, 25.0)
	stable.earn(stable.COURSE_COINS + stable.CLEAR_ROUND_COINS)
	_check("1 km and a clear round earn 60 coins", stable.coins == 60)
	stable.earn(200)
	shop._buy_horse(storm)
	_check("Storm bought for 200 coins", stable.owns(storm) and stable.coins == 60)

	var tack: Script = preload("res://scripts/tack.gd")
	shop._buy_tack("bridle", 4)   # Pink, 50 coins
	_check("Pink bridle bought and worn", stable.owns_tack("bridle", 4, tack.OPTIONS)
		and stable.coins == 10 and stable.tack[scene._index].bridle == 4)
	shop.close()

	# The stable now shows Storm among the horses.
	scene._index = 0
	var seen := []
	for i in stable.owned_horses().size():
		scene._browse(1)
		seen.append(stable.HORSES[scene._index].name)
	_check("Browsing the stable reaches Storm", "Storm" in seen and seen.size() == 7)

	var config := ConfigFile.new()
	config.load(stable.SAVE_PATH)
	_check("Purchases are saved", config.get_value("shop", "coins") == 10
		and "Storm" in config.get_value("shop", "horses") and "bridle:4" in config.get_value("shop", "tack"))

	# Put the saved game back.
	stable.coins = saved.coins
	stable.bought = saved.bought
	stable.bought_tack = saved.tack
	stable.tack.assign(saved.horse_tack)
	stable.select(saved.selected)
	if saved.riderless:
		root.get_node("RiderData").saved = false
	print("RESULT: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
	return true
