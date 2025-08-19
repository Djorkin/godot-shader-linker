# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name SharedVaryings

# Централизованные shared varying на сессию сборки: фиксированные имена, без UID.

var requested := {}
var decl_lines: Array[String] = []
var vertex_lines: Array[String] = []
var ctxInjected := false


func reset() -> void:
	requested.clear()
	decl_lines.clear()
	vertex_lines.clear()
	ctxInjected = false


const VARS := {
	"world_pos": {
		"type": "vec3",
		"name": "sv_world_pos",
		"v_assign": "sv_world_pos = obj_to_world_pos_ctx(VERTEX, svCtx);",
		"needs_ctx": true,
	},
	"world_normal": {
		"type": "vec3",
		"name": "sv_world_normal",
		"v_assign": "sv_world_normal = obj_to_world_normal_ctx(NORMAL, svCtx);",
		"needs_ctx": true,
	},
	"view_pos": {
		"type": "vec3",
		"name": "sv_view_pos",
		"v_assign": "sv_view_pos = obj_to_view_pos_ctx(VERTEX, svCtx);",
		"needs_ctx": true,
	},
	"view_normal": {
		"type": "vec3",
		"name": "sv_view_normal",
		"v_assign": "sv_view_normal = obj_to_view_normal_ctx(NORMAL, svCtx);",
		"needs_ctx": true,
	},
	"world_uv": {
		"type": "vec2",
		"name": "sv_world_uv",
		"v_assign": "sv_world_uv = UV;",
		"needs_ctx": false,
	},
}

func request(keys: Array) -> Dictionary:
	var out := {}
	for key in keys:
		if not VARS.has(key):
			continue
		var def: Dictionary = VARS[key]
		out[key] = def["name"]
		if requested.has(key):
			continue
		requested[key] = true
		if def.get("needs_ctx", false) and not ctxInjected:
			vertex_lines.append("TransformCtx svCtx = make_ctx(MODEL_MATRIX, MODEL_NORMAL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX, INV_PROJECTION_MATRIX);")
			ctxInjected = true
		decl_lines.append("varying %s %s;" % [def["type"], def["name"]])
		vertex_lines.append(def["v_assign"])
	return out

func build_global_declarations() -> String:
	if decl_lines.is_empty():
		return ""
	return "// SHARED VARYINGS\n\n" + "\n".join(decl_lines) + "\n"

func build_vertex_code() -> String:
	if vertex_lines.is_empty():
		return ""
	return "// SHARED VARYINGS (VERTEX)\n" + "\n".join(vertex_lines) + "\n"

func get_var_name(key: String) -> String:
	if not VARS.has(key):
		return ""
	return VARS[key]["name"]
