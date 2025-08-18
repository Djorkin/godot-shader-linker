# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name OutputModule
extends ShaderModule

func _init() -> void:
	super._init()
	module_name = "Material Output"
	
	input_sockets = [
		InputSocket.new("Surface", InputSocket.SocketType.SHADER)
	]

func get_include_files() -> Array[String]:
	return [PATHS.INC["MATERIAL"], PATHS.INC["MATERIAL_OUT"]]

func get_uniform_definitions() -> Dictionary:
	var uniforms = {}
	for socket in get_input_sockets():
		if socket.type == InputSocket.SocketType.SHADER:
			continue
		if not socket.source:
			uniforms[socket.name.to_lower()] = socket.to_uniform()
	return uniforms

func get_input_sockets() -> Array[InputSocket]: 
	return input_sockets

func get_code_blocks() -> Dictionary:
	var inputs = get_input_args()
	var has_surface: bool = input_sockets[0].source != null
	var surf_expr := ""
	if has_surface:
		surf_expr = inputs[0]
	var uid = unique_id
	var code : String

	if has_surface:
		code = """
// {module}: {uid}
Material mat_{uid} = {surf};
ALBEDO   = mat_{uid}.albedo;
ROUGHNESS = mat_{uid}.roughness;
METALLIC = mat_{uid}.metallic;
#ifdef ALPHA_TRANSFER
	ALPHA = mat_{uid}.alpha;
#endif
NORMAL = mat_{uid}.normal;
SPECULAR = mat_{uid}.specular_level;
EMISSION = mat_{uid}.emission;
CLEARCOAT = mat_{uid}.coat_weight;
CLEARCOAT_ROUGHNESS = mat_{uid}.coat_roughness;
""".format({"module": module_name, "uid": uid, "surf": surf_expr})
	else:
		code = """
// {module}: {uid}
Material mat_{uid};
mat_{uid}.albedo = vec3(0.0);
mat_{uid}.metallic = 0.0;
mat_{uid}.roughness = 0.5;
mat_{uid}.alpha = 1.0;
mat_{uid}.normal = NORMAL;
mat_{uid}.specular_level = 0.0;
mat_{uid}.emission = vec3(0.0);
mat_{uid}.coat_weight = 0.0;
mat_{uid}.coat_roughness = 0.0;

ALBEDO   = mat_{uid}.albedo;
ROUGHNESS = mat_{uid}.roughness;
METALLIC  = mat_{uid}.metallic;
#ifdef ALPHA_TRANSFER
	ALPHA     = mat_{uid}.alpha;
#endif
NORMAL    = mat_{uid}.normal;
SPECULAR  = mat_{uid}.specular_level;
EMISSION  = mat_{uid}.emission;
CLEARCOAT = mat_{uid}.coat_weight;
CLEARCOAT_ROUGHNESS = mat_{uid}.coat_roughness;
""".format({"module": module_name, "uid": uid})

	return {
		"fragment_%s" % uid : {"stage":"fragment", "code": code}
	}

func get_render_modes() -> Array[String]:
	return ["depth_draw_always", "blend_mix", "depth_prepass_alpha"]