extends SceneTree
## Plays every quest: talks to each person, accepts their quest, does it
## (jumps a clear round, picks things up, delivers the letter, gallops),
## goes back for the reward, and checks the coins add up. Puts the saved
## quests and coins back afterwards. Run with:
## godot --headless --path . -s tests/quest_test.gd

var main: Node
var quests: Node
var horse: CharacterBody3D
var frames := 0
var steps: Array[Callable] = []
var wait := 0
var saved := {}
var ok := true


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(what: String, passed: bool) -> void:
	print("%s: %s" % [what, "ok" if passed else "FAILED"])
	ok = ok and passed


## Put the horse next to a person or on a spot, and wait a few frames.
func _go(to: Vector2) -> void:
	var y: float = main.get_node("World").height_at(to.x, to.y)
	horse.global_position = Vector3(to.x, y + 0.1, to.y)
	wait = 4


func _go_to_person(id: String) -> void:
	_go(quests.PEOPLE[id].pos + Vector2(2.5, 0))


## Press the dialog's first (main) button.
func _press() -> void:
	_check("Talking to someone", quests._dialog.visible)
	var button: Button = quests._buttons.get_child(0)
	button.pressed.emit()
	wait = 2


func _process(_delta: float) -> bool:
	frames += 1
	var stable := root.get_node("Stable")
	if frames == 2:
		quests = main.get_node("Quests")
		horse = main.get_node("Horse")
		horse.set_physics_process(false)
		saved = {"quests": stable.quests.duplicate(true), "coins": stable.coins, "discovered": stable.discovered.duplicate()}
		stable.quests.clear()
		# Count only quest rewards, not coins for finding places on the way.
		for place in main.get_node("World").PLACES:
			if not place.id in stable.discovered:
				stable.discovered.append(place.id)
		quests._refresh()
		_plan(stable)
		return false
	if frames < 3:
		return false
	if wait > 0:
		wait -= 1
		return false
	if steps.is_empty():
		_check("All quests done", stable.quests.size() == quests.QUESTS.size()
			and stable.quests.values().all(func(q): return q.state == "done"))
		_check("Rewards add up to 270 coins", stable.coins - saved.coins == 270)
		stable.quests = saved.quests
		stable.coins = saved.coins
		stable.discovered = saved.discovered
		stable.select(stable.selected)   # Save them back
		print("RESULT: ", "PASS" if ok else "FAIL")
		quit(0 if ok else 1)
		return true
	steps.pop_front().call()
	return false


func _plan(stable: Node) -> void:
	# Lily: a clear round.
	steps.append(_go_to_person.bind("lily"))
	steps.append(_press)
	steps.append(func(): _check("Lily's quest accepted", stable.quest_state("clear_round") == "active"))
	steps.append(func(): quests._on_course_finished(30.0, 0))
	steps.append(func(): _check("Clear round counted", stable.quest_state("clear_round") == "ready"))
	steps.append(func(): _go(Vector2(0, 30)))
	steps.append(_go_to_person.bind("lily"))
	steps.append(_press)
	# Tom, Mia and Sam: things to pick up.
	for quest in [["tom", "apples"], ["mia", "flowers"], ["sam", "horseshoe"]]:
		steps.append(_go_to_person.bind(quest[0]))
		steps.append(_press)
		steps.append(_collect.bind(quest[1]))
		steps.append(func(): _check("%s picked up" % quest[1], stable.quest_state(quest[1]) == "ready"))
		steps.append(_go_to_person.bind(quest[0]))
		steps.append(_press)
	# Rosa's letter to Ben, then Ben's gallop.
	steps.append(_go_to_person.bind("rosa"))
	steps.append(_press)
	steps.append(_go_to_person.bind("ben"))
	steps.append(_press)   # Hand in the letter...
	steps.append(func(): _check("Letter delivered", stable.quest_state("letter") == "done"))
	steps.append(_press)   # ...and Ben offers the gallop straight away
	steps.append(_gallop)
	steps.append(func(): _check("Galloped 500 m", stable.quest_state("gallop") == "ready"))
	steps.append(_go_to_person.bind("ben"))
	steps.append(_press)


## Visit each of a quest's things in turn (as extra steps, run next).
func _collect(id: String) -> void:
	var visits: Array[Callable] = []
	for item in quests._items[id]:
		if item != null:
			visits.append(_go.bind(Vector2(item.position.x, item.position.z)))
	steps = visits + steps


## Gallop in a straight line, a little each frame.
func _gallop() -> void:
	var visits: Array[Callable] = []
	horse.current_gait = 4
	for i in 300:
		visits.append(func():
			horse.global_position += Vector3(1.9, 0, 0)
			if i == 0:
				horse.global_position = Vector3(0, 0.6, 40))
	steps = visits + steps
