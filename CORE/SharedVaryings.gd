# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name SharedVaryings
extends Object

static var DEFINITIONS := {
	"world_normal": {
		"type": "vec3",
		"vertex_code": """#ifdef WORLD_VERTEX_COORDS\n\tvec3 _world_nrm_tmp = normalize((inverse(MODEL_MATRIX) * vec4(NORMAL, 0.0)).xyz);\n\tv_world_normal = _world_nrm_tmp.xzy;\n#else\n\tv_world_normal = NORMAL.xzy;\n#endif"""
	},
	"world_uv": {
		"type": "vec2",
		"vertex_code": "v_world_uv = UV;"
	},
}

# Утилита: вернуть описание по ключу (или null)
static func get_definition(key: String) -> Dictionary:
	return DEFINITIONS.get(key, {}) 
