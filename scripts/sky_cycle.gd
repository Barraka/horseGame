extends Node
## Day and night, and the weather. The hour goes round (a whole day takes
## DAY_MINUTES real minutes): the sun rises in the east, climbs over the
## south and sets in the west with a warm glow; at night the moon and stars
## come out and the light turns blue. Now and then clouds roll in and it
## rains, and when the rain stops in the daytime a rainbow shows for a
## while. T moves the clock on two hours, R changes the weather.

const DAY_MINUTES := 12.0
const SUN_ENERGY := 1.35
const MOON_ENERGY := 0.32
const RAINBOW_SECONDS := 60.0
const WEATHERS := ["clear", "cloudy", "rain"]

@export var sun_path: NodePath
@export var environment_path: NodePath
@export var hour := 10.0           ## 0 to 24
@export var running := true        ## Let the clock and the weather go by

var weather := "clear"
var cover := 0.25                  ## How cloudy, follows the weather
var rain := 0.0                    ## How hard it rains, follows the weather
var rainbow := 0.0
var snow_zone := 0.0               ## How far into the snowy mountains the camera is (set by mountains.gd); rain falls as snow there
var _rainbow_left := 0.0
var _weather_left := 0.0           ## Seconds until the weather may change
var _sun: DirectionalLight3D
var _env: Environment
var _sky: ShaderMaterial
var _rain: GPUParticles3D
var _fireflies: GPUParticles3D
var _moonlight: OmniLight3D       ## A soft light by the camera at night, so the horse stays easy to see
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_sun = get_node(sun_path)
	_env = (get_node(environment_path) as WorldEnvironment).environment
	Settings.apply_environment(_env)
	Settings.apply_sun(_sun)
	_rng.randomize()
	_weather_left = _rng.randf_range(90.0, 150.0)
	_sky = ShaderMaterial.new()
	_sky.shader = preload("res://shaders/sky.gdshader")
	var noise := FastNoiseLite.new()
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var clouds := NoiseTexture2D.new()
	clouds.width = 512
	clouds.height = 512
	clouds.seamless = true
	clouds.noise = noise
	_sky.set_shader_parameter("cloud_noise", clouds)
	_env.sky.sky_material = _sky
	_env.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	_rain = _rain_particles()
	add_child(_rain)
	_fireflies = _firefly_particles()
	add_child(_fireflies)
	_moonlight = OmniLight3D.new()
	_moonlight.light_color = Color(0.72, 0.8, 1.0)
	_moonlight.omni_range = 10.0
	_moonlight.omni_attenuation = 1.5
	_moonlight.light_energy = 0.0
	_moonlight.shadow_enabled = false
	add_child(_moonlight)
	_apply()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_T:
		hour = fmod(hour + 2.0, 24.0)
	elif key.physical_keycode == KEY_R:
		set_weather(WEATHERS[(WEATHERS.find(weather) + 1) % WEATHERS.size()])


func _process(delta: float) -> void:
	if running:
		hour = fmod(hour + delta * 24.0 / (DAY_MINUTES * 60.0), 24.0)
		_weather_left -= delta
		if _weather_left <= 0.0:
			var roll := _rng.randf()
			set_weather("clear" if roll < 0.6 else ("cloudy" if roll < 0.85 else "rain"))
	var want_cover: float = {"clear": 0.25, "cloudy": 0.7, "rain": 0.95}[weather]
	cover = move_toward(cover, want_cover, delta / 20.0)
	rain = move_toward(rain, 1.0 if weather == "rain" else 0.0, delta / 12.0)
	_rainbow_left = maxf(_rainbow_left - delta, 0.0)
	var bow := 1.0 if _rainbow_left > 0.0 and rain < 0.3 else 0.0
	rainbow = move_toward(rainbow, bow, delta / 6.0)
	var camera := get_viewport().get_camera_3d()
	if camera:
		_rain.global_position = camera.global_position + Vector3(0, 10, 0) - camera.global_basis.z * 6.0
		_moonlight.global_position = camera.global_position + Vector3(0, 1.5, 0)
		_fireflies.global_position = camera.global_position + Vector3(0, -1.5, 0) - camera.global_basis.z * 8.0
	_apply()


## Change the weather now; it then stays a few minutes. A rainbow follows
## rain that stops while the sun is up.
func set_weather(next: String) -> void:
	if weather == "rain" and next != "rain" and sun_direction().y > 0.05:
		_rainbow_left = RAINBOW_SECONDS
	weather = next
	_weather_left = _rng.randf_range(120.0, 240.0) * (0.6 if next == "rain" else 1.0)


## Towards the sun: up at noon, below the ground at midnight.
func sun_direction() -> Vector3:
	var a := (hour - 6.0) / 12.0 * PI
	return Vector3(cos(a), sin(a) * 0.82, sin(a) * 0.57).normalized()


## How much it is day, 0 at night and 1 once the sun is up.
func daylight() -> float:
	return smoothstep(-0.12, 0.2, sun_direction().y)


func _apply() -> void:
	var to_sun := sun_direction()
	var to_moon := -to_sun
	var day := daylight()
	var night := 1.0 - smoothstep(-0.2, 0.02, to_sun.y)
	var glow := smoothstep(0.42, 0.05, to_sun.y) * smoothstep(-0.25, 0.0, to_sun.y)
	var storm := rain

	# One light: the sun by day, the moon by night.
	var sun_energy := SUN_ENERGY * smoothstep(-0.03, 0.25, to_sun.y)
	var moon_energy := MOON_ENERGY * smoothstep(-0.02, -0.25, to_sun.y)
	var from := to_sun if sun_energy >= moon_energy else to_moon
	_sun.global_basis = Basis.looking_at(-from, Vector3.UP if absf(from.y) < 0.99 else Vector3.FORWARD)
	var warm := Color(1.0, 0.9, 0.74).lerp(Color(1.0, 0.55, 0.3), glow)
	_sun.light_color = warm if sun_energy >= moon_energy else Color(0.6, 0.7, 1.0)
	_sun.light_energy = maxf(sun_energy, moon_energy) * (1.0 - storm * 0.55) * (1.0 - cover * 0.2)

	# The sky's colours.
	var top := Color(0.04, 0.06, 0.16).lerp(Color(0.22, 0.47, 0.88), day)
	var horizon := Color(0.1, 0.13, 0.25).lerp(Color(0.86, 0.87, 0.9), day)
	top = top.lerp(Color(0.32, 0.36, 0.68), glow * 0.6)
	horizon = horizon.lerp(Color(1.0, 0.62, 0.42), glow * 0.8)
	var grey := Color(0.55, 0.57, 0.6) * lerpf(0.25, 1.0, day)
	top = top.lerp(grey, storm * 0.7)
	horizon = horizon.lerp(grey, storm * 0.6)
	_sky.set_shader_parameter("top_color", top)
	_sky.set_shader_parameter("horizon_color", horizon)
	_sky.set_shader_parameter("ground_color", Color(0.3, 0.4, 0.25) * lerpf(0.2, 1.0, day))
	_sky.set_shader_parameter("sun_color", Color(1.0, 0.85, 0.6).lerp(Color(1.0, 0.5, 0.25), glow))
	_sky.set_shader_parameter("sun_dir", to_sun)
	_sky.set_shader_parameter("moon_dir", to_moon)
	_sky.set_shader_parameter("night", night)
	_sky.set_shader_parameter("glow", glow)
	_sky.set_shader_parameter("cover", cover)
	_sky.set_shader_parameter("storm", storm)
	_sky.set_shader_parameter("rainbow", rainbow)

	# Fog and the light that fills the shadows. Nights stay light enough to
	# ride in, with a blue moonlit tint.
	_env.fog_light_color = horizon.lerp(Color(0.78, 0.85, 0.94), day * 0.5 * (1.0 - glow))
	_env.fog_density = 0.0016 + storm * 0.006
	_env.ambient_light_color = Color(0.45, 0.53, 0.82).lerp(Color(1, 1, 1), day)
	_env.ambient_light_sky_contribution = lerpf(0.2, 0.8, day)
	_env.ambient_light_energy = lerpf(1.2, 1.0, day)
	_env.adjustment_saturation = lerpf(0.6, 1.1, day) * (1.0 - storm * 0.15)

	_rain.amount_ratio = clampf(rain * (1.0 - snow_zone), 0.0, 1.0)
	_rain.emitting = rain > 0.02 and snow_zone < 0.6
	_fireflies.emitting = night > 0.5 and rain < 0.2 and snow_zone < 0.3
	_moonlight.light_energy = night * 1.6
	_moonlight.visible = night > 0.01


func _rain_particles() -> GPUParticles3D:
	var drops := GPUParticles3D.new()
	drops.name = "Rain"
	drops.amount = 700 if OS.has_feature("mobile") else 1800
	drops.lifetime = 1.0
	drops.local_coords = false
	drops.emitting = false
	drops.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 30, 60))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(22, 2, 22)
	process.direction = Vector3(0.05, -1, 0.02)
	process.spread = 2.0
	process.initial_velocity_min = 16.0
	process.initial_velocity_max = 19.0
	process.gravity = Vector3(0, -4, 0)
	drops.process_material = process
	var streak := QuadMesh.new()
	streak.size = Vector2(0.018, 0.55)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	mat.albedo_color = Color(0.78, 0.84, 0.95, 0.4)
	streak.material = mat
	drops.draw_pass_1 = streak
	drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return drops


## Little glowing fireflies drifting over the grass at night.
func _firefly_particles() -> GPUParticles3D:
	var flies := GPUParticles3D.new()
	flies.name = "Fireflies"
	flies.amount = 90
	flies.lifetime = 5.0
	flies.local_coords = false
	flies.emitting = false
	flies.visibility_aabb = AABB(Vector3(-25, -5, -25), Vector3(50, 12, 50))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(16, 0.8, 16)
	process.gravity = Vector3.ZERO
	process.spread = 180.0
	process.initial_velocity_min = 0.1
	process.initial_velocity_max = 0.4
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.8
	var blink := Gradient.new()
	blink.set_color(0, Color(1, 1, 1, 0))
	blink.add_point(0.3, Color(1, 1, 1, 1))
	blink.add_point(0.5, Color(1, 1, 1, 0.2))
	blink.add_point(0.7, Color(1, 1, 1, 1))
	blink.set_color(blink.get_point_count() - 1, Color(1, 1, 1, 0))
	var blink_texture := GradientTexture1D.new()
	blink_texture.gradient = blink
	process.color_ramp = blink_texture
	flies.process_material = process
	var dot := SphereMesh.new()
	dot.radius = 0.035
	dot.height = 0.07
	dot.radial_segments = 6
	dot.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(3.0, 2.85, 1.35)
	dot.material = mat
	flies.draw_pass_1 = dot
	flies.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return flies
