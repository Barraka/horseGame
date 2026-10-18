extends SceneTree
## Trains a horse and checks it gets better: speed levels make the canter
## and gallop faster, jumps earn jumping points and make jumps stronger,
## stamina levels let it gallop for longer before it is out of breath, and
## the stable shows the levels. Puts the saved training back afterwards.
## Run with: godot --headless --path . -s tests/training_test.gd

var main: Node
var horse: CharacterBody3D
var frames := 0
var saved := {}
var ok := true
var levels: Array[String] = []
var landed_at := -1
var scene: Node


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(what: String, passed: bool) -> void:
	print("%s: %s" % [what, "ok" if passed else "FAILED"])
	ok = ok and passed


## Gallop (without moving) until out of breath; returns the seconds it took.
func _gallop_until_tired() -> float:
	horse.energy = 1.0
	horse.set_gait(4)
	horse.current_gait = 4
	var seconds := 0.0
	while horse.target_gait == 4 and seconds < 300.0:
		horse._breathe(0.1)
		seconds += 0.1
	return seconds


func _process(_delta: float) -> bool:
	frames += 1
	var stable := root.get_node("Stable")
	var i: int = stable.selected
	if frames == 2:
		horse = main.get_node("Horse")
		saved = stable.training[i].duplicate()
		for skill in stable.SKILLS:
			stable.training[i][skill] = 0.0
		stable.level_up.connect(func(_h, skill, level): levels.append("%s %d" % [skill, level]))
		_check("A new horse starts at level 1", stable.SKILLS.all(func(s): return stable.skill_level(i, s) == 1))
		_check("Level 1 gallop is 11 m/s", is_equal_approx(horse.top_speed(4), 11.0))

		stable.train(i, "speed", 260)
		_check("260 speed points make level 3", stable.skill_level(i, "speed") == 3 and "speed 3" in levels)
		_check("Level 3 gallops faster", horse.top_speed(4) > 11.0 and is_equal_approx(horse.top_speed(1), 1.8))
		_check("Progress to the next level", is_equal_approx(stable.skill_progress(i, "speed"), 10.0 / 200.0))

		var tired: float = _gallop_until_tired()
		_check("Level 1 stamina gallops for %.0f s" % tired, absf(tired - horse.GALLOP_SECONDS) < 0.5)
		_check("Out of breath, the horse canters", horse.target_gait == 3)
		horse.set_gait(4)
		_check("Can't gallop again straight away", horse.target_gait == 3)
		horse.current_gait = 2
		for n in 50:
			horse._breathe(0.1)
		horse.set_gait(4)
		_check("Trotting gets the breath back", horse.target_gait == 4)
		stable.train(i, "stamina", 700)
		var longer: float = _gallop_until_tired()
		_check("Level 5 stamina gallops for %.0f s" % longer, longer > tired + 30.0)

		# Jump from a trot and wait to land.
		horse.energy = 1.0
		horse.set_gait(2)
		horse.speed = 3.6
		horse.current_gait = 2
		return false
	if frames == 30:
		_check("Jumped", horse.jump())
	if frames > 30 and frames < 200 and landed_at < 0 and not horse.jumping:
		landed_at = frames
		_check("A jump earns %d jumping points" % stable.JUMP_POINTS, stable.training[i].jumping == stable.JUMP_POINTS)
		stable.train(i, "jumping", 1000)
		var before: float = horse.GAITS[2].jump
		horse.jump()
		_check("Level 6 jumps higher", horse.velocity.y > before * 1.1)
	if frames == 210:
		# Open the stable screen (skipping rider creation).
		saved.riderless = not root.get_node("RiderData").saved
		root.get_node("RiderData").saved = true
		scene = load("res://scenes/stable.tscn").instantiate()
		root.add_child(scene)
	if frames < 213:
		return false
	scene._care.show_horse(i)
	var shown: Array = Stable.SKILLS.map(func(s): return scene._care._skills[s][0].text)
	_check("Stable shows %s" % ", ".join(shown), shown == ["Lv 3", "Lv 6", "Lv 5"])

	var config := ConfigFile.new()
	config.load(stable.SAVE_PATH)
	_check("Training is saved", config.get_value("training", "speed_%d" % i) == 260.0)

	if saved.riderless:
		root.get_node("RiderData").saved = false
	saved.erase("riderless")
	stable.training[i] = saved
	stable.select(i)   # Save it back
	print("RESULT: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
	return true
