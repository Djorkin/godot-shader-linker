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
		var global_decl_vert := "varying vec3 v_pos_world_%s;" % unique_id

		var vertex_code := """
// {module}: {uid} (VERTEX)

TransformCtx ctx_{uid} = make_ctx(MODEL_MATRIX, MODEL_NORMAL_MATRIX,
									 VIEW_MATRIX, INV_VIEW_MATRIX,
									 PROJECTION_MATRIX, INV_PROJECTION_MATRIX);
v_pos_world_{uid} = obj_to_world_pos_ctx(VERTEX, ctx_{uid});
v_nrm_world_{uid} = obj_to_world_normal_ctx(NORMAL, ctx_{uid});

	""".format({"module": module_name, "uid": unique_id}).strip_edges()
		blocks["global_nrm_%s" % unique_id] = {"stage":"global", "code": global_decl_normal}
		blocks["global_vert_%s" % unique_id] = {"stage":"global", "code": global_decl_vert}
		blocks["vertex_%s" % unique_id] = {"stage":"vertex", "code": vertex_code}
		n_expr = "v_nrm_world_%s" % unique_id
	else:
		# Всегда требуется позиция в мировом пространстве для node_bump
		var global_decl_vert := "varying vec3 v_pos_world_%s;" % unique_id
		var vertex_code := """


// {module}: {uid} (VERTEX)

TransformCtx ctx_{uid} = make_ctx(MODEL_MATRIX, MODEL_NORMAL_MATRIX,
									 VIEW_MATRIX, INV_VIEW_MATRIX,
									 PROJECTION_MATRIX, INV_PROJECTION_MATRIX);
v_pos_world_{uid} = obj_to_world_pos_ctx(VERTEX, ctx_{uid});

	""".format({"module": module_name, "uid": unique_id}).strip_edges()
		blocks["global_vert_%s" % unique_id] = {"stage":"global", "code": global_decl_vert}
		blocks["vertex_%s" % unique_id] = {"stage":"vertex", "code": vertex_code}
		n_expr = inputs[idx_normal]
	

	var frag_template = """


 // {module}: {uid} (FRAG)
 TransformCtx ctx_{uid} = make_ctx(MODEL_MATRIX, MODEL_NORMAL_MATRIX,
                                 VIEW_MATRIX, INV_VIEW_MATRIX,
                                 PROJECTION_MATRIX, INV_PROJECTION_MATRIX);
 vec2 dHd_{uid} = vec2(dFdx({height}), dFdy({height}));
 float fw_{uid} = max({filter_width}, 0.001);
vec3 tmpN_{uid} = node_bump(
		{strength},
		{dist},
		fw_{uid},
		{normal_expr},
		dHd_{uid},
		({invert} ? -1.0 : 1.0),
		FRONT_FACING,
		v_pos_world_{uid});

vec3 {out_var} = world_to_view_normal_ctx(tmpN_{uid}, ctx_{uid});

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


