extends SceneTree
## Smoke test: an autopilot rides the show jumping course and checks the
## result: lap 1 jumps every fence (expects a clear round), lap 2 jumps
## nothing (expects 4 faults per fence). It also checks that riding left the
## horse hungrier and muddier. Run with:  godot --headless --path . -s tests/ride_test.gd

var main: Node
var horse: CharacterBody3D
var course: Node
var frames := 0
var jumped_for := -1
var messages: Array[String] = []
var lap := 1
var lap1_faults := -1
var heading_home := false
var care_before := {}
var coins_before := 0
var training_before := {}
var ridden := 0.0
var last_pos := Vector3.INF


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	horse = main.get_node("Horse")
	course = main.get_node("Course")
	course.announce.connect(func(t): messages.append(t); print("  course: ", t))


func _target() -> Vector2:
	if heading_home:
		return Vector2(0, 2)
	if course.state != course.State.RIDING:
		var g: Vector3 = course.start.global_position
		return Vector2(g.x, g.z - 2)
	if course.next_fence < course.fences.size():
		var f: Vector3 = course.fences[course.next_fence].global_position
		return Vector2(f.x, f.z)
	var fin: Vector3 = course.finish.global_position
	return Vector2(fin.x, fin.z)


func _process(delta: float) -> bool:
	frames += 1
	if frames == 2:
		horse.set_gait(3)
		# Start from a full, clean horse so the drop is easy to see.
		var stable := root.get_node("Stable")
		stable.care[stable.selected].food = 1.0
		stable.care[stable.selected].clean = 1.0
		care_before = stable.care[stable.selected].duplicate()
		coins_before = stable.coins
		training_before = stable.training[stable.selected].duplicate()
	var pos := Vector2(horse.global_position.x, horse.global_position.z)
	if last_pos != Vector3.INF:
		ridden += Vector2(last_pos.x, last_pos.z).distance_to(pos)
	last_pos = horse.global_position
	var target := _target()
	var to_target := target - pos
	var forward := Vector2(-sin(horse.rotation.y), -cos(horse.rotation.y))
	var angle := forward.angle_to(to_target)
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	if absf(angle) > 0.03:
		Input.action_press("steer_right" if angle > 0 else "steer_left", clampf(absf(angle) * 2.0, 0.2, 1.0))
	if course.state == course.State.RIDING and course.next_fence < course.fences.size() \
			and lap == 1 and to_target.length() < 3.6 and jumped_for != course.next_fence:
		jumped_for = course.next_fence
		horse.jump()
	if frames % 120 == 0:
		print("t=%.0fs pos=(%.1f, %.1f) gait=%d speed=%.1f state=%d next=%d" % [frames / 60.0, pos.x, pos.y, horse.current_gait, horse.speed, course.state, course.next_fence])
	if heading_home and pos.distance_to(Vector2(0, 2)) < 2.0:
		heading_home = false
	if course.state == course.State.DONE and lap == 1:
		lap1_faults = course.faults
		print("LAP 1 (jumping): time=%.1f faults=%d" % [course.time, course.faults])
		lap = 2
		heading_home = true
		course.state = course.State.READY
	elif course.state == course.State.DONE and lap == 2:
		print("LAP 2 (no jumps): time=%.1f faults=%d" % [course.time, course.faults])
		var stable := root.get_node("Stable")
		var care: Dictionary = stable.care[stable.selected]
		print("CARE after %.0f m: food %.2f -> %.2f, clean %.2f -> %.2f" % [ridden, care_before.food, care.food, care_before.clean, care.clean])
		var worn: bool = care.food < care_before.food and care.clean < care_before.clean
		# A clear round (40), a round with faults (15), and a coin per 50 m.
		var earned: int = stable.coins - coins_before
		var paid: bool = earned == 55 + int(ridden / 50.0) or earned == 55 + int(ridden / 50.0) - 1
		print("COINS earned: %d" % earned)
		# Cantering trains speed and stamina; lap 1 jumped 5 fences clear.
		var t: Dictionary = stable.training[stable.selected]
		var jumps: int = course.fences.size() * (stable.JUMP_POINTS + stable.CLEAR_FENCE_POINTS)
		var trained: bool = t.speed > training_before.speed + ridden * 0.05 and t.stamina > training_before.stamina + ridden * 0.05 \
			and t.jumping == training_before.jumping + jumps
		print("TRAINING: speed +%.0f, stamina +%.0f, jumping +%.0f" % [t.speed - training_before.speed, t.stamina - training_before.stamina, t.jumping - training_before.jumping])
		stable.training[stable.selected] = training_before
		stable.coins = coins_before
		stable.select(stable.selected)   # Save the coins back
		var ok: bool = lap1_faults == 0 and course.faults == 4 * course.fences.size() and worn and paid and trained
		print("RESULT: ", "PASS" if ok else "FAIL")
		quit(0 if ok else 1)
	elif frames > 60 * 400:
		print("RESULT: FAIL (timed out on lap %d)" % lap)
		quit(1)
	return false
