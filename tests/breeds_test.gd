extends SceneTree
## Breeds and foals: each breed is drawn at its own size and build, a foal
## is small and can't be ridden, carrots and time make it grow, and once
## grown up it can be ridden at its breed's size. Puts the saved stable
## back afterwards. Run with: godot --headless --path . -s tests/breeds_test.gd

const Horse := preload("res://scripts/horse.gd")

var ok := true
var frames := 0
var horse: Node3D
var saved := {}


func _check(what: String, passed: bool) -> void:
	print("%s: %s" % [what, "ok" if passed else "FAILED"])
	ok = ok and passed


func _initialize() -> void:
	horse = Horse.new()
	horse.with_rider = false
	root.add_child(horse)
	horse.set_physics_process(false)


## The horse model's size in its own space (width, height, length).
func _size() -> Vector3:
	var box := AABB()
	var first := true
	for node in horse.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.is_visible_in_tree() and mi.mesh is ArrayMesh and mi.mesh.get_blend_shape_count() > 0:
			var aabb: AABB = horse.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
			box = aabb if first else box.merge(aabb)
			first = false
	return box.size


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 3:
		return false
	var stable := root.get_node("Stable")
	saved = {"growth": stable.growth.duplicate(), "bought": stable.bought.duplicate(), "selected": stable.selected}
	var daisy := -1
	for i in stable.HORSES.size():
		_check("%s has a breed" % stable.HORSES[i].name, stable.BREEDS.has(stable.HORSES[i].get("breed", "")))
		if stable.HORSES[i].name == "Daisy":
			daisy = i
	var hazel: Vector3 = stable.body_shape(0)
	var honey: Vector3 = stable.body_shape(4)   # Welsh pony
	var shadow: Vector3 = stable.body_shape(10) # Gypsy cob
	_check("A pony is smaller than a warmblood", honey.y < hazel.y and honey.z < hazel.z)
	_check("A cob is broad", shadow.x / shadow.z > hazel.x / hazel.z + 0.1)

	horse.set_body_shape(hazel)
	var big := _size()
	horse.set_body_shape(honey)
	var small := _size()
	_check("The model is drawn at the pony's size", absf(small.y / big.y - honey.y) < 0.02)

	# A new foal.
	stable.growth.erase("Daisy")
	if not "Daisy" in stable.bought:
		stable.bought.append("Daisy")
	_check("A new foal can't be ridden", stable.is_foal(daisy) and not stable.can_ride(daisy))
	stable.select(daisy)
	_check("Choosing a foal to ride doesn't work", stable.selected != daisy)
	var foal: Vector3 = stable.body_shape(daisy)
	_check("A foal is small, with long legs", foal.y < honey.y * 0.75 and foal.y / foal.z > honey.y / honey.z)
	stable.care[daisy].food = 0.2
	stable.feed(daisy)
	_check("A carrot helps a foal grow", stable.grown(daisy) >= stable.FOAL_FEED_GROWTH)
	var fed: Vector3 = stable.body_shape(daisy)
	_check("Growing makes it bigger", fed.y > foal.y)
	var grew := [false]
	stable.grown_up.connect(func(i): grew[0] = i == daisy)
	stable.care[daisy] = {"food": 1.0, "clean": 1.0, "love": 1.0}
	stable._pass_time(stable.FOAL_GROW_HOURS)
	_check("A foal grows up in time", grew[0] and stable.can_ride(daisy))
	_check("Grown up it is its breed's size", stable.body_shape(daisy).is_equal_approx(honey))

	stable.growth = saved.growth
	stable.bought = saved.bought
	stable.select(saved.selected)
	print("RESULT: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
	return true
