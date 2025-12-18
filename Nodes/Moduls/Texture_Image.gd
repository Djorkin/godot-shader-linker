# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name TextureImageModule
extends ShaderModule

enum InterpolationType { LINEAR, CLOSEST, CUBIC }
enum ProjectionType { FLAT, BOX, SPHERE, TUBE }
enum ExtensionType { REPEAT, EXTEND, CLIP, MIRROR }
enum ColorSpaceType { SRGB, NON_COLOR }
enum AlphaModeType { STRAIGHT, PREMULTIPLIED, CHANNEL_PACKED, NONE }

@export_enum("Linear", "Closest", "Cubic") var interpolation: int = InterpolationType.LINEAR
@export_enum("Flat", "Box", "Sphere", "Tube") var projection: int = ProjectionType.FLAT
@export_range(0, 1, 0.01) var box_blend: float = 0.0
@export_enum("Repeat", "Extend", "Clip", "Mirror") var extension: int = ExtensionType.REPEAT
@export_enum("sRGB", "Non-Color") var color_space: int = ColorSpaceType.SRGB
@export_enum("Straight", "Premultiplied", "ChannelPacked", "None") var alpha_mode: int = AlphaModeType.STRAIGHT

func _init() -> void:
	super._init()
	module_name = "Texture Image"

	input_sockets = [
		InputSocket.new("Vector", InputSocket.SocketType.VEC3, Vector3.ZERO)
	]

	output_sockets = [
		OutputSocket.new("Color", OutputSocket.SocketType.VEC4),
		OutputSocket.new("Alpha", OutputSocket.SocketType.FLOAT)
	]

	for socket in output_sockets:
		socket.set_parent_module(self)

func get_include_files() -> Array[String]:
	return [
		PATHS.INC["BLENDER_COORDS"], 
		PATHS.INC["COLOR_CONVERSIONS"], 
		PATHS.INC["STRUCT_TEX_IMG"], 
		PATHS.INC["TEX_IMAGE"],
	]

func get_required_shared_varyings() -> Array[int]:
	return [ShaderSpec.SharedVar.OBJECT_NORMAL]

func get_uniform_definitions() -> Dictionary:
	return {
		"image_texture": [ShaderSpec.ShaderType.SAMPLER2D, null],
		"interpolation": [ShaderSpec.ShaderType.INT, interpolation, ShaderSpec.UniformHint.ENUM, ["Linear","Closest","Cubic"]],
		"projection": [ShaderSpec.ShaderType.INT, projection, ShaderSpec.UniformHint.ENUM, ["Flat","Box","Sphere","Tube"]],
		"box_blend": [ShaderSpec.ShaderType.FLOAT, box_blend, ShaderSpec.UniformHint.RANGE, {"min":0, "max":1, "step":0.01}],
		"extension": [ShaderSpec.ShaderType.INT, extension, ShaderSpec.UniformHint.ENUM, ["Repeat","Extend","Clip","Mirror"]],
		"color_space": [ShaderSpec.ShaderType.INT, color_space, ShaderSpec.UniformHint.ENUM, ["sRGB","Non-Color"]],
		"alpha_mode": [ShaderSpec.ShaderType.INT, alpha_mode, ShaderSpec.UniformHint.ENUM, ["Straight","Premultiplied","ChannelPacked","None"]],
	}

func get_code_blocks() -> Dictionary:
	var outputs = get_output_vars()
	var inputs = get_input_args()

	var coord_expr: String = inputs[0]
	if input_sockets[0].source == null:
		coord_expr = "vec3(UV, 0.0)"

	var args = {
		"uid": unique_id,
		"module": module_name,
		"coord": coord_expr,
		"color": outputs["Color"],
		"alpha": outputs["Alpha"],
		"object_normal": ShaderSpec.shared_var_name(ShaderSpec.SharedVar.OBJECT_NORMAL),
	}

	var frag_code := """
// {module}: {uid}
Tex_img_params params_{uid};
params_{uid}.interpolation  = u_{uid}_interpolation;
params_{uid}.projection     = u_{uid}_projection;
params_{uid}.box_blend      = u_{uid}_box_blend;
params_{uid}.extension      = u_{uid}_extension;
params_{uid}.color_space    = u_{uid}_color_space;
params_{uid}.alpha_mode     = u_{uid}_alpha_mode;

vec4 tex_{uid} = _sample_image(vec3({coord}), 
								{object_normal} * ROT_X(-90.0),
								u_{uid}_image_texture,
								params_{uid});

vec4 {color} = tex_{uid};

"""

	return {
		"fragment_%s" % unique_id : {"stage":"fragment", "code": generate_code_block("fragment", frag_code, args)}
	}
