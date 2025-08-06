# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name SocketCompatibility
extends RefCounted


const COMPATIBLE: Dictionary = {
	"float": {
		"float": "{v}",
		"vec2": "vec2({v})",
		"vec3": "vec3({v})",
		"vec4": "vec4({v}, {v}, {v}, 1.0)",
		"Material": "material_from_color(vec4({v}, {v}, {v}, 1.0))",
	},
	"vec2": {
		"vec2": "{v}",
		"vec3": "vec3({v}.x, {v}.y, 0.0)",
		"vec4": "vec4({v}.x, {v}.y, 0.0, 1.0)",
		"float": "{v}.x",
		"Material": "material_from_color(vec4({v}, 0.0, 1.0))",
	},
	"vec3": {
		"vec3": "{v}",
		"vec4": "vec4({v}, 1.0)",
		"float": "{v}.x",
		"Material": "material_from_color(vec4({v}, 1.0))",
	},
	"vec4": {
		"vec4": "{v}",
		"vec3": "({v}).xyz",
		"float": "{v}.x",
		"Material": "material_from_color({v})",
	},
	"sampler2D": {
		"sampler2D": "{v}",
	},
	"Material": {
		"Material": "{v}",
	},
}

static func is_compatible(from_type: String, to_type: String) -> bool:
	return COMPATIBLE.has(from_type) and COMPATIBLE[from_type].has(to_type)

static func convert(expr: String, from_type: String, to_type: String) -> String:
	if from_type == to_type:
		return expr
	if not is_compatible(from_type, to_type):
		return expr
	return COMPATIBLE[from_type][to_type].format({"v": expr})
