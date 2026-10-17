extends Node3D
## The player's rider, put together from the character parts in assets/rider
## (Quaternius' modular characters): an outfit, a head and a hairstyle on one
## shared skeleton, with skin, hair and helmet colours of the player's choice.
## The model faces +Z; set_pose() switches between standing and riding.

const DIR := "res://assets/rider/"

const BODIES := [
	{"name": "Girl", "prefix": "Female"},
	{"name": "Boy", "prefix": "Male"},
]
const HAIRSTYLES := [
	{"name": "Long", "file": "Hair_Long"},
	{"name": "Buns", "file": "Hair_Buns"},
	{"name": "Short", "file": "Hair_SimpleParted"},
	{"name": "Cropped", "file": "Hair_BuzzedFemale"},
	{"name": "Buzzed", "file": "Hair_Buzzed"},
	{"name": "Beard", "file": "Hair_Beard"},
]
const SKIN_TONES := [
	{"name": "Fair",   "color": Color(1.12, 1.08, 1.08)},
	{"name": "Light",  "color": Color(1.0, 0.95, 0.92)},
	{"name": "Tan",    "color": Color(0.82, 0.7, 0.62)},
	{"name": "Brown",  "color": Color(0.58, 0.44, 0.36)},
	{"name": "Dark",   "color": Color(0.36, 0.26, 0.22)},
]
const HAIR_COLORS := [
	{"name": "Blonde", "color": Color(0.95, 0.78, 0.45)},
	{"name": "Brown",  "color": Color(0.42, 0.26, 0.15)},
	{"name": "Black",  "color": Color(0.09, 0.08, 0.08)},
	{"name": "Red",    "color": Color(0.78, 0.32, 0.12)},
	{"name": "Pink",   "color": Color(1.0, 0.55, 0.75)},
	{"name": "Lilac",  "color": Color(0.7, 0.55, 0.95)},
]
const OUTFITS := [
	{"name": "Green jacket", "file": "Ranger",  "texture": "T_Ranger_BaseColor"},
	{"name": "Cream jacket", "file": "Ranger",  "texture": "T_Ranger_3_BaseColor"},
	{"name": "Brown tunic",  "file": "Peasant", "texture": "T_Peasant_BaseColor"},
	{"name": "Green tunic",  "file": "Peasant", "texture": "T_Peasant_2_BaseColor"},
]
const HELMETS := [
	{"name": "No helmet", "color": Color.TRANSPARENT},
	{"name": "Black",     "color": Color(0.06, 0.06, 0.08)},
	{"name": "Navy",      "color": Color(0.1, 0.14, 0.32)},
	{"name": "Pink",      "color": Color(0.95, 0.45, 0.65)},
	{"name": "Purple",    "color": Color(0.45, 0.25, 0.7)},
	{"name": "White",     "color": Color(0.92, 0.92, 0.9)},
]

## Each option the player can change, and the list it picks from.
const OPTIONS := {
	"body": BODIES, "skin": SKIN_TONES, "hair": HAIRSTYLES,
	"hair_color": HAIR_COLORS, "outfit": OUTFITS, "helmet": HELMETS,
}
const DEFAULT := {"body": 0, "skin": 1, "hair": 0, "hair_color": 1, "outfit": 0, "helmet": 1}

## Poses as rotations of bones in the model's own space (degrees, applied
## X then Y then Z on top of the bone's rest rotation). Children follow
## their parents, so a calf turns on top of its thigh. +X is the rider's
## left, +Z forward.
const POSES := {
	"stand": {
		"upperarm_l": Vector3(0, 0, -75), "upperarm_r": Vector3(0, 0, 75),
		"lowerarm_l": Vector3(-10, 0, 0), "lowerarm_r": Vector3(-10, 0, 0),
	},
	"ride": {
		"spine_01": Vector3(8, 0, 0),
		"thigh_l": Vector3(-70, 32, 0), "thigh_r": Vector3(-70, -32, 0),
		"calf_l": Vector3(85, 0, 0), "calf_r": Vector3(85, 0, 0),
		"foot_l": Vector3(-20, 0, 0), "foot_r": Vector3(-20, 0, 0),
		"upperarm_l": Vector3(-25, 0, -72), "upperarm_r": Vector3(-25, 0, 72),
		"lowerarm_l": Vector3(-60, 0, 0), "lowerarm_r": Vector3(-60, 0, 0),
	},
}
## Height of the hips above the feet in the model's rest pose.
const HIP_HEIGHT := 0.93

var config: Dictionary = DEFAULT.duplicate()
var skeleton: Skeleton3D
var _model: Node3D
var _pose := "stand"


## Rebuild the rider from a config (missing keys keep their defaults).
func build(new_config: Dictionary) -> void:
	config = DEFAULT.duplicate()
	for key in new_config:
		if OPTIONS.has(key):
			config[key] = clampi(new_config[key], 0, OPTIONS[key].size() - 1)
	if _model:
		_model.queue_free()
		remove_child(_model)

	var prefix: String = BODIES[config.body].prefix
	var outfit: Dictionary = OUTFITS[config.outfit]
	_model = _instance("%s_%s" % [prefix, outfit.file])
	add_child(_model)
	skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	for mi in _meshes(_model):
		# The ranger's hood would cover the hair and helmet.
		if mi.name.ends_with("Head_Hood"):
			mi.queue_free()
	_attach("Head_" + prefix)
	_attach(HAIRSTYLES[config.hair].file)

	var outfit_texture := load(DIR + "textures/%s.png" % outfit.texture) as Texture2D
	for mi in _meshes(_model):
		for i in mi.mesh.get_surface_count():
			var material := mi.mesh.surface_get_material(i) as BaseMaterial3D
			var tinted := material.duplicate() as BaseMaterial3D
			var kind := material.resource_name
			if kind.begins_with("MI_Hair"):
				tinted.albedo_color = HAIR_COLORS[config.hair_color].color
			elif kind.begins_with("MI_Regular") or kind.begins_with("MI_Superhero"):
				tinted.albedo_color = SKIN_TONES[config.skin].color
			elif kind == "MI_Ranger" or kind == "MI_Peasant":
				tinted.albedo_texture = outfit_texture
			mi.set_surface_override_material(i, tinted)

	if HELMETS[config.helmet].color.a > 0.0:
		_build_helmet(HELMETS[config.helmet].color)
	set_pose(_pose)


func set_pose(pose: String) -> void:
	_pose = pose
	if not skeleton:
		return
	var rotations: Dictionary = POSES[pose]
	var globals: Array[Basis] = []
	globals.resize(skeleton.get_bone_count())
	# Bones are listed parents first, so each parent is done before its children.
	for bone in skeleton.get_bone_count():
		var parent := skeleton.get_bone_parent(bone)
		var parent_basis := globals[parent] if parent >= 0 else Basis()
		var basis := parent_basis * skeleton.get_bone_rest(bone).basis
		var euler: Vector3 = rotations.get(skeleton.get_bone_name(bone), Vector3.ZERO)
		if euler != Vector3.ZERO:
			basis = Basis.from_euler(euler * PI / 180.0, EULER_ORDER_XYZ) * basis
		globals[bone] = basis
		skeleton.set_bone_pose_rotation(bone, (parent_basis.inverse() * basis).get_rotation_quaternion())


func _instance(file: String) -> Node3D:
	return (load(DIR + file + ".gltf") as PackedScene).instantiate() as Node3D


## Move a part's meshes (a head or hairstyle, rigged to the same skeleton)
## onto the outfit's skeleton.
func _attach(file: String) -> void:
	var part := _instance(file)
	for mi in _meshes(part):
		mi.get_parent().remove_child(mi)
		mi.owner = null
		skeleton.add_child(mi)
		mi.skeleton = NodePath("..")
	part.free()


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var list: Array[MeshInstance3D] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		list.append(node)
	return list


## A velvet riding helmet with a short peak, made from simple shapes.
func _build_helmet(color: Color) -> void:
	var attach := BoneAttachment3D.new()
	attach.bone_name = "Head"
	skeleton.add_child(attach)
	var velvet := StandardMaterial3D.new()
	velvet.albedo_color = color
	velvet.roughness = 0.55
	velvet.rim_enabled = true
	velvet.rim = 0.4
	var shell := SphereMesh.new()
	shell.radius = 0.14
	shell.height = 0.14
	shell.is_hemisphere = true
	var dome := MeshInstance3D.new()
	dome.mesh = shell
	dome.material_override = velvet
	dome.position = Vector3(0, 0.14, -0.02)
	dome.scale = Vector3(0.95, 1.0, 1.1)
	attach.add_child(dome)
	var peak := CylinderMesh.new()
	peak.top_radius = 0.075
	peak.bottom_radius = 0.075
	peak.height = 0.012
	var brim := MeshInstance3D.new()
	brim.mesh = peak
	brim.material_override = velvet
	brim.position = Vector3(0, 0.15, 0.1)
	brim.rotation.x = 0.25
	brim.scale = Vector3(1.0, 1.0, 0.55)
	attach.add_child(brim)
