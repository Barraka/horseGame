extends SceneTree
## Rides through the gaits and checks the rider moves with the horse:
## rising at the trot with the feet staying in the stirrups, leaning
## forward at the gallop, folding over a jump and leaning into a turn. Run
## with: godot --headless --path . -s tests/rider_test.gd

const STEP := 1.0 / 60.0

var main: Node
var frames := 0
var ok := true
var horse: Node3D
var rider: Node3D
var rise := Vector2(INF, -INF)    # Lowest and highest the rider rose at the trot
var feet_moved := 0.0             # Furthest the feet moved in the saddle meanwhile
var feet_at := Vector3.INF
var lean := 0.0
var fold := 0.0
var roll := 0.0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(what: String, passed: bool) -> void:
	print("%s: %s" % [what, "ok" if passed else "FAILED"])
	ok = ok and passed


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 2:
		horse = main.get_node("Horse")
		rider = horse._rider
		horse.set_physics_process(false)   # Stepped evenly below
	if frames < 3:
		return false
	var t := (frames - 3) * STEP
	horse.energy = 1.0
	horse.set_gait(2 if t < 4.0 else 4)
	if t >= 7.0 and t < 7.0 + STEP:
		horse.jump()
	if t >= 8.5:
		Input.action_press("steer_right")
	horse._physics_process(STEP)
	if t > 2.5 and t < 4.0:
		var up: float = rider.position.y - rider.seat.y
		rise = Vector2(minf(rise.x, up), maxf(rise.y, up))
		var skeleton: Skeleton3D = rider.skeleton
		var foot := (horse._saddle as Node3D).global_transform.affine_inverse() * (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("ball_l")).origin)
		if feet_at == Vector3.INF:
			feet_at = foot
		feet_moved = maxf(feet_moved, foot.distance_to(feet_at))
	if t > 6.5 and t < 7.0:
		lean = maxf(lean, horse._ride.lean)
	if horse.jumping:
		fold = maxf(fold, horse._ride.fold)
	if t > 9.0:
		roll = maxf(roll, horse._ride.roll)
	if t < 9.5:
		return false
	Input.action_release("steer_right")
	_check("The rider rises and sits at the trot", rise.y - rise.x > 0.05)
	_check("Their feet stay in the stirrups (moved %.3f m)" % feet_moved, feet_moved < 0.04)
	_check("They lean forward at the gallop", lean > 25.0)
	_check("They fold over a jump", fold > 0.9)
	_check("They lean into a turn", roll > 3.0)
	print("RESULT: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
	return true
