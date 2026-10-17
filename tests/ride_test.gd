extends SceneTree
## Smoke test: an autopilot rides the show jumping course and checks the
## result: lap 1 jumps every fence (expects a clear round), lap 2 jumps
## nothing (expects 4 faults per fence). Run with:  godot --headless --path . -s tests/ride_test.gd

var main: Node
var horse: CharacterBody3D
var course: Node
var frames := 0
var jumped_for := -1
var messages: Array[String] = []
var lap := 1
var lap1_faults := -1
var heading_home := false


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
	var pos := Vector2(horse.global_position.x, horse.global_position.z)
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
		var ok: bool = lap1_faults == 0 and course.faults == 4 * course.fences.size()
		print("RESULT: ", "PASS" if ok else "FAIL")
		quit(0 if ok else 1)
	elif frames > 60 * 400:
		print("RESULT: FAIL (timed out on lap %d)" % lap)
		quit(1)
	return false
