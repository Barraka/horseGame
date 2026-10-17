extends GPUParticles3D
## Soft glowing motes drifting in the air around the player, for a
## dreamy fairy-tale feel. Follows the target so they are always nearby.

@export var target_path: NodePath

var _target: Node3D


func _ready() -> void:
	_target = get_node(target_path)
	amount = 160
	lifetime = 6.0
	preprocess = 6.0
	local_coords = false
	visibility_aabb = AABB(Vector3(-25, -5, -25), Vector3(50, 15, 50))

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(18, 2.5, 18)
	process.gravity = Vector3(0, 0.08, 0)
	process.direction = Vector3(0, 1, 0)
	process.spread = 180.0
	process.initial_velocity_min = 0.05
	process.initial_velocity_max = 0.25
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.4
	process.turbulence_noise_scale = 4.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	process.color_ramp = fade_texture
	process_material = process

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.0, 0.95, 0.75)
	mat.albedo_texture = _dot_texture()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	quad.material = mat
	draw_pass_1 = quad


func _process(_delta: float) -> void:
	global_position = _target.global_position + Vector3.UP * 1.5


## A small round glow: bright centre fading to transparent.
func _dot_texture() -> GradientTexture2D:
	var glow := Gradient.new()
	glow.set_color(0, Color(1, 1, 1, 1))
	glow.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = glow
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 32
	tex.height = 32
	return tex
