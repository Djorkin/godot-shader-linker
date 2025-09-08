# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later
class_name ShaderBuilder

var _shader_type: String
var render_modes := {}
var uniforms := []
var vertex_blocks := []
var fragment_blocks := []
var added_uniforms := {}
var added_includes := {}
var include_blocks := [] 
var added_function_hashes := {}  
var function_blocks := []
var global_blocks := []
var defines := {} 
var uniform_resources := {}

func shader_type(type: String) -> void:
	_shader_type = type

func add_render_mode(mode: String) -> void:
	if not mode:
		return
	
	var key = mode.strip_edges().to_lower()
	if render_modes.has(key):
		return
	render_modes[key] = mode.strip_edges()

func add_define(name: String) -> void:
	if not name:
		return

	var key = name.strip_edges()
	if defines.has(key):
		return
	defines[key] = "#define %s" % key

func add_include(path: String) -> void:
	var abs_path = ProjectSettings.globalize_path(path).to_lower()
	if added_includes.has(abs_path):
		return
	added_includes[abs_path] = true
	include_blocks.append('#include "%s"' % path)

func normalize_braces(s: String) -> String:
	return String(s).replace("{{", "{").replace("}}", "}")

func add_uniform(type: String, name: String, default_value = null, hint = null, hint_params = null) -> void:
	if added_uniforms.has(name):
		return
	
	var uniform_str = "uniform %s %s" % [type, name]
	
	var hint_str := ShaderSpec.format_uniform_hint(hint, hint_params)
	if hint_str != "":
		uniform_str += " : %s" % hint_str
	
	if default_value != null:
		uniform_str += " = %s" % ShaderSpec.format_uniform_value(default_value, type)
	
	uniform_str += ";"
	
	uniforms.append(uniform_str)
	added_uniforms[name] = true


func add_code(code: String, stage) -> void:
	if not code:
		return

	var stage_enum = ShaderSpec.stage_from(stage)
	code = normalize_braces(code)
	var key = "%s:%s" % [stage_enum, code.hash()]

	if added_function_hashes.has(key):
		return
	added_function_hashes[key] = true

	match stage_enum:
		ShaderSpec.Stage.GLOBAL:
			global_blocks.append(code)
		ShaderSpec.Stage.FUNCTIONS:
			function_blocks.append(code)
		ShaderSpec.Stage.VERTEX:
			vertex_blocks.append(code)
		ShaderSpec.Stage.FRAGMENT:
			fragment_blocks.append(code)



func build_shader() -> String:
	var parts := []
	
	parts.append("shader_type %s;" % _shader_type)
	
	if render_modes:
		parts.append("render_mode %s;" % ", ".join(render_modes.values()) + "\n")
	
	if defines:
		parts.append("// DEFINES")
		parts.append("\n".join(defines.values()))
	
	if global_blocks:
		parts.append("// GLOBAL")
		parts.append("\n".join(global_blocks))
	
	if uniforms:
		parts.append("// UNIFORMS")
		parts.append("\n".join(uniforms))

	if include_blocks:
		parts.append("#define INCLUDE_WRAPPER" + "\n") 
		parts.append("// INCLUDES")
		parts.append("\n".join(include_blocks) + "\n")
	
	if function_blocks:
		parts.append("// FUNCTIONS")
		parts.append("\n".join(function_blocks) + "\n")
	
	if vertex_blocks.size() > 0:
		parts.append(build_stage_code(ShaderSpec.Stage.VERTEX, vertex_blocks) + "\n")
	
	if fragment_blocks.size() > 0:
		parts.append(build_stage_code(ShaderSpec.Stage.FRAGMENT, fragment_blocks) + "\n")
	
	return "\n".join(parts)

func build_stage_code(stage_enum: int, blocks: Array) -> String:
	var code = []
	code.append("void %s() {" % ShaderSpec.stage_function_name(stage_enum))
	for block in blocks:
		for line in str(block).split("\n"):
			if line.strip_edges():
				code.append("\t" + line)
	code.append("}")
	return "\n".join(code)
