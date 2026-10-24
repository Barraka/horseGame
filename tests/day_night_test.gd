extends SceneTree
## Turns the clock and the weather and checks the light follows: bright
## warm sun at noon, low orange sun at sunset, dim blue moonlight with
## stars at night, rain falling when it rains and a rainbow after it.
## Run with: godot --headless --path . -s tests/day_night_test.gd

var main: Node
var frames := 0
var ok := true


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(what: String, good: bool) -> void:
	print("%s: %s" % [what, "ok" if good else "WRONG"])
	ok = ok and good


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 3:
		return false
	var sky: Node = main.get_node("SkyCycle")
	var sun: DirectionalLight3D = main.get_node("Sun")
	sky.running = false
	var mat: ShaderMaterial = main.get_node("WorldEnvironment").environment.sky.sky_material
	match frames:
		3:
			sky.hour = 12.0
		5:
			_check("noon sun high and bright", sun.light_energy > 1.0 and -sun.global_basis.z.y < -0.7)
			_check("no stars at noon", mat.get_shader_parameter("night") < 0.01)
			sky.hour = 17.6
		7:
			_check("sunset glow", mat.get_shader_parameter("glow") > 0.5)
			_check("sunset light orange", sun.light_color.b < 0.6)
			sky.hour = 0.0
		9:
			_check("night stars", mat.get_shader_parameter("night") > 0.99)
			_check("moonlight dim and blue", sun.light_energy < 0.6 and sun.light_color.b > sun.light_color.r)
			_check("moon above the ground", -sun.global_basis.z.y < 0.0)
			_check("fireflies at night", main.get_node("SkyCycle/Fireflies").emitting)
			sky.hour = 15.0
			sky.set_weather("rain")
		10:
			sky.rain = 1.0
			sky.cover = 0.95
		12:
			_check("rain falling", main.get_node("SkyCycle/Rain").emitting)
			_check("rain darkens the sun", sun.light_energy < 0.8)
			sky.set_weather("clear")
		13:
			sky.rain = 0.0
			sky.rainbow = 1.0
		15:
			_check("rainbow after rain", mat.get_shader_parameter("rainbow") > 0.5)
			_check("rain stopped", not main.get_node("SkyCycle/Rain").emitting)
			print("RESULT: ", "PASS" if ok else "FAIL")
			quit(0 if ok else 1)
			return true
	return false
