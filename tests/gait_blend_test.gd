extends SceneTree
## Rides the horse up through the gaits and back down, and checks each
## change blends smoothly: both gaits are shown together for a moment, the
## pose always adds up to one whole horse, and the back never moves faster
## while blending than it does in a gait's own stride. Run with:
## godot --headless --path . -s tests/gait_blend_test.gd

var main: Node
var frames := 0
var ok := true
var blended := 0    # Frames showing two gaits at once
var last_seat := Vector3.INF
var fastest_stride := 0.0   # Fastest the saddle moved on the horse in one gait, in m/s
var fastest_blend := 0.0    # ...and while blending two
var saved_training: Dictionary


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	frames += 1
	var stable := root.get_node("Stable")
	var horse: Node3D = main.get_node("Horse")
	if frames == 2:
		saved_training = stable.training[stable.selected].duplicate()
		var mesh: ArrayMesh = horse._set_model.mesh
		if mesh.get_blend_shape_count() < 80:
			print("FAIL: the blended horse has only %d poses" % mesh.get_blend_shape_count())
			ok = false
	if frames < 3:
		return false
	horse.energy = 1.0
	# Up through the gaits and back down, a couple of seconds each.
	var plan := [1, 2, 3, 4, 3, 2, 1, 0]
	horse.set_gait(plan[mini(frames / 120, plan.size() - 1)])
	var total := 0.0
	var gaits := {}
	for shape in horse._weights:
		total += horse._weights[shape]
		gaits[_gait_of(shape)] = true
	if absf(total - 1.0) > 0.001:
		print("FAIL: frame %d's pose weights add up to %.3f" % [frames, total])
		ok = false
	if gaits.size() > 1:
		blended += 1
	# The saddle follows the horse's back, which must never jump.
	var seat: Vector3 = horse.get_node("Visual/Saddle").position
	if last_seat != Vector3.INF:
		var moved := seat.distance_to(last_seat) / maxf(delta, 1.0 / 60.0)
		if gaits.size() > 1:
			fastest_blend = maxf(fastest_blend, moved)
		else:
			fastest_stride = maxf(fastest_stride, moved)
	last_seat = seat
	if frames < 120 * 8 + 60:
		return false
	if blended < 20:
		print("FAIL: only %d frames blended two gaits" % blended)
		ok = false
	if fastest_blend > fastest_stride * 1.2:
		print("FAIL: the back jumped while blending gaits (%.1f m/s, against %.1f m/s in a stride)" % [fastest_blend, fastest_stride])
		ok = false
	print("frames blending two gaits: %d; fastest the back moved: %.1f m/s blending, %.1f m/s in a stride" % [blended, fastest_blend, fastest_stride])
	stable.training[stable.selected] = saved_training
	stable._save()
	print("RESULT: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
	return true


func _gait_of(shape: int) -> int:
	var GaitBlend = load("res://scripts/gait_blend.gd")
	for gait in range(GaitBlend._first_shape.size() - 1, -1, -1):
		if shape >= GaitBlend._first_shape[gait]:
			return gait
	return 0
