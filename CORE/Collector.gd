# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later
class_name Collector

#var active_modules: Array = []
var registered_modules := {}

func get_all_input_sockets() -> Array[InputSocket]:
	var sockets: Array[InputSocket] = []
	for module in registered_modules.values():
		sockets.append_array(module.get_input_sockets())
	return sockets

func register_module(module) -> void:
	if not registered_modules.has(module.unique_id):
		registered_modules[module.unique_id] = module
		#active_modules.append(module)

func recompute_active_output_sockets():
	var active_set := {}
	for input_socket in get_all_input_sockets():
		if input_socket.source != null:
			active_set[input_socket.source] = true
	for module in registered_modules.values():
		module.active_output_sockets.clear()
		for socket in module.get_output_sockets():
			if active_set.has(socket):
				module.active_output_sockets.append(socket.name)

func configure(builder: ShaderBuilder, shader_type : String = "spatial") -> void:
	#builder.reset()
	builder.shader_type(shader_type)

	
	var all_includes = []
	for module in registered_modules.values():
		all_includes.append_array(module.get_include_files())
	
	var unique_includes = {}
	for include in all_includes:
		var abs_path = ProjectSettings.globalize_path(include).to_lower()
		if not unique_includes.has(abs_path):
			unique_includes[abs_path] = include
			builder.add_include(include)

	var processed = {}
	var execution_order = topological_sort()
	recompute_active_output_sockets()
	for module in execution_order:
		if not processed.has(module.unique_id):
			apply_module(builder, module, processed)


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

func apply_module(builder: ShaderBuilder, module, processed: Dictionary) -> void:
	if processed.has(module.unique_id):
		return
	
	for define_name in module.get_compile_defines():
		builder.add_define(define_name)
	
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
	
	for block_name in module.get_code_blocks():
		var block = module.get_code_blocks()[block_name]
		builder.add_code(block["code"], block["stage"])
	
	for mode in module.get_render_modes():
		builder.add_render_mode(mode)
	
	processed[module.unique_id] = true
