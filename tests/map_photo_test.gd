extends SceneTree
## The map and photo mode: Tab opens the map (the game waits) with you,
## the places and the people on it; P opens photo mode, which hides the
## buttons, moves its own camera around the horse and takes a photo; both
## put the game back as it was when closed. Run with:
## godot --headless --path . -s tests/map_photo_test.gd

var main: Node
var frames := 0
var ok := true
var photo_path := ""


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)


func _check(what: String, good: bool) -> void:
	print("%s: %s" % [what, "yes" if good else "NO"])
	ok = ok and good


func _process(_delta: float) -> bool:
	frames += 1
	var map: CanvasLayer = main.get_node("WorldMap")
	var photo: CanvasLayer = main.get_node("PhotoMode")
	var hud: CanvasLayer = main.get_node("HUD")
	var horse: Node3D = main.get_node("Horse")
	if frames == 5:
		_key(KEY_TAB)
	elif frames == 7:
		_check("Tab opens the map", map.is_open())
		_check("The game waits while the map is open", paused)
		_check("The ground is drawn", map._ground != null and map._ground.get_width() == map.PIXELS)
		_check("Trees are on the map", map._trees.size() > 100)
		var box: Rect2 = map._map_rect()
		var you: Vector2 = map._to_map(Vector2(horse.global_position.x, horse.global_position.z))
		_check("You are on the map", box.has_point(you))
		var lake: Vector2 = map._to_map(main.get_node("World").LAKE_CENTER)
		_check("The lake is right of and below the arena", lake.x > box.get_center().x and lake.y > box.get_center().y)
		_check("The HUD hides behind the map", not hud.visible)
		_key(KEY_TAB)
	elif frames == 9:
		_check("Tab closes the map", not map.is_open() and not paused and hud.visible)
		_key(KEY_P)
	elif frames == 11:
		_check("P opens photo mode", photo.is_open() and paused)
		_check("The buttons are hidden", not hud.visible and not map.visible)
		_check("Photo mode has its own camera", root.get_viewport().get_camera_3d() == photo._camera)
		var before: Vector3 = photo._camera.global_position
		photo._turn(Vector2(200, 0))
		photo._zoom(0.8)
		var target: Vector3 = photo._target()
		_check("Dragging moves the camera around the horse", photo._camera.global_position.distance_to(before) > 0.5)
		_check("The camera keeps looking at the horse", (-photo._camera.global_transform.basis.z).dot((target - photo._camera.global_position).normalized()) > 0.99)
		photo._set_look(2)
		_check("A look can be picked", photo._filter.visible and photo._look_label.text == "Black & white")
		photo.take_photo()
	elif frames == 16:
		photo.close()
	elif frames == 18:
		_check("Closing photo mode puts the game back", not photo.is_open() and not paused and hud.visible and map.visible)
		_check("The game camera is back", root.get_viewport().get_camera_3d() != null and root.get_viewport().get_camera_3d() != photo._camera)
		_check("Photos have a folder", DirAccess.dir_exists_absolute(photo.photos_dir()))
		print("RESULT: ", "PASS" if ok else "FAIL")
		quit(0 if ok else 1)
		return true
	return false
