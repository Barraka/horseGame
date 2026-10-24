extends SceneTree
## Rides the horse to every place in the world (by moving it there) and
## checks each one is discovered and counted, that grass grew along the
## way but not in the arena, the lake or the middle of the trail, and that
## every kind of tree, bush and rock is there, out of the arena and lake. Run with:
## godot --headless --path . -s tests/explore_test.gd

var main: Node
var frames := 0
var index := 0
var coins_before := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	var stable := root.get_node("Stable")
	var world := main.get_node("World")
	var horse: Node3D = main.get_node("Horse")
	if frames == 2:
		stable.discovered.clear()
		coins_before = stable.coins
	if frames < 3:
		return false
	# Move to the next place every 30 frames, then check.
	if (frames - 3) % 30 == 0:
		if index > 0:
			var id: String = world.PLACES[index - 1].id
			print("%s found: %s" % [id, id in stable.discovered])
		if index == world.PLACES.size():
			var earned: int = stable.coins - coins_before
			print("coins earned: %d" % earned)
			var ok: bool = stable.discovered.size() == world.PLACES.size() and earned == stable.PLACE_COINS * world.PLACES.size()
			ok = _grass_ok(world) and ok
			ok = _trees_ok(world) and ok
			stable.coins = coins_before
			print("RESULT: ", "PASS" if ok else "FAIL")
			stable.discovered.clear()
			stable.select(stable.selected)   # Save the cleared list again
			quit(0 if ok else 1)
			return true
		var pos: Vector2 = world.PLACES[index].pos
		var near := pos + (Vector2.ZERO - pos).normalized() * 12.0
		if world.PLACES[index].id == "lake":
			near = pos + (Vector2.ZERO - pos).normalized() * (world.LAKE_RADIUS + 8.0)
		horse.global_position = Vector3(near.x, world.height_at(near.x, near.y) + 0.5, near.y)
		index += 1
	return frames > 60 * 30


func _grass_ok(world: Node3D) -> bool:
	var squares := world.get_node("Grass").get_children()
	var tufts := 0
	var misplaced := 0
	for square in squares:
		var mm: MultiMesh = square.multimesh
		for i in mm.instance_count:
			var p := mm.get_instance_transform(i).origin
			tufts += 1
			if world.is_in_arena(p.x, p.z) or world.is_in_lake(p.x, p.z, -1.0) or world.trail_at(p.x, p.z) > 0.5:
				misplaced += 1
	print("grass: %d squares, %d tufts, %d in the wrong place" % [squares.size(), tufts, misplaced])
	return squares.size() > 100 and tufts > 50000 and misplaced == 0


func _trees_ok(world: Node3D) -> bool:
	var kinds := {}
	var misplaced := 0
	for node in world.get_children():
		if not node.name.begins_with("Trees_"):
			continue
		var mm: MultiMesh = node.multimesh
		kinds[String(node.name).trim_prefix("Trees_").get_slice(":", 0).rsplit("_", true, 3)[0]] = true
		for i in mm.instance_count:
			var p := mm.get_instance_transform(i).origin
			if world.is_in_arena(p.x, p.z) or world.is_in_lake(p.x, p.z, 2.0):
				misplaced += 1
	print("trees: kinds %s, %d in the wrong place" % [kinds.keys(), misplaced])
	return kinds.size() == world.Trees.KINDS.size() + 1 and kinds.has("rock") and misplaced == 0
