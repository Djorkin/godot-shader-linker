# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later
class_name Collector

static var active_modules: Array[ShaderModule] = []
static var registered_modules := {}


static func get_all_input_sockets() -> Array[InputSocket]:
	var sockets: Array[InputSocket] = []
	for module in registered_modules.values():
		sockets.append_array(module.get_input_sockets())
	return sockets

static func register_module(module: ShaderModule) -> void:
	if not registered_modules.has(module.unique_id):
		registered_modules[module.unique_id] = module
		#active_modules.append(module)

static func configure(builder: ShaderBuilder, shader_type : String = "spatial") -> void:
    # Новый подход: shared varyings собираются через SharedVaryings.request() из модулей.
    # Сбрасываем накопленные запросы перед сборкой.
    SharedVaryings.reset()

    builder.reset()
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
	var execution_order = _topological_sort()
    for module in execution_order:
        if not processed.has(module.unique_id):
            _apply_module(builder, module, processed)

    # Добавляем общий блок объявлений shared varyings и единый vertex-код один раз
    var sv_decls = SharedVaryings.build_global_declarations()
    if sv_decls != "":
        builder.add_code(sv_decls, "shared_varyings_decls", "global")
    var sv_vertex = SharedVaryings.build_vertex_code()
    if sv_vertex != "":
        builder.add_code(sv_vertex, "shared_varyings_vertex", "vertex")
	
	for module in execution_order:
		module.update_active_sockets()

static func _topological_sort() -> Array:
	var visited = {}
	var order = []
	
	for module in registered_modules.values():
		_visit(module, visited, order)
	
	
	print("Execution order of modules:")
	for module in order:
		print("- %s (%s)" % [module.module_name, module.unique_id])
	
	return order

static func _visit(module: ShaderModule, visited: Dictionary, order: Array) -> void:
	if visited.has(module):
		if visited[module]:
			return
		else:
			push_error("Cycle dependency detected!")
		return
	
	visited[module] = false
	for dependency in module.get_dependency():
		print("Module %s depends on %s" % [module.unique_id, dependency.unique_id])
		_visit(dependency, visited, order)
	
	visited[module] = true
	order.append(module)

const SharedVaryings = preload("res://addons/godot_shader_linker_(gsl)/CORE/SharedVaryings.gd")

static func _apply_module(builder: ShaderBuilder, module: ShaderModule, processed: Dictionary) -> void:
	if processed.has(module.unique_id):
		return
	
	for define_name in module.get_compile_defines():
		builder.add_define(define_name)
	
	var inputs = module.get_uniform_definitions()
	for input_name in inputs:
		var input_def = inputs[input_name]
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
			input_def.get("hint", "")
		)
	
	for block_name in module.get_code_blocks():
		var block = module.get_code_blocks()[block_name]
		builder.add_code(block["code"], block_name, block["stage"])
	
	for mode in module.get_render_modes():
		builder.add_render_mode(mode)
	
	processed[module.unique_id] = true

static func _prefix_code(code: String, module: ShaderModule) -> String:
	return code
