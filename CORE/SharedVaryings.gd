# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name SharedVaryings
extends Object

static var DEFINITIONS := {
	"world_uv": {
		"type": "vec2",
		"vertex_code": "v_world_uv = UV;"
	},
}

# Утилита: вернуть описание по ключу (или null)
static func get_definition(key: String) -> Dictionary:
	return DEFINITIONS.get(key, {}) 
