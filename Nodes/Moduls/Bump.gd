# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name BumpModule
extends ShaderModule

func _init() -> void:
	super._init()
	module_name = "Bump"
	
	_input_sockets = [
		InputSocket.new("Strength", InputSocket.SocketType.FLOAT, 1.0),
		InputSocket.new("Distance", InputSocket.SocketType.FLOAT, 1.0),
		InputSocket.new("Filter_width", InputSocket.SocketType.FLOAT, 0.1),
		InputSocket.new("Height", InputSocket.SocketType.FLOAT, 1.0),
		InputSocket.new("Normal", InputSocket.SocketType.VEC3, Vector3.ZERO),
	]
	_output_sockets = [
		OutputSocket.new("Normal", OutputSocket.SocketType.VEC3),
	]
	
	for socket in _output_sockets:
		socket.set_parent_module(self)

func get_include_files() -> Array[String]:
	return [PATHS.INC["BLENDER_COORDS"], PATHS.INC["BUMP"]]

func get_input_sockets() -> Array[InputSocket]:
	return _input_sockets

func get_output_sockets() -> Array[OutputSocket]:
	return _output_sockets

func get_uniform_definitions() -> Dictionary:
	var uniforms = {}

	# Флаг инверсии (чекбокс)
	uniforms["invert"] = {"type": "bool", "default": false}

	# Параметры из input-сокетов с хинтами
	for s in get_input_sockets():
		if s.source:
			continue
		var u = s.to_uniform()
		match s.name:
			"Strength":
				u["hint"] = "hint_range(0,1)"
			"Distance":
				u["hint"] = "hint_range(0,1000)"
			"Filter_width":
				u["hint"] = "hint_range(0,10)"
			_:
				pass
		uniforms[s.name.to_lower()] = u
	return uniforms

func get_code_blocks() -> Dictionary:
	update_active_sockets()
	var outputs = get_output_vars()
	var inputs  = _get_input_args()
	var idx_strength := 0
	var idx_dist := 1
	var idx_filter := 2
	var idx_height := 3
	var idx_normal := 4
	
	var n_expr: String
	var blocks := {}
	
	if _input_sockets[idx_normal].source == null:
		var global_decl_normal := "varying vec3 v_nrm_world_%s;" % unique_id
		var global_decl_vert := "varying vec3 v_vert_%s;" % unique_id

		var vertex_code := """
 // {module}: {uid} (VERTEX)

v_nrm_world_{uid} = NORMAL * ROT_MATRIX_Y_TO_Z;
v_vert_{uid} = VERTEX.xzy;

""".format({"module": module_name, "uid": unique_id}).strip_edges()
		blocks["global_nrm_%s" % unique_id] = {"stage":"global", "code": global_decl_normal}
		blocks["global_vert_%s" % unique_id] = {"stage":"global", "code": global_decl_vert}
		blocks["vertex_%s" % unique_id] = {"stage":"vertex", "code": vertex_code}
		n_expr = "v_nrm_world_%s" % unique_id
	else:
		n_expr = inputs[idx_normal]
	

	var frag_template = """


 // {module}: {uid} (FRAG)
float height_val = {height};
vec3 df = differentiate_texco(vec3(height_val));
vec2 height_xy = df.xy;
float pixel = max(1e-4, length(dFdx(SCREEN_UV)) + length(dFdy(SCREEN_UV)));
float fw = {filter_width} / pixel / 100.0; 
vec3 {out_var} = node_bump(
		{strength},
		{dist},
		fw,
		height_val,
		{normal_expr},
		height_xy,
		({invert} ? -1.0 : 1.0),
		FRONT_FACING,
		v_vert_{uid});
{out_var} = {out_var} * ROT_MATRIX_Z_TO_Y;
//{out_var} = normalize( (VIEW_MATRIX * vec4({out_var}, 0.0)).xyz);

 """.strip_edges()
	
	var frag_code = frag_template.format({
		"module": module_name,
		"uid": unique_id,
		"strength": inputs[idx_strength],
		"dist": inputs[idx_dist],
		"filter_width": inputs[idx_filter],
		"height": inputs[idx_height],
		"normal_expr": n_expr,
		"out_var": outputs["Normal"],
		"invert": _get_prefixed_name("invert"),
	})
	
	blocks["fragment_%s" % unique_id] = {"stage":"fragment", "code": frag_code}
	
	return blocks


func get_render_modes() -> Array[String]:
	return ["world_vertex_coords"]
