extends SceneTree
## Dressage and cross-country: rides the Bronze dressage test neatly (every
## movement in the right gait, straight to the letter) and wins it, then a
## sloppy Silver test in the wrong gaits and comes last. Jumps the Bronze
## cross-country course clear and fast and wins, then rides into a jump
## too low (a refusal) and past one (a run-out) and checks the penalties.
## Checks the jumps make way for the dressage test, and the trophy shelf.
## Puts the saved results and coins back afterwards. Run with:
## godot --headless --path . -s tests/dressage_xc_test.gd

var main: Node
var comps: Node
var horse: CharacterBody3D
var world: Node3D
var frames := 0
var saved := {}
var ok := true
var steps: Array[Callable] = []
var wait := 0
var scene: Node


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(what: String, passed: bool) -> void:
	print("%s: %s" % [what, "ok" if passed else "FAILED"])
	ok = ok and passed


func _process(_delta: float) -> bool:
	frames += 1
	var stable := root.get_node("Stable")
	if frames == 2:
		comps = main.get_node("Competitions")
		horse = main.get_node("Horse")
		world = main.get_node("World")
		comps.set_process(false)   # Stepped by hand below, at 60 steps a second
		horse.set_physics_process(false)
		saved = {"results": stable.results.duplicate(), "coins": stable.coins, "discovered": stable.discovered.duplicate(),
			"training": stable.training[stable.selected].duplicate()}
		stable.results.clear()
		for place in world.PLACES:
			if not place.id in stable.discovered:
				stable.discovered.append(place.id)
		stable.coins = 0
		_plan(stable)
		return false
	if frames < 3:
		return false
	if wait > 0:
		wait -= 1
		return false
	if not steps.is_empty():
		steps.pop_front().call()
		return false
	stable.results = saved.results
	stable.coins = saved.coins
	stable.discovered = saved.discovered
	stable.training[stable.selected] = saved.training
	stable.select(stable.selected)   # Save them back
	print("RESULT: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
	return true


func _plan(stable: Node) -> void:
	var dressage: Node = comps.get_node("Dressage")
	var xc: Node = comps.get_node("CrossCountry")
	steps.append(func():
		_check("Letters round the arena", dressage.has_node("LetterA") and dressage.has_node("LetterE") and dressage.has_node("LetterC"))
		_check("Cross-country jumps out on the trail", xc.has_node("XCJump1") and xc.has_node("XCJump9"))
		_check("The water jump's splash makes hooves splash", world.is_in_pond(xc.pond().x, xc.pond().y))
		comps.enter("dressage", 0)
		_check("Entered the dressage", comps.event == "dressage")
		_check("The show jumps make way", not main.get_node("Course").visible)
		_ride_test(dressage, true))
	steps.append(func():
		print(comps._results_text.text)
		_check("A neat test wins the Bronze dressage cup", stable.best_place("dressage", 0) == 1 and comps._results.visible)
		_check("The show jumps are back", main.get_node("Course").visible)
		_check("Won 50 coins", stable.coins == 50)
		comps._results.visible = false
		comps.enter("dressage", 1)
		_ride_test(dressage, false))
	steps.append(func():
		print(comps._results_text.text)
		_check("Wrong gaits come last in the Silver dressage", stable.best_place("dressage", 1) == 4)
		comps._results.visible = false
		comps.enter("xc", 0)
		_ride_course(xc, 9.0, true))
	steps.append(func():
		print(comps._results_text.text)
		_check("A clear, fast round wins the Bronze cross-country", stable.best_place("xc", 0) == 1)
		_check("Time penalties: 70 s on a 62.7 s course is 8 s over", is_equal_approx(xc.score(0, 70.0, 0), 3.2))
		comps._results.visible = false
		comps.enter("xc", 1)
		# Ride through START, then into the first jump without jumping.
		_go(xc.spot(-3.0), xc.yaw(0.0), 0.1)
		comps._process(1.0 / 60.0)
		_go(xc.spot(1.0), xc.yaw(0.0), 0.1)
		comps._process(1.0 / 60.0)
		_check("Through the START gate", xc.started)
		_go(xc.spot(xc.JUMPS[0][0] - 1.0), xc.yaw(0.0), 0.1)
		comps._process(1.0 / 60.0)
		_go(xc.spot(xc.JUMPS[0][0] + 1.0), xc.yaw(0.0), 0.1)
		comps._process(1.0 / 60.0)
		_check("Too low is a refusal: 20 penalties, and the horse stops", xc.penalties == 20 and xc.next == 0 and horse.speed == 0.0)
		# Now go past beside it.
		_go(xc.spot(xc.JUMPS[0][0] - 1.0, 8.0), xc.yaw(0.0), 0.1)
		comps._process(1.0 / 60.0)
		_go(xc.spot(xc.JUMPS[0][0] + 1.0, 8.0), xc.yaw(0.0), 0.1)
		comps._process(1.0 / 60.0)
		_check("Beside it is a run-out: 20 more", xc.penalties == 40 and xc.next == 0)
		_check("The callout says so", "Run-out" in comps._callout.text)
		comps.give_up()
		_check("Giving up tidies the gates away", comps.event == "" and xc._gates.is_empty())
		root.get_node("RiderData").saved = true
		scene = load("res://scenes/stable.tscn").instantiate()
		root.add_child(scene)
		wait = 3)
	steps.append(func():
		scene._trophies._toggle()
		var cups: Dictionary = scene._trophies._cups
		_check("Shelf shows the dressage Bronze cup won", cups["dressage:0"][1].text == "Won!")
		_check("Shelf shows the cross-country Bronze cup won", cups["xc:0"][1].text == "Won!")
		scene.queue_free())


func _go(at: Vector3, yaw: float, lift: float) -> void:
	horse.global_position = at + Vector3.UP * lift
	horse.rotation.y = yaw


## Ride the dressage test from letter to letter, at 60 steps a second: in
## the right gaits if `neat`, else always at a canter, never halting (and
## at the end, stopping a little short of X).
func _ride_test(dressage: Node, neat: bool) -> void:
	var rides: Array[Callable] = []
	for i in 60 * 200:
		rides.append(func():
			if comps.event != "dressage":
				return
			var movement: Array = dressage._test[dressage._step]
			var gait: int = movement[1] if neat else 3
			var target: Vector2 = dressage.letter_spot(movement[0])
			var at := Vector2(horse.global_position.x, horse.global_position.z)
			var speed: float = horse.GAITS[maxi(gait, 1)].speed
			var to_go := at.distance_to(target)
			if movement[1] == 0 and not neat and to_go < 3.2:
				speed = 0.0   # Pulls up short of X, then finally creeps in
				at = at.move_toward(target, 0.02)
			elif to_go < 0.05:
				speed = 0.0
			else:
				at = at.move_toward(target, speed / 60.0)
			horse.speed = speed if gait != 0 or to_go > 0.5 else 0.0
			horse.current_gait = gait if horse.speed > 0.0 or gait == 0 else 0
			horse.global_position = Vector3(at.x, world.height_at(at.x, at.y) + 0.1, at.y)
			comps._process(1.0 / 60.0))
	steps = rides + steps


## Ride the cross-country course at `speed` m/s, high over every jump.
func _ride_course(xc: Node, speed: float, clear: bool) -> void:
	var rides: Array[Callable] = []
	for i in int((xc.METRES + 10.0) / speed * 60.0) + 100:
		rides.append(func():
			if comps.event != "xc":
				return
			var along: float = -3.0 + (i + 1) * speed / 60.0
			var lift := 0.1
			for jump in xc.JUMPS:
				if absf(along - jump[0]) < 1.5 and clear:
					lift = 1.0
			_go(xc.spot(along), xc.yaw(along), lift)
			horse.speed = speed
			comps._process(1.0 / 60.0))
	steps = rides + steps
