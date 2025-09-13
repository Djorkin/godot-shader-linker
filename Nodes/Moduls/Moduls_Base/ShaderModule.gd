# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name ShaderModule
extends Resource

const PATHS = preload("res://addons/godot_shader_linker_(gsl)/Nodes/Moduls/Moduls_Base/path.gd")


@export_category("Module Settings")
@export var module_name: String = "Unnamed"


var unique_id: String
var dependencies: Array[ShaderModule] = []
var input_sockets: Array[InputSocket] = []
var output_sockets: Array[OutputSocket] = []
var active_output_sockets: Array[String] = []
var uniform_overrides: Dictionary = {}


func _init() -> void:
	unique_id = generate_uuid()

func get_active_output_sockets() -> Array[String]:
	return active_output_sockets.duplicate()

func get_uniform_definitions() -> Dictionary:
	return {}

func get_dependency() -> Array[ShaderModule]:
	return dependencies

func get_code_blocks() -> Dictionary:
	return {}

func get_input_sockets() -> Array[InputSocket]:
	return input_sockets

func get_output_sockets() -> Array[OutputSocket]:
	return output_sockets

func get_render_modes() -> Array[String]:
	return []

func get_compile_defines() -> Array[String]:
	var arr: Array[String] = []
	return arr

func get_output_vars() -> Dictionary:
	var outputs = {}
	for socket in get_output_sockets():
		outputs[socket.name] = "output_%s_%s" % [unique_id.replace("-", "_"), socket.name.to_lower()]
	return outputs

func get_prefixed_name(param: String) -> String:
	return "u_%s_%s" % [unique_id.replace("-", "_"), param]

func get_input_args() -> Array:
	var args = []
	for socket in get_input_sockets():
		var expr: String
		if socket.source:
			var source_vars = socket.source.parent_module.get_output_vars()
			var from_type = socket.source.type_name()
			var to_type = socket.type_name()
			expr = SocketCompatibility.convert(source_vars[socket.source.name], from_type, to_type)
		else:
			expr = get_prefixed_name(socket.name.to_lower().replace(" ", "_"))
		args.append(expr)
	return args

func get_uniform_override(name: String):
	return uniform_overrides.get(name, null)

func set_uniform_override(name: String, value) -> void:
	uniform_overrides[name] = value

func add_dependency(module: ShaderModule) -> void:
	if not module in dependencies:
		dependencies.append(module)

func generate_uuid() -> String:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	return "%08x" % rng.randi()

func get_required_shared_varyings() -> Array[int]:
	return []

func get_required_instance_uniforms() -> Array[int]:
	return []

##unused
#func get_mark() -> String:
	#var data = ""
	#data += module_name
	#data += str(get_input_sockets().map(func(s): return s.name + s.type_name()))
	#data += str(get_output_sockets().map(func(s): return s.name + s.type_name()))
	#data += str(get_code_blocks())
	#return data.sha1_text()

func generate_code_block(stage: String, template: String, args: Dictionary) -> String:
	return template.format(args).strip_edges()
