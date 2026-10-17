extends SceneTree
## Rides the horse to every place in the world (by moving it there) and
## checks each one is discovered and counted. Run with:
## godot --headless --path . -s tests/explore_test.gd

var main: Node
var frames := 0
var index := 0


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
	if frames < 3:
		return false
	# Move to the next place every 30 frames, then check.
	if (frames - 3) % 30 == 0:
		if index > 0:
			var id: String = world.PLACES[index - 1].id
			print("%s found: %s" % [id, id in stable.discovered])
		if index == world.PLACES.size():
			var ok: bool = stable.discovered.size() == world.PLACES.size()
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
