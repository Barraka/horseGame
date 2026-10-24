extends SceneTree
## The snowy mountains: a horse can canter up through the pass into the
## valley, the track to every mountain place is gentle enough to ride,
## snow falls there (and rain turns to snow), hooves crunch in the snow and
## clop on the ice, and the hut, the lake's ice and the falls are built.
## Puts the saved stable back afterwards. Run with:
## godot --headless --path . -s tests/mountains_test.gd

var main: Node
var world: Node3D
var horse: CharacterBody3D
var sound: Node
var sky: Node
var stable: Node
var frames := 0
var steps: Array[Callable] = []
var wait := 0.0
var saved := {}
var ok := true


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
		sound = root.get_node("Sound")
		world = main.get_node("World")
		horse = main.get_node("Horse")
		sky = main.get_node("SkyCycle")
		saved = {"care": stable.care[stable.selected].duplicate(), "coins": stable.coins, "discovered": stable.discovered.duplicate(),
			"weather": sky.weather}
		_plan()
	if frames < 3:
		return false
	if wait > 0.0:
		wait -= delta
		return false
	if steps.is_empty():
		sky.set_weather(saved.weather)
		stable.care[stable.selected] = saved.care
		stable.coins = saved.coins
		stable.discovered = saved.discovered
		stable._save()
		print("RESULT: ", "PASS" if ok else "FAIL")
		quit(0 if ok else 1)
		return true
	steps.pop_front().call()
	return false


func _place(id: String) -> Dictionary:
	for place in world.PLACES:
		if place.id == id:
			return place
	return {}


func _put(spot: Vector2, gait: int) -> void:
	horse.global_position = Vector3(spot.x, world.height_at(spot.x, spot.y) + 0.3, spot.y)
	horse.rotation.y = 0.0
	horse.speed = horse.GAITS[gait].speed
	horse.set_gait(gait)
	sound.counts.clear()


func _hooves(surface: String) -> int:
	var n := 0
	for name in sound.counts:
		if name.begins_with("hoof_" + surface):
			n += sound.counts[name]
	return n


func _plan() -> void:
	steps.append(func():
		_check("Three mountain places", ["frozen_lake", "hut", "falls"].all(func(id): return not _place(id).is_empty()))
		_check("The mountain ground is built", world.has_node("Mountains") and world.has_node("MountainsBody"))
		var mountains := main.get_node("Mountains")
		_check("The hut, the ice and the snowman are built", mountains.has_node("MountainHut") and mountains.has_node("Ice") and mountains.has_node("Snowman"))
		# Every stretch of the track is gentle enough to ride.
		var steepest := 0.0
		var track: Array = world.MOUNTAIN_PATH + world.SNOW_TRACK
		for i in track.size() - 1:
			var a: Vector2 = track[i]
			var b: Vector2 = track[i + 1]
			for step in int(a.distance_to(b)):
				var p := a.lerp(b, step / a.distance_to(b))
				var q := a.lerp(b, (step + 1.0) / a.distance_to(b))
				steepest = maxf(steepest, absf(world.height_at(q.x, q.y) - world.height_at(p.x, p.y)))
		print("steepest metre of the track: %.2f m" % steepest)
		_check("The track to the mountains is gentle", steepest < 0.5)
		# The peaks really are high, and the snow line is where it should be.
		_check("Peaks rise around the valley", world.height_at(0.0, -432.0) > 50.0 and world.height_at(120.0, -330.0) > 40.0)
		_check("Snow only past the snow line", world.snow_at(0.0, -100.0) == 0.0 and world.snow_at(0.0, -300.0) == 1.0)
		# Canter north up the trail towards the pass.
		_put(Vector2(world.PASS_X, -200.0), 3)
		wait = 12.0)
	steps.append(func():
		var at := horse.global_position
		print("after cantering through the pass: x %.1f z %.1f" % [at.x, at.z])
		_check("Cantering through the pass reaches the valley", at.z < -255.0)
		_check("Hooves crunch in the snow", _hooves("snow") > 0)
		_check("Snow is falling", main.get_node("Mountains/Snowfall").emitting and sky.snow_zone > 0.9)
		sky.set_weather("rain")
		sky.rain = 1.0
		wait = 0.5)
	steps.append(func():
		_check("Rain falls as snow up here", not sky.get_node("Rain").emitting and main.get_node("Mountains/Snowfall").amount_ratio > 0.9)
		var lake: Vector2 = _place("frozen_lake").pos
		_put(lake + Vector2(0, 8), 1)
		wait = 2.0)
	steps.append(func():
		_check("Hooves clop on the ice", _hooves("dirt") > 0 and _hooves("snow") == 0)
		_check("Riding onto the ice finds the Frozen Lake", "frozen_lake" in stable.discovered)
		# Back down in the meadow, rain is rain again.
		_put(Vector2(30, 60), 0)
		wait = 1.0)
	steps.append(func():
		_check("Rain again in the meadow", sky.get_node("Rain").emitting and not main.get_node("Mountains/Snowfall").emitting))
