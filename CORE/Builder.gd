# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later
class_name ShaderBuilder


var _shader_type: String
var _render_modes := {}
var _uniforms := []
var _vertex_blocks := {}
var _fragment_blocks := {}
var _added_uniforms := {}
var _added_functions := {}
var _added_includes := {}
var _include_blocks := [] 
var _added_function_hashes := {}  
var _function_blocks := []
var _global_blocks := []
var _defines := {} 

func reset() -> void:
	_shader_type = "spatial"
	_uniforms.clear()
	_vertex_blocks.clear()
	_fragment_blocks.clear()
	_added_uniforms.clear()
	_added_functions.clear()
	_added_includes.clear()
	_include_blocks.clear()
	_function_blocks.clear() 
	_added_function_hashes.clear() 
	_global_blocks.clear()
	_render_modes.clear()
	_defines.clear()

func shader_type(type: String) -> void:
	_shader_type = type

func add_include(path: String) -> void:
	var abs_path = ProjectSettings.globalize_path(path).to_lower()
	if _added_includes.has(abs_path):
		return
	
	_added_includes[abs_path] = true
	_include_blocks.append('#include "%s"' % path)


func add_uniform(type: String, name: String, default_value = null, hint: String = "") -> void:
	if _added_uniforms.has(name):
		return
	
	var uniform_str = "uniform %s %s" % [type, name]
	
	if hint != "":
		uniform_str += " : %s" % hint
	
	if default_value != null:
		uniform_str += " = %s" % _format_uniform_value(default_value, type)
	
	uniform_str += ";"
	
	_uniforms.append(uniform_str)
	_added_uniforms[name] = true


func add_code(code: String, block_type: String, stage: String = "fragment") -> void:
	if code == "":
		return
	
	# Добавляем уникальный идентификатор модуля в ключ
	var key = "%s:%s:%s" % [stage, block_type, code.hash()] 
	
	if block_type == "functions":
		var hash = code.hash()
		if _added_function_hashes.has(hash):
			return
		_added_function_hashes[hash] = true
		_function_blocks.append(code)
		return
	
	if _added_functions.has(key):
		return
	
	if stage == "global":
		_global_blocks.append(code)
		_added_functions[key] = true
		return
	
	match stage:
		"vertex":
			_vertex_blocks[block_type] = code
		"fragment":
			_fragment_blocks[block_type] = code
	
	_added_functions[key] = true


func add_render_mode(mode: String) -> void:
	if mode == "":
		return
	
	var key = mode.strip_edges().to_lower()
	if _render_modes.has(key):
		return
	_render_modes[key] = mode.strip_edges()


func add_define(name: String) -> void:
	if name == "":
		return
	var key = name.strip_edges()
	if _defines.has(key):
		return
	_defines[key] = "#define %s" % key


# Сборка полного шейдера
func build_shader() -> String:
	var shader_code: String = "shader_type %s;\n" % _shader_type
	
	# render mode строка
	if _render_modes.size() > 0:
		shader_code += "render_mode " + ", ".join(_render_modes.values()) + ";\n"

	# Добавляем compile-time define-ы
	if _defines.size() > 0:
		shader_code += "\n".join(_defines.values()) + "\n"

	# Определяем вспомогательные препроцессорные флаги
	if _render_modes.has("world_vertex_coords"):
		shader_code += "#define WORLD_VERTEX_COORDS\n"

	# Блок include-директив
	if _include_blocks.size() > 0:
		shader_code += "#define SHARED_DEFINE"
		shader_code += "\n// INCLUDES\n"
		shader_code += "\n".join(_include_blocks) + "\n\n"
	
	
	# Глобальные переменные (varying)
	if _global_blocks.size() > 0:
		shader_code += "// GLOBAL\n"
		shader_code += "\n".join(_global_blocks) + "\n\n"
	
	# Добавляем uniforms
	shader_code += "// UNIFORMS\n"
	shader_code += "\n".join(_uniforms) + "\n\n"
	
	# Добавляем функции ПЕРЕД main
	if _function_blocks.size() > 0:
		shader_code += "// FUNCTIONS\n"
		shader_code += "\n".join(_function_blocks) + "\n\n"
	
	# Вершинный шейдер
	if _vertex_blocks.size() > 0:
		if _vertex_blocks.has("functions"):
			shader_code += _vertex_blocks["functions"] + "\n\n"
		
		shader_code += "void vertex() {\n"
		# Добавляем все declarations
		if _vertex_blocks.has("declarations"):
			var decl_code = _vertex_blocks["declarations"]
			for line in decl_code.split("\n"):
				if line.strip_edges() != "":
					shader_code += "\t" + line + "\n"

		# Затем добавляем все остальные блоки (кроме declarations)
		for block_key in _vertex_blocks:
			if block_key != "declarations" and block_key != "functions":
				var code = _vertex_blocks[block_key]
				for line in code.split("\n"):
					if line.strip_edges() != "":
						shader_code += "\t" + line + "\n"
		shader_code += "}\n\n"
	
	# Фрагментный шейдер
	shader_code += "void fragment() {\n"
	# Сначала добавляем все declarations
	if _fragment_blocks.has("declarations"):
		var decl_code = _fragment_blocks["declarations"]
		for line in decl_code.split("\n"):
			if line.strip_edges() != "":
				shader_code += "\t" + line + "\n"

	# Затем добавляем все остальные блоки (кроме declarations)
	for block_key in _fragment_blocks:
		if block_key != "declarations" and block_key != "functions":
			var code = _fragment_blocks[block_key]
			for line in code.split("\n"):
				if line.strip_edges() != "":
					shader_code += "\t" + line + "\n"

	shader_code += "}\n"
	
	return shader_code


func create_material() -> ShaderMaterial:
	var material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = build_shader()
	material.shader = shader
	return material

func _remove_unused_functions(code: String) -> String:
	var used_functions = []
	var function_pattern = RegEx.new()
	function_pattern.compile("\\b([a-zA-Z0-9_]+)_[a-f0-9]{4}_[a-zA-Z_]+\\b")
	
	for match in function_pattern.search_all(code):
		used_functions.append(match.get_string(1))
	
	# Фильтрация объявлений функций
	var lines = code.split("\n")
	var result = []
	var current_func = ""
	
	for line in lines:
		if line.begins_with("vec"):
			current_func = line.split("(")[0].split(" ")[-1]
			if current_func in used_functions:
				result.append(line)
			else:
				current_func = ""
		elif current_func != "":
			result.append(line)
		else:
			result.append(line)
	
	return "\n".join(result)


static func _format_uniform_value(value, type: String) -> String:
	match typeof(value):
		TYPE_VECTOR3:
			var v3: Vector3 = value
			return "vec3(%s, %s, %s)" % [v3.x, v3.y, v3.z]
		TYPE_VECTOR4:
			var v4: Vector4 = value
			return "vec4(%s, %s, %s, %s)" % [v4.x, v4.y, v4.z, v4.w]
		TYPE_COLOR:
			var c: Color = value
			return "vec4(%s, %s, %s, %s)" % [c.r, c.g, c.b, c.a]
		TYPE_FLOAT:
			return "%s" % value
		TYPE_INT:
			return "%d" % value
		TYPE_BOOL:
			return "true" if value else "false"
		_:
			return str(value)
