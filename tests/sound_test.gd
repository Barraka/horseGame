extends SceneTree
## Sounds: every sound file loads (and the long ones loop), the music and
## sound volume buses exist, hoofbeats keep time while riding and change
## with the ground, and looking after the horse makes its sounds. Puts the
## saved stable back afterwards. Run with:
## godot --headless --path . -s tests/sound_test.gd

const SPOT := Vector2(30, 60)   ## Open meadow

var main: Node
var horse: CharacterBody3D
var sound: Node
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
		horse = main.get_node("Horse")
		saved = {"care": stable.care[stable.selected].duplicate(), "coins": stable.coins}
		_plan()
	if frames < 3:
		return false
	if wait > 0.0:
		wait -= delta
		return false
	if steps.is_empty():
		stable.care[stable.selected] = saved.care
		stable.coins = saved.coins
		stable._save()
		print("PASS" if ok else "FAIL")
		quit(0 if ok else 1)
		return true
	steps.pop_front().call()
	return false


func _hooves(surface: String) -> int:
	var n := 0
	for name in sound.counts:
		if name.begins_with("hoof_" + surface):
			n += sound.counts[name]
	return n


func _ride_at(spot: Vector2, gait: int) -> void:
	var world: Node3D = main.get_node("World")
	horse.global_position = Vector3(spot.x, world.height_at(spot.x, spot.y) + 0.2, spot.y)
	horse.rotation.y = 0.0
	horse.speed = horse.GAITS[gait].speed
	horse.set_gait(gait)
	sound.counts.clear()


func _plan() -> void:
	var i: int = stable.selected
	steps.append(func():
		var files := DirAccess.get_files_at("res://assets/audio")
		var loaded := 0
		for file in files:
			if file.ends_with(".ogg"):
				var stream: AudioStream = sound.stream(file.get_basename())
				loaded += 1 if stream else 0
				if file.get_basename() in sound.LOOPS:
					_check("%s loops" % file.get_basename(), stream is AudioStreamOggVorbis and stream.loop)
		_check("All %d sounds load" % loaded, loaded >= 30)
		_check("Music and Sounds volume buses", AudioServer.get_bus_index("Music") >= 0 and AudioServer.get_bus_index("Sounds") >= 0)
		_ride_at(SPOT, 2)
		wait = 3.0)
	steps.append(func():
		var beats := _hooves("grass")
		print("trot on grass: %d hoofbeats in 3 s" % beats)
		_check("Hoofbeats keep time at a trot", beats >= 6 and beats <= 20)
		_ride_at(SPOT, 0)
		wait = 1.0)
	steps.append(func():
		_check("No hoofbeats standing still", _hooves("") == 0)
		var world: Node3D = main.get_node("World")
		var lake: Vector2 = world.LAKE_CENTER
		_ride_at(lake + Vector2(0, -world.LAKE_RADIUS * 0.5), 1)
		wait = 2.0)
	steps.append(func():
		_check("Splashing through the lake", _hooves("water") > 0)
		_ride_at(SPOT, 0)
		stable.care[i] = {"food": 0.3, "clean": 0.3, "love": 0.3}
		wait = 0.1)
	steps.append(func():
		sound.counts.clear()
		stable.feed(i)
		_check("A carrot crunches", sound.counts.get("crunch", 0) == 1)
		stable.pet(i)
		_check("A pat makes the horse nicker", sound.counts.get("nicker", 0) >= 1)
		stable.earn(5)
		_check("Coins chime", sound.counts.get("coin", 0) == 1))
