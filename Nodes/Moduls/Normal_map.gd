# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name NormalMapModule
extends ShaderModule


# Only Tangent Space is implemented. The rest work as stubs.
enum NormalMapType {
	TANGENT_SPACE,
	OBJECT_SPACE,
	WORLD_SPACE,
	BLENDER_OBJECT_SPACE,
	BLENDER_WORLD_SPACE
}

@export_enum(
	"Tangent Space",
	"Object Space",
	"World Space",
	"Blender Object Space",
	"Blender World Space"
)
var normal_map_type: int = NormalMapType.TANGENT_SPACE


func _init() -> void:
	super._init()
	module_name = "NormalMap"
	
	input_sockets = [
		InputSocket.new("Strength", InputSocket.SocketType.FLOAT, 1.0),
		InputSocket.new("Color", InputSocket.SocketType.VEC4, Vector4(0.5, 0.5, 1.0, 1.0))
	]
	output_sockets = [
		OutputSocket.new("Normal", OutputSocket.SocketType.VEC3)
	]
	
	for socket in output_sockets:
		socket.set_parent_module(self)

func get_include_files() -> Array[String]:
	return [PATHS.INC["NORMAL_MAP"]]

func get_input_sockets() -> Array[InputSocket]:
	return input_sockets

func get_output_sockets() -> Array[OutputSocket]:
	return output_sockets

func get_uniform_definitions() -> Dictionary:
	var uniforms = {}

	uniforms["normal_map_type"] = {"type": "int", "default": normal_map_type, "hint": "hint_enum(\"Tangent Space\", \"Object Space\", \"World Space\", \"Blender Object Space\", \"Blender World Space\")"}
	for s in get_input_sockets():
		if s.source:
			continue
		var u = s.to_uniform()
		match s.name:
			"Strength":
				u["hint"] = "hint_range(0,10)"
			_:
				pass
		uniforms[s.name.to_lower()] = u
	return uniforms

func get_code_blocks() -> Dictionary:
	var outputs := get_output_vars()
	var inputs := get_input_args()
	var idx_strength := 0
	var idx_color := 1
	
	if not "Normal" in get_active_output_sockets():
		return {}
	
	var frag_template := """

 // {module}: {uid} 
vec3 {out_var} = get_normal_map(
	{color}.rgb,
	{strength},
	NORMAL,
	TANGENT
);
""".strip_edges()
	
	var frag_code := frag_template.format({
		"module": module_name,
		"uid": unique_id,
		"out_var": outputs["Normal"],
		"color": inputs[idx_color],
		"strength": inputs[idx_strength]
	})
	
	return {
		"fragment_%s" % unique_id: {"stage": "fragment", "code": frag_code}
	}
