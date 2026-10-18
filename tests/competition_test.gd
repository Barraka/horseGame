extends SceneTree
## Enters the competitions: talks to Judge Clara, wins the show jumping
## Bronze cup (which opens the Silver cup), comes last in the Silver cup,
## wins the Bronze cup trail race by riding along the trail through every
## checkpoint, and comes last in the Silver cup race by riding slowly. Checks
## the places, coins, trophies, the stable's trophy shelf and the save.
## Puts the saved results and coins back afterwards. Run with:
## godot --headless --path . -s tests/competition_test.gd

var main: Node
var comps: Node
var horse: CharacterBody3D
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
		comps.set_process(false)   # Stepped by hand below, at 60 steps a second
		saved = {"results": stable.results.duplicate(), "coins": stable.coins,
			"riderless": not root.get_node("RiderData").saved, "discovered": stable.discovered.duplicate()}
		stable.results.clear()
		# Count only competition prizes, not coins for finding places on the way.
		for place in main.get_node("World").PLACES:
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
	stable.select(stable.selected)   # Save them back
	if saved.riderless:
		root.get_node("RiderData").saved = false
	print("RESULT: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
	return true


func _step(frames_to_run: int) -> void:
	for i in frames_to_run:
		comps._process(1.0 / 60.0)


func _plan(stable: Node) -> void:
	# Talk to the judge.
	steps.append(func():
		horse.set_physics_process(false)
		var p: Vector2 = comps.JUDGE.pos + Vector2(0, 3)
		horse.global_position = Vector3(p.x, main.get_node("World").height_at(p.x, p.y) + 0.1, p.y)
		_step(2)
		_check("Judge Clara talks", comps._dialog.visible)
		var first: Button = comps._buttons.get_child(0)
		_check("Offers the show jumping Bronze cup", "Bronze" in first.text and "jumping" in first.text)
		first.pressed.emit())
	steps.append(func():
		_check("Entered the show jumping", comps.event == "jumping" and comps.cup == 0)
		main.get_node("Course").finished.emit(20.0, 0))
	steps.append(func():
		_check("A 20 s clear round wins the Bronze cup", stable.best_place("jumping", 0) == 1 and comps._results.visible)
		_check("Won 50 coins", stable.coins == 50)
		_check("Silver cup open", stable.cup_open("jumping", 1) and comps.next_cup("jumping") == 1)
		comps._results.visible = false
		comps.enter("jumping", 1)
		main.get_node("Course").finished.emit(30.0, 8))
	steps.append(func():
		_check("Slow with 8 faults comes 4th", stable.best_place("jumping", 1) == 4 and stable.coins == 60)
		_check("Gold cup still locked", not stable.cup_open("jumping", 2))
		comps._results.visible = false
		comps.enter("race", 0))
	# The race: line up, count down, then ride the trail.
	steps.append(func():
		_check("Three riders line up", comps._race.rivals.size() == 3)
		_step(int(comps.COUNTDOWN * 60) + 2)
		_check("Countdown over", comps._race.countdown <= 0.0)
		horse.set_physics_process(false)
		_ride(12.0))
	steps.append(func():
		_check("Won the Bronze cup race", stable.best_place("race", 0) == 1 and comps.event == "")
		_check("Race things tidied away", comps._race.is_empty())
		print(comps._results_text.text)
		comps._results.visible = false
		comps.enter("race", 1)
		_step(int(comps.COUNTDOWN * 60) + 2)
		horse.set_physics_process(false)
		_ride(5.0))
	steps.append(func():
		_check("A slow ride comes 4th in the Silver cup race", stable.best_place("race", 1) == 4)
		_check("Coins add up (50 + 10 + 50 + 10)", stable.coins == 120)
		var config := ConfigFile.new()
		config.load(stable.SAVE_PATH)
		_check("Results are saved", config.get_value("competitions", "results", {}).get("race:0") == 1)
		root.get_node("RiderData").saved = true
		scene = load("res://scenes/stable.tscn").instantiate()
		root.add_child(scene)
		wait = 3)
	steps.append(func():
		scene._trophies._toggle()
		var cups: Dictionary = scene._trophies._cups
		_check("Shelf shows the jumping Bronze cup won", cups["jumping:0"][1].text == "Won!")
		_check("Shelf shows 4th in the Silver race", cups["race:1"][1].text == "Best: 4th")
		_check("Shelf shows the Gold race locked", cups["race:2"][1].text == "Locked")
		_check("Two gold rosettes", scene._trophies._rosettes[0].text == "× 2")
		scene.queue_free())


## Ride along the trail at `speed` m/s until the race ends (as extra steps).
func _ride(speed: float) -> void:
	var rides: Array[Callable] = []
	var world: Node3D = main.get_node("World")
	for i in int(comps.RACE_METRES / speed * 60.0) + 400:
		rides.append(func():
			if comps.event != "race":
				return
			var along: float = minf((i + 1) * speed / 60.0, comps.RACE_METRES + 2.0)
			var p: Vector3 = comps._race_spot(along, 0.0)
			horse.global_position = p + Vector3.UP * 0.1
			comps._process(1.0 / 60.0))
	steps = rides + steps
