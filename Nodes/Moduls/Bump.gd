# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name BumpModule
extends ShaderModule

func _init() -> void:
	super._init()
	module_name = "Bump"
	
	input_sockets = [
		InputSocket.new("Strength", InputSocket.SocketType.FLOAT, 1.0),
		InputSocket.new("Distance", InputSocket.SocketType.FLOAT, 0.001),
		InputSocket.new("Filter_width", InputSocket.SocketType.FLOAT, 0.1),
		InputSocket.new("Height", InputSocket.SocketType.FLOAT, 1.0),
		InputSocket.new("Normal", InputSocket.SocketType.VEC3, Vector3.ZERO),
	]
	output_sockets = [
		OutputSocket.new("Normal", OutputSocket.SocketType.VEC3),
	]
	
	for socket in output_sockets:
		socket.set_parent_module(self)

func get_include_files() -> Array[String]:
	return [PATHS.INC["COORDS"], PATHS.INC["BUMP"]]

func get_uniform_definitions() -> Dictionary:
	var u = {}

	u["invert"] = [ShaderSpec.ShaderType.BOOL, false]

	for s in get_input_sockets():
		if s.source:
			continue
		var t
		match s.type:
			InputSocket.SocketType.FLOAT:
				t = ShaderSpec.ShaderType.FLOAT
			InputSocket.SocketType.VEC3:
				t = ShaderSpec.ShaderType.VEC3
			InputSocket.SocketType.VEC4:
				t = ShaderSpec.ShaderType.VEC4
			_:
				t = ShaderSpec.ShaderType.FLOAT

		var key = s.name.to_lower()
		var spec = [t, s.default]
		match s.name:
			"Strength":
				spec = [ShaderSpec.ShaderType.FLOAT, s.default, ShaderSpec.UniformHint.RANGE, {"min":0, "max":1, "step":0.01}]
			"Distance":
				spec = [ShaderSpec.ShaderType.FLOAT, s.default, ShaderSpec.UniformHint.RANGE, {"min":0, "max":1000, "step":0.001}]
			"Filter_width":
				spec = [ShaderSpec.ShaderType.FLOAT, s.default, ShaderSpec.UniformHint.RANGE, {"min":0, "max":10, "step":0.001}]
			_:
				pass
		u[key] = spec
	return u

func get_required_shared_varyings() -> Array[int]:
	var idx_normal := 4
	var req: Array[int] = []
	req.append(ShaderSpec.SharedVar.WORLD_POS)
	if input_sockets[idx_normal].source == null:
		req.append(ShaderSpec.SharedVar.WORLD_NORMAL)
	return req

func get_code_blocks() -> Dictionary:
	var outputs = get_output_vars()
	var inputs  = get_input_args()
	var idx_strength := 0
	var idx_dist := 1
	var idx_filter := 2
	var idx_height := 3
	var idx_normal := 4

	var n_expr: String
	if input_sockets[idx_normal].source == null:
		n_expr = ShaderSpec.shared_var_name(ShaderSpec.SharedVar.WORLD_NORMAL)
	else:
		n_expr = inputs[idx_normal]

	var n_expr_world: String
	if input_sockets[idx_normal].source == null:
		n_expr_world = n_expr
	else:
		n_expr_world = "view_to_world_normal_ctx(%s, svCtx)" % [n_expr]

	var world_pos_name := ShaderSpec.shared_var_name(ShaderSpec.SharedVar.WORLD_POS)

	var blocks := {}

	# If Height is connected, use eval path; otherwise, avoid calling eval and fallback to constant height
	if input_sockets[idx_height].source != null:
		# Build init and smear code segments based on detected sources (from Collector via meta)
		var gen_src := ""
		if has_meta("eval_src_generated"):
			gen_src = str(get_meta("eval_src_generated"))
		var obj_src := ""
		if has_meta("eval_src_object"):
			obj_src = str(get_meta("eval_src_object"))
		var cam_src := ""
		if has_meta("eval_src_camera"):
			cam_src = str(get_meta("eval_src_camera"))
		var scr_src := ""
		if has_meta("eval_src_screen_uv"):
			scr_src = str(get_meta("eval_src_screen_uv"))

		var init_ctx := """
		EvalCtx ctx0_{uid};
		ctx0_{uid}.uv = UV;
		ctx0_{uid}.world_pos = {world_pos};
		ctx0_{uid}.world_normal = {normal_expr_world};
		""".strip_edges()

		if gen_src != "":
			init_ctx += "\nctx0_%s.generated = %s;" % [unique_id, gen_src]
		if obj_src != "":
			init_ctx += "\nctx0_%s.object = %s;" % [unique_id, obj_src]
		if cam_src != "":
			init_ctx += "\nctx0_%s.camera = %s;" % [unique_id, cam_src]
		if scr_src != "":
			init_ctx += "\nctx0_%s.screen_uv = %s;" % [unique_id, scr_src]

		init_ctx = init_ctx.format({
			"uid": unique_id,
			"world_pos": world_pos_name,
			"normal_expr_world": n_expr_world,
		})

		var smear_x := """
		EvalCtx ctxx_{uid} = ctx0_{uid};
		ctxx_{uid}.uv += dFdx(ctx0_{uid}.uv) * fw_{uid};
		""".strip_edges()
		if gen_src != "":
			smear_x += "\nctxx_%s.generated += dFdx(ctx0_%s.generated) * fw_%s;" % [unique_id, unique_id, unique_id]
		if obj_src != "":
			smear_x += "\nctxx_%s.object += dFdx(ctx0_%s.object) * fw_%s;" % [unique_id, unique_id, unique_id]
		if cam_src != "":
			smear_x += "\nctxx_%s.camera += dFdx(ctx0_%s.camera) * fw_%s;" % [unique_id, unique_id, unique_id]
		if scr_src != "":
			smear_x += "\nctxx_%s.screen_uv += dFdx(ctx0_%s.screen_uv) * fw_%s;" % [unique_id, unique_id, unique_id]
		smear_x = smear_x.format({"uid": unique_id})

		var smear_y := """
		EvalCtx ctxy_{uid} = ctx0_{uid};
		ctxy_{uid}.uv += dFdy(ctx0_{uid}.uv) * fw_{uid};
		""".strip_edges()
		if gen_src != "":
			smear_y += "\nctxy_%s.generated += dFdy(ctx0_%s.generated) * fw_%s;" % [unique_id, unique_id, unique_id]
		if obj_src != "":
			smear_y += "\nctxy_%s.object += dFdy(ctx0_%s.object) * fw_%s;" % [unique_id, unique_id, unique_id]
		if cam_src != "":
			smear_y += "\nctxy_%s.camera += dFdy(ctx0_%s.camera) * fw_%s;" % [unique_id, unique_id, unique_id]
		if scr_src != "":
			smear_y += "\nctxy_%s.screen_uv += dFdy(ctx0_%s.screen_uv) * fw_%s;" % [unique_id, unique_id, unique_id]
		smear_y = smear_y.format({"uid": unique_id})

		var eval_template := """

// {module}: {uid} (FRAG)
float fw_{uid} = max({filter_width}, 0.001);

{init_ctx}

{smear_x}

{smear_y}

float h_{uid} = {eval_fn}(ctx0_{uid}, svCtx);
vec2 hxy_{uid} = vec2(
	{eval_fn}(ctxx_{uid}, svCtx),
	{eval_fn}(ctxy_{uid}, svCtx)
);

vec3 tmpN_{uid} = node_bump(
	{strength},
	{dist} * 10.0,
	fw_{uid},
	h_{uid},
	{normal_expr_world},
	hxy_{uid},
	({invert} ? -1.0 : 1.0),
	FRONT_FACING,
	{world_pos});

vec3 {out_var} = world_to_view_normal_ctx(tmpN_{uid}, svCtx);

""".strip_edges()

		var frag_code: String = eval_template.format({
			"module": module_name,
			"uid": unique_id,
			"strength": inputs[idx_strength],
			"dist": inputs[idx_dist],
			"filter_width": inputs[idx_filter],
			"normal_expr_world": n_expr_world,
			"out_var": outputs["Normal"],
			"invert": get_prefixed_name("invert"),
			"world_pos": world_pos_name,
			"eval_fn": "eval_height_%s" % unique_id,
			"init_ctx": init_ctx,
			"smear_x": smear_x,
			"smear_y": smear_y,
			})
		blocks["fragment_%s" % unique_id] = {"stage":"fragment", "code": frag_code}
	else:
		# Fallback: constant height, zero gradient, no eval() calls
		var fallback_template := """

			// {module}: {uid} (FRAG)
		float fw_{uid} = max({filter_width}, 0.001);
		float h_{uid} = {height_expr};
		vec2 hxy_{uid} = vec2(h_{uid}, h_{uid});
		vec3 tmpN_{uid} = node_bump(
				{strength},
				{dist} * 100.0,
				fw_{uid},
				h_{uid},
				{normal_expr_world},
				hxy_{uid},
				({invert} ? -1.0 : 1.0),
				FRONT_FACING,
				{world_pos});
		vec3 {out_var} = world_to_view_normal_ctx(tmpN_{uid}, svCtx);
		""".strip_edges()

		var fallback_code := fallback_template.format({
			"module": module_name,
			"uid": unique_id,
			"strength": inputs[idx_strength],
			"dist": inputs[idx_dist],
			"filter_width": inputs[idx_filter],
			"normal_expr_world": n_expr_world,
			"out_var": outputs["Normal"],
			"invert": get_prefixed_name("invert"),
			"world_pos": world_pos_name,
			"height_expr": inputs[idx_height],
		})
		blocks["fragment_%s" % unique_id] = {"stage":"fragment", "code": fallback_code}
	
	return blocks
