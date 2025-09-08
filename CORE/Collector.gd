# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later
class_name Collector


var SV_inst := SharedVaryings.new()
var requested_vars: Array = []
var registered_modules := {}
var eval_ctx_declared := false


func get_all_input_sockets() -> Array[InputSocket]:
	var sockets: Array[InputSocket] = []
	for module in registered_modules.values():
		sockets.append_array(module.get_input_sockets())
	return sockets

func register_module(module) -> void:
	if not registered_modules.has(module.unique_id):
		registered_modules[module.unique_id] = module

func recompute_active_output_sockets(modules: Array) -> void:
	var active_set := {}
	for input_socket in get_all_input_sockets():
		if input_socket.source != null:
			active_set[input_socket.source] = true
	for module in modules:
		module.active_output_sockets.clear()
		for socket in module.get_output_sockets():
			if active_set.has(socket):
				module.active_output_sockets.append(socket.name)

func configure(builder: ShaderBuilder, shader_type : String = "spatial") -> void:
	builder.shader_type(shader_type)

	var modules: Array = registered_modules.values()


	recompute_active_output_sockets(modules)
	configure_instance_uniforms(builder, modules)
	configure_shared_varyings(builder, modules)
	configure_includes(builder, modules)
	precompute_eval_metadata(builder, modules)

	var execution_order = topological_sort()
	for module in execution_order:
		apply_module(builder, module)

	# Emit eval functions last, so all GEN functions they call are already defined
	configure_eval_functions(builder, modules)

func configure_shared_varyings(builder: ShaderBuilder, modules: Array) -> void:
	requested_vars.clear()
	for m in modules:
		if m.has_method("get_required_shared_varyings"):
			var arr = m.get_required_shared_varyings()
			if typeof(arr) == TYPE_ARRAY and arr.size() > 0:
				requested_vars.append_array(arr)

	# Local deduplication of shared-variable keys
	var unique := {}
	for v in requested_vars:
		unique[v] = true
	var unique_list: Array = unique.keys()

	if unique_list.size() > 0:
		SV_inst.request(unique_list)
		var global_code = SV_inst.build_global_declarations()
		if global_code != "":
			builder.add_code(global_code, "global")
		var vertex_code = SV_inst.build_vertex_code()
		if vertex_code != "":
			builder.add_code(vertex_code, "vertex")
		var fragment_code = SV_inst.build_fragment_code()
		if fragment_code != "":
			builder.add_code(fragment_code, "fragment")


func configure_includes(builder: ShaderBuilder, modules: Array) -> void:
	for module in modules:
		for inc in module.get_include_files():
			builder.add_include(inc)


#region Evaluation functions

func configure_eval_functions(builder: ShaderBuilder, modules: Array) -> void:
	# For every Bump module that has a connected Height input, build eval function
	for module in modules:
		if not module or not module.has_method("get_input_sockets"):
			continue
		if String(module.module_name) != "Bump":
			continue
		var sockets: Array = module.get_input_sockets()
		var height_idx := -1
		for i in range(sockets.size()):
			if String(sockets[i].name) == "Height":
				height_idx = i
				break
		if height_idx == -1:
			continue
		if sockets[height_idx].source == null:
			continue
		build_eval_for_bump(builder, module, height_idx)

func precompute_eval_metadata(builder: ShaderBuilder, modules: Array) -> void:
	# Ensure EvalCtx is declared early for Bump code that uses it in fragment
	if not eval_ctx_declared:
		var eval_ctx_code := """
		struct EvalCtx {
			vec2 uv;
			vec3 generated;
			vec3 object;
			vec3 camera;
			vec2 screen_uv;
			vec3 world_pos;
			vec3 world_normal;
		};
		""".strip_edges()
		builder.add_code(eval_ctx_code, "global")
		eval_ctx_declared = true

	# Compute and store coordinate sources for each Bump
	for module in modules:
		if not module or not module.has_method("get_input_sockets"):
			continue
		if String(module.module_name) != "Bump":
			continue
		var sockets: Array = module.get_input_sockets()
		var height_idx := -1
		for i in range(sockets.size()):
			if String(sockets[i].name) == "Height":
				height_idx = i
				break
		if height_idx == -1 or sockets[height_idx].source == null:
			continue
		var srcs := detect_eval_sources(module, height_idx)
		if srcs.has("generated") and srcs["generated"] != "":
			module.set_meta("eval_src_generated", srcs["generated"])
		if srcs.has("object") and srcs["object"] != "":
			module.set_meta("eval_src_object", srcs["object"])
		if srcs.has("camera") and srcs["camera"] != "":
			module.set_meta("eval_src_camera", srcs["camera"])
		if srcs.has("screen_uv") and srcs["screen_uv"] != "":
			module.set_meta("eval_src_screen_uv", srcs["screen_uv"])

func build_eval_for_bump(builder: ShaderBuilder, bump_module, height_idx: int) -> void:
	# Collect upstream modules subgraph from Height source
	var src_socket = bump_module.get_input_sockets()[height_idx].source
	if src_socket == null:
		return
	var root_mod = src_socket.parent_module
	var subgraph: Array = []
	var visited := {}
	collect_upstream_modules(root_mod, visited, subgraph)

	# Filter global topological order to preserve correct sequence
	var topo = topological_sort()
	var need := {}
	for m in subgraph:
		need[m] = true
	var ordered: Array = []
	for m in topo:
		if need.has(m):
			ordered.append(m)

	# Concatenate fragment code of the subgraph
	var merged_code := ""
	for m in ordered:
		if not m.has_method("get_code_blocks"):
			continue
		var blocks: Dictionary = m.get_code_blocks()
		for k in blocks:
			var b = blocks[k]
			if typeof(b) == TYPE_DICTIONARY and String(b.get("stage", "")) == "fragment":
				merged_code += String(b.get("code", "")) + "\n"

	# Identifier remapping to ctx.*
	var repl := {
		"UV": "ctx.uv",
		"v_generated": "ctx.generated",
		"v_object": "ctx.object",
		"sv_world_pos": "ctx.world_pos",
		"sv_world_normal": "ctx.world_normal",
		"sv_view_pos": "ctx.camera",
		"SCREEN_UV": "ctx.screen_uv",
	}
	# also map per-module generated varyings like gen_vec_<uid> to ctx.generated
	for m in ordered:
		var gen_name := "gen_vec_%s" % m.unique_id
		repl[gen_name] = "ctx.generated"

	merged_code = replace_identifiers(merged_code, repl)

	# Determine height expression as seen by Bump
	var args: Array = bump_module.get_input_args()
	var height_expr: String = String(args[height_idx])
	height_expr = replace_identifiers(height_expr, repl)

	# Wrap into eval function; ensure svCtx is available
	var func_name := "eval_height_%s" % bump_module.unique_id
	var func_code := """
	float {fname}(EvalCtx ctx, TransformCtx svCtx) {{
	{body}
		return ({ret});
	}}
	""".format({
		"fname": func_name,
		"body": merged_code.indent("    "),
		"ret": height_expr,
	}).strip_edges()

	builder.add_code(func_code, "functions")

func collect_upstream_modules(module, visited: Dictionary, acc: Array) -> void:
	if visited.has(module):
		return
	visited[module] = true
	# visit inputs first
	if module.has_method("get_input_sockets"):
		for s in module.get_input_sockets():
			if s.source != null and s.source.parent_module != null:
				collect_upstream_modules(s.source.parent_module, visited, acc)
	# then append this module
	acc.append(module)

func replace_identifiers(code: String, repl: Dictionary) -> String:
	var out := code
	for key in repl.keys():
		var pattern := "\\b" + String(key) + "\\b"
		var rx := RegEx.new()
		var ok = rx.compile(pattern)
		if ok == OK:
			out = rx.sub(out, String(repl[key]), true)
		else:
			# fallback naive replace if regex failed
			out = out.replace(String(key), String(repl[key]))
	return out

func detect_eval_sources(bump_module, height_idx: int) -> Dictionary:
	var result := {
		"generated": "",
		"object": "",
		"camera": "",
		"screen_uv": "",
	}
	var height_src = bump_module.get_input_sockets()[height_idx].source
	if height_src == null:
		return result
	var visited_mods := {}
	detect_sources_from_output(height_src, result, visited_mods)
	return result

func detect_sources_from_output(out_socket, result: Dictionary, visited_mods: Dictionary) -> void:
	if out_socket == null:
		return
	var mod = out_socket.parent_module
	if mod == null:
		return
	if visited_mods.has(mod.unique_id):
		return
	visited_mods[mod.unique_id] = true

	# Texture Coordinate direct outputs
	if String(mod.module_name) == "Texture Coordinate":
		var oname := String(out_socket.name)
		match oname:
			"Generated":
				if result["generated"] == "":
					result["generated"] = "v_generated"
			"Object":
				if result["object"] == "":
					result["object"] = "v_object"
			"Camera":
				if result["camera"] == "":
					# use view position as canonical camera source
					result["camera"] = "sv_view_pos"
			"Window":
				if result["screen_uv"] == "":
					result["screen_uv"] = "SCREEN_UV"

	# Noise Texture with implicit generated coords
	if String(mod.module_name) == "Noise Texture":
		var in_socks: Array = mod.get_input_sockets()
		if in_socks.size() > 0:
			var vec_sock = in_socks[0]
			if vec_sock.source == null:
				# matches code path that emits gen_vec_<uid>
				if result["generated"] == "":
					result["generated"] = "gen_vec_%s" % mod.unique_id

	# Recurse into inputs
	if mod.has_method("get_input_sockets"):
		for s in mod.get_input_sockets():
			if s.source != null:
				detect_sources_from_output(s.source, result, visited_mods)

#endregion

func topological_sort() -> Array:
	var visited = {}
	var order = []
	
	for module in registered_modules.values():
		visit(module, visited, order)
	
	#print("Execution order of modules:") 
	#for module in order:
		#print("- %s (%s)" % [module.module_name, module.unique_id])
	
	return order

func visit(module, visited: Dictionary, order: Array) -> void:
	if visited.has(module):
		if visited[module]:
			return
		else:
			push_error("Cycle dependency detected!")
		return
	
	visited[module] = false
	for dependency in module.get_dependency():
		#print("Module %s depends on %s" % [module.unique_id, dependency.unique_id])
		visit(dependency, visited, order)
	
	visited[module] = true
	order.append(module)


func apply_module(builder: ShaderBuilder, module) -> void:
	add_module_defines(builder, module)
	add_module_uniforms(builder, module)
	add_module_code_blocks(builder, module)
	add_module_render_modes(builder, module)

func add_module_defines(builder: ShaderBuilder, module) -> void:
	for define_name in module.get_compile_defines():
		builder.add_define(define_name)

func add_module_uniforms(builder: ShaderBuilder, module) -> void:
	var inputs = module.get_uniform_definitions()
	for input_name in inputs:
		var input_def = inputs[input_name]
		if typeof(input_def) == TYPE_ARRAY:
			input_def = ShaderSpec.decode_uniform_spec(input_def)
		var unique_name = "u_%s_%s" % [module.unique_id.replace("-", "_"), input_name]
		var def_val = input_def.get("default", null)
		var override_val = null
		if module.has_method("get_uniform_override"):
			override_val = module.get_uniform_override(input_name)
		if override_val != null:
			def_val = override_val
		builder.add_uniform(
			input_def["type"],
			unique_name,
			def_val,
			input_def.get("hint", null),
			input_def.get("hint_params", null)
		)

func add_module_code_blocks(builder: ShaderBuilder, module) -> void:
	var code_blocks = module.get_code_blocks()
	for block_name in code_blocks:
		var block = code_blocks[block_name]
		builder.add_code(block["code"], block["stage"])

func add_module_render_modes(builder: ShaderBuilder, module) -> void:
	for mode in module.get_render_modes():
		builder.add_render_mode(mode)

func configure_instance_uniforms(builder: ShaderBuilder, modules: Array) -> void:
	var need_bbox := false
	for m in modules:
		if m and m.has_method("get_required_instance_uniforms"):
			var arr = m.get_required_instance_uniforms()
			if typeof(arr) == TYPE_ARRAY:
				for v in arr:
					if int(v) == ShaderSpec.InstanceUniform.BBOX:
						need_bbox = true
						break
		if need_bbox:
			break
	if need_bbox:
		var code := """
instance uniform vec3 bbox_min : instance_index(0);
instance uniform vec3 bbox_max : instance_index(1);
""".strip_edges()
		builder.add_code(code, "global")
