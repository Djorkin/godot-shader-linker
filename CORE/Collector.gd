# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later
class_name Collector


var SV_inst := SharedVaryings.new()
var requested_vars: Array = []
var registered_modules := {}



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
	configure_shared_varyings(builder, modules)
	configure_includes(builder, modules)

	var execution_order = topological_sort()
	for module in execution_order:
		apply_module(builder, module)


func configure_shared_varyings(builder: ShaderBuilder, modules: Array) -> void:
	requested_vars.clear()
	for m in modules:
		if m.has_method("get_required_shared_varyings"):
			var arr = m.get_required_shared_varyings()
			if typeof(arr) == TYPE_ARRAY and arr.size() > 0:
				requested_vars.append_array(arr)

	# локальная дедупликация ключей shared-переменных
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


func configure_includes(builder: ShaderBuilder, modules: Array) -> void:
	for module in modules:
		for inc in module.get_include_files():
			builder.add_include(inc)


func topological_sort() -> Array:
	var visited = {}
	var order = []
	
	for module in registered_modules.values():
		visit(module, visited, order)
	
	print("Execution order of modules:")
	for module in order:
		print("- %s (%s)" % [module.module_name, module.unique_id])
	
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
		print("Module %s depends on %s" % [module.unique_id, dependency.unique_id])
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
	
