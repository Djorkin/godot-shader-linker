# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name OutputSocket
extends RefCounted

enum SocketType {VEC2,VEC3, VEC4, FLOAT, SHADER}
const TYPE_NAMES = {
	SocketType.VEC2: "vec2",
	SocketType.VEC3: "vec3",
	SocketType.VEC4: "vec4",
	SocketType.FLOAT: "float",
	SocketType.SHADER: "Material"
}

var name: String
var type: SocketType
var description: String
var parent_module: ShaderModule


func _init(socket_name: String, type: SocketType, desc: String = "") -> void:
	name = socket_name
	self.type = type
	description = desc

func type_name() -> String:
	return TYPE_NAMES.get(type, "vec3")

func declaration(var_name: String) -> String:
	return "%s %s" % [type_name(), var_name]

func set_parent_module(module: ShaderModule) -> void:
	parent_module = module
