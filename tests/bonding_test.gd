extends SceneTree
## Bonding: care and rides grow hearts, tricks unlock with hearts and are
## refused by an unhappy horse, the horse bows, spins and rears at a halt,
## you can get off and walk, a whistle brings the horse trotting over, and
## it walks beside you when you lead it by the head collar.
## Puts the saved stable back afterwards. Run with:
## godot --headless --path . -s tests/bonding_test.gd

const SPOT := Vector2(30, 60)   ## Open meadow

var main: Node
var horse: CharacterBody3D
var bonding: Node
var stable: Node
var frames := 0
var steps: Array[Callable] = []
var wait := 0.0
var until := Callable()
var saved := {}
var ok := true
var came := [false]
var peak := [0.0]


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(what: String, passed: bool) -> void:
	print("%s: %s" % [what, "ok" if passed else "FAILED"])
	ok = ok and passed


func _process(delta: float) -> bool:
	frames += 1
	if frames == 2:
		stable = root.get_node("Stable")
		horse = main.get_node("Horse")
		bonding = main.get_node("Bonding")
		var i: int = stable.selected
		saved = {"bond": stable.bond.duplicate(), "care": stable.care[i].duplicate()}
		_plan()
	if frames < 3:
		return false
	if wait > 0.0:
		wait -= delta
		if until.is_valid() and until.call():
			wait = 0.0
		return false
	until = Callable()
	if steps.is_empty():
		var i: int = stable.selected
		stable.bond = saved.bond
		stable.care[i] = saved.care
		stable._save()
		print("PASS" if ok else "FAIL")
		quit(0 if ok else 1)
		return true
	steps.pop_front().call()
	return false


func _plan() -> void:
	var i: int = stable.selected
	var world: Node3D = main.get_node("World")
	steps.append(func():
		_check("The meadow spot is open", not world.is_in_lake(SPOT.x, SPOT.y, 3.0) and not world.is_in_arena(SPOT.x, SPOT.y, 3.0))
		horse.global_position = Vector3(SPOT.x, world.height_at(SPOT.x, SPOT.y) + 0.2, SPOT.y)
		horse.rotation.y = 0.0
		horse.set_gait(0)
		horse.speed = 0.0
		wait = 0.3)

	# Hearts grow with care.
	steps.append(func():
		stable.bond[i] = 0.0
		stable.care[i] = {"food": 0.3, "clean": 0.2, "love": 0.3}
		_check("No hearts to start with", stable.hearts(i) == 0)
		stable.feed(i)
		stable.pet(i)
		stable.brush(i, 0.5)
		_check("Feeding, petting and brushing grow the bond", stable.bond[i] > stable.BOND_FEED + stable.BOND_PET)
		stable.ride(i, 1000.0)
		_check("Riding grows the bond", stable.bond[i] > stable.BOND_FEED + stable.BOND_PET + stable.BOND_PER_KM)
		stable.bond[i] = stable.BOND_PER_HEART * 2 + 1.0
		_check("Hearts follow the bond", stable.hearts(i) == 2)
		_check("Two hearts know bow and spin, not rear", stable.knows_trick(i, "bow") and stable.knows_trick(i, "spin") and not stable.knows_trick(i, "rear"))
		stable._save()
		var config := ConfigFile.new()
		config.load(stable.SAVE_PATH)
		_check("The bond is saved", is_equal_approx(config.get_value("bond", str(i), -1.0), stable.bond[i]))
		_check("A rear isn't known yet", not bonding.do_trick("rear"))
		stable.care[i] = {"food": 0.1, "clean": 0.1, "love": 0.1}
		_check("An unhappy horse won't do tricks", not bonding.do_trick("bow"))
		stable.care[i] = {"food": 1.0, "clean": 1.0, "love": 1.0}
		stable.bond[i] = 80.0
		_check("The trick bar shows at a halt", bonding._trick_bar.visible)
		peak[0] = 0.0
		_check("A happy horse bows", bonding.do_trick("bow") and horse.trick == "bow")
		wait = 4.0
		until = func():
			peak[0] = minf(peak[0], horse.get_node("Visual").rotation.x)
			return horse.trick == "")
	steps.append(func():
		_check("The bow dips the front end", peak[0] < -0.1)
		_check("The horse stands normally after", horse.get_node("Visual").transform.is_equal_approx(Transform3D.IDENTITY))
		peak[0] = 0.0
		_check("Rearing starts", bonding.do_trick("rear"))
		wait = 4.0
		until = func():
			peak[0] = maxf(peak[0], horse.get_node("Visual").rotation.x)
			return horse.trick == "")
	steps.append(func():
		_check("Rearing lifts the front end high", peak[0] > 0.5)
		peak[0] = horse.rotation.y
		_check("Spinning starts", bonding.do_trick("spin"))
		wait = 4.0
		until = func(): return horse.trick == "")
	steps.append(func():
		_check("A spin goes right round", absf(wrapf(horse.rotation.y - peak[0], -PI, PI)) < 0.15)
		_check("The horse stayed put", Vector2(horse.global_position.x - SPOT.x, horse.global_position.z - SPOT.y).length() < 0.5))

	# Getting off, walking away and whistling.
	steps.append(func():
		_check("Getting off at a halt", bonding.get_off() and bonding.on_foot != null and not horse.ridden)
		var person: Node3D = bonding.on_foot
		var y: float = world.height_at(SPOT.x + 14.0, SPOT.y + 6.0)
		person.global_position = Vector3(SPOT.x + 14.0, y, SPOT.y + 6.0)
		_check("Too far away to get on", not bonding.get_on())
		wait = 1.0)
	steps.append(func():
		var before: float = stable.bond[i]
		horse.came_over.connect(func(): came[0] = true)
		_check("Whistling calls the horse", bonding.whistle() and horse.is_coming())
		saved["before_call"] = before
		wait = 20.0
		until = func(): return came[0])
	steps.append(func():
		_check("The horse trotted over", came[0])
		var person: Node3D = bonding.on_foot
		var away := Vector2(person.global_position.x - horse.global_position.x, person.global_position.z - horse.global_position.z).length()
		_check("It stopped next to you", away < 3.5 and away > 1.0)
		_check("Coming over grows the bond", stable.bond[i] > saved.before_call)
		_check("Taking the head collar", bonding.toggle_lead() and horse.is_led())
		Input.action_press("ride_forward")
		wait = 5.0)
	steps.append(func():
		var person: Node3D = bonding.on_foot
		var beside: Vector3 = person.global_transform.affine_inverse() * horse.global_position
		_check("The led horse walks beside you", beside.x > 0.3 and beside.x < 1.6 and absf(beside.z - horse.LEAD_BACK) < 0.8)
		_check("It walks at your pace", absf(horse.speed - person.speed) < 0.3)
		_check("The lead rope is in your hand", person._rope != null and person._rope.visible)
		Input.action_release("ride_forward")
		wait = 2.0)
	steps.append(func():
		_check("The horse stops when you stop", absf(horse.speed) < 0.2)
		_check("Letting go", not bonding.toggle_lead() and not horse.is_led())
		wait = 0.3)
	steps.append(func():
		_check("The rope goes with it", not bonding.on_foot._rope.visible)
		_check("Getting back on", bonding.get_on() and horse.ridden and bonding.on_foot == null))
