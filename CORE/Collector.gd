# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later
class_name Collector

static var active_modules: Array[ShaderModule] = []
static var registered_modules := {}

# Shared varyings, собираемые из всех модулей
static var shared_requirements : Dictionary = {}


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
	shared_requirements.clear()
	for module in registered_modules.values():
		if module and module.has_method("get_shared_requirements"):
			var reqs = module.get_shared_requirements()
			if typeof(reqs) == TYPE_DICTIONARY:
				for key in reqs:
					if not shared_requirements.has(key):
						shared_requirements[key] = reqs[key]

	# Отладочный вывод
	if shared_requirements.size() > 0:
		print("[Collector] Shared varyings: " + str(shared_requirements))

	builder.reset()
	builder.shader_type(shader_type)
	_apply_shared_varyings(builder)
	
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

static func _apply_shared_varyings(builder: ShaderBuilder) -> void:
	# Добавляет объявления и vertex-код для общих varying-переменных.
	if shared_requirements.is_empty():
		return

	var vertex_lines: Array[String] = []
	for key in shared_requirements:
		var def: Dictionary = SharedVaryings.get_definition(key)
		if def.is_empty():
			push_warning("Shared varying '%s' not supported" % key)
			continue

		var type_str: String = str(def.get("type", "vec3"))
		var var_name = "v_%s" % key
		builder.add_code("varying %s %s;" % [type_str, var_name], "shared_var_%s" % key, "global")

		var vcode: String = def.get("vertex_code", "")
		if vcode.strip_edges() != "":
			vertex_lines.append(vcode)

	if vertex_lines.size() > 0:
		builder.add_code("\n".join(vertex_lines), "shared_varyings_vertex", "vertex")

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
