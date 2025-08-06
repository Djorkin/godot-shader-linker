# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name InputSocket
extends RefCounted

enum SocketType {INT, FLOAT, VEC2, VEC3, VEC4, SAMPLER2D, SHADER}
const TYPE_NAMES = {
	SocketType.INT: "int",
	SocketType.FLOAT: "float",
	SocketType.VEC2: "vec2",
	SocketType.VEC3: "vec3",
	SocketType.VEC4: "vec4",
	SocketType.SAMPLER2D: "sampler2D",
	SocketType.SHADER: "Material"
}

var name: String
var type: SocketType
var default: Variant
var description: String
var source: OutputSocket = null

func _init(socket_name: String, type: SocketType, default_value: Variant = null, desc: String = "") -> void:
	name = socket_name
	self.type = type
	default = default_value
	description = desc

func type_name() -> String:
	return TYPE_NAMES.get(type, "float")

func to_uniform() -> Dictionary:
	return {"type": type_name(), "default": default}

func declaration(var_name: String) -> String:
	return "%s %s" % [type_name(), var_name]

func set_source(output_socket: OutputSocket) -> void:
	source = output_socket
