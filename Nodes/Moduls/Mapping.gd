# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name MappingModule
extends ShaderModule

enum MappingType { POINT, TEXTURE, VECTOR, NORMAL }

@export_enum("Point", "Texture", "Vector", "Normal") var mapping_type: int = MappingType.POINT


func _init() -> void:
	super._init()
	module_name = "Mapping"
	
	_input_sockets = [
		InputSocket.new("Vector", InputSocket.SocketType.VEC3, Vector3.ZERO),
		InputSocket.new("Location", InputSocket.SocketType.VEC3, Vector3.ZERO),
		InputSocket.new("Rotation", InputSocket.SocketType.VEC3, Vector3.ZERO),
		InputSocket.new("Scale", InputSocket.SocketType.VEC3, Vector3.ONE)
	]
	_output_sockets = [
		OutputSocket.new("Vector", OutputSocket.SocketType.VEC3)
	]
	
	for socket in _output_sockets:
		socket.set_parent_module(self)
	
	update_active_sockets()

func get_include_files() -> Array[String]:
	return [PATHS.INC["MAPPING"]]

func get_uniform_definitions() -> Dictionary:
	var uniforms = {}
	uniforms["mapping_type"] = {
		"type": "int",
		"default": mapping_type,
		"hint": "hint_enum(\"Point\", \"Texture\", \"Vector\", \"Normal\")"
	}
	
	for socket in get_input_sockets():
		if socket.name == "Type":
			continue
		if not socket.source:
			uniforms[socket.name.to_lower()] = socket.to_uniform()
	return uniforms

func get_input_sockets() -> Array[InputSocket]: 
	return _input_sockets

func get_output_sockets() -> Array[OutputSocket]:
	return _output_sockets

func get_code_blocks() -> Dictionary:
	update_active_sockets()
	var active: Array[String] = get_active_output_sockets()
	
	if not "Vector" in active:
		return {}
	
	var outputs = get_output_vars()
	var inputs = _get_input_args()
	
	var rotation_arg: String
	var in_socks = get_input_sockets()
	if in_socks.size() > 2 and in_socks[2].source:
		rotation_arg = inputs[2]
	else:
		rotation_arg = "radians(%s)" % inputs[2]
	
	return {
		"fragment_%s" % unique_id: {
			"stage": "fragment",
			"code": generate_code_block(
				"fragment",
				"""
// {module}: {uid}
vec3 {local_var} = apply_mapping(
	{type},
	{vector},
	{location},
	{rotation},
	{scale}
);
""",
				{
					"uid": unique_id,
					"module": module_name,
					"output": outputs["Vector"],
					"local_var": outputs["Vector"],
					"type": _get_prefixed_name("mapping_type"),
					"vector": inputs[0],         # Vector
					"location": inputs[1],       # Location
					"rotation": rotation_arg,    # Rotation
					"scale": inputs[3]           # Scale
				}
			)
		}
	}
