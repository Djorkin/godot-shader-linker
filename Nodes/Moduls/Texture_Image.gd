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

	_input_sockets = [
		InputSocket.new("Vector", InputSocket.SocketType.VEC3, Vector3.ZERO)
	]

	_output_sockets = [
		OutputSocket.new("Color", OutputSocket.SocketType.VEC4),
		OutputSocket.new("Alpha", OutputSocket.SocketType.FLOAT)
	]

	for socket in _output_sockets:
		socket.set_parent_module(self)

func get_include_files() -> Array[String]:
	return [PATHS.INC["BLENDER_COORDS"], PATHS.INC["STRUCT_TEX_IMG"], PATHS.INC["TEX_IMAGE"],]

func get_input_sockets() -> Array[InputSocket]:
	return _input_sockets

func get_output_sockets() -> Array[OutputSocket]:
	return _output_sockets

func get_uniform_definitions() -> Dictionary:
	return {
		"image_texture": {"type":"sampler2D"},
		"interpolation": {"type":"int", "default":interpolation, "hint":"hint_enum(\"Linear\",\"Closest\",\"Cubic\")"},
		"projection": {"type":"int", "default":projection, "hint":"hint_enum(\"Flat\",\"Box\",\"Sphere\",\"Tube\")"},
		"box_blend": {"type":"float", "default":box_blend, "hint":"hint_range(0,1,0.01)"},
		"extension": {"type":"int", "default":extension, "hint":"hint_enum(\"Repeat\",\"Extend\",\"Clip\",\"Mirror\")"},
		"color_space": {"type":"int", "default":color_space, "hint":"hint_enum(\"sRGB\",\"Non-Color\")"},
		"alpha_mode": {"type":"int", "default":alpha_mode, "hint":"hint_enum(\"Straight\",\"Premultiplied\",\"ChannelPacked\",\"None\")"},
	}

func get_code_blocks() -> Dictionary:
	var outputs = get_output_vars()
	var inputs = _get_input_args()

	# Shared varyings: запрашиваем мировую нормаль один раз на шейдер
	var sv = SharedVaryings.request(["world_normal"]) 
	var sv_world_normal: String = sv.get("world_normal", SharedVaryings.get_var_name("world_normal"))

	var coord_expr: String = inputs[0]
	if _input_sockets[0].source == null:
		coord_expr = "vec3(UV, 0.0)"

	var args = {
		"uid": unique_id,
		"module": module_name,
		"coord": coord_expr,
		"color": outputs["Color"],
		"alpha": outputs["Alpha"],
		"sv_n": sv_world_normal
	}

	var frag_code := """
// {module}: {uid} (FRAG)
Tex_img_params params_{uid};
params_{uid}.interpolation  = u_{uid}_interpolation;
params_{uid}.projection     = u_{uid}_projection;
params_{uid}.box_blend      = u_{uid}_box_blend;
params_{uid}.extension      = u_{uid}_extension;
params_{uid}.color_space    = u_{uid}_color_space;
params_{uid}.alpha_mode     = u_{uid}_alpha_mode;

vec4 tex_{uid} = _sample_image(vec3(flip_uv({coord}.xy), {coord}.z), 
								{sv_n},
								u_{uid}_image_texture,
								params_{uid});

vec4 {color} = tex_{uid};

"""

	var blocks: Dictionary = {}
	# Глобальные объявления shared varyings (добавятся один раз)
	var sv_decls = SharedVaryings.build_global_declarations()
	if sv_decls != "":
		blocks["shared_varyings_decls"] = {"stage":"global", "code": sv_decls}
	# Vertex-код для shared varyings (добавится один раз)
	var sv_vertex = SharedVaryings.build_vertex_code()
	if sv_vertex != "":
		blocks["shared_varyings_vertex"] = {"stage":"vertex", "code": sv_vertex}

	blocks["fragment_%s" % unique_id] = {"stage":"fragment", "code": generate_code_block("fragment", frag_code, args)}
	return blocks


