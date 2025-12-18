# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name SharedVaryings

# Centralized shared varyings for the build session: fixed names, no UID.

var requested := {}
var decl_lines: Array[String] = []
var vertex_lines: Array[String] = []
var fragment_lines: Array[String] = []
var ctxInjected := false
var ctxInjectedFrag := false


func reset() -> void:
	requested.clear()
	decl_lines.clear()
	vertex_lines.clear()
	fragment_lines.clear()
	ctxInjected = false
	ctxInjectedFrag = false


var VARS := {
	ShaderSpec.SharedVar.WORLD_POS: {
		"type": "vec3",
		"name": ShaderSpec.shared_var_name(ShaderSpec.SharedVar.WORLD_POS),
		"v_assign": "%s = obj_to_world_pos_ctx(VERTEX, svCtx);" % ShaderSpec.shared_var_name(ShaderSpec.SharedVar.WORLD_POS),
		"needs_ctx": true,
	},
	ShaderSpec.SharedVar.WORLD_NORMAL: {
		"type": "vec3",
		"name": ShaderSpec.shared_var_name(ShaderSpec.SharedVar.WORLD_NORMAL),
		"v_assign": "%s = obj_to_world_normal_ctx(NORMAL, svCtx);" % ShaderSpec.shared_var_name(ShaderSpec.SharedVar.WORLD_NORMAL),
		"needs_ctx": true,
	},
	ShaderSpec.SharedVar.VIEW_POS: {
		"type": "vec3",
		"name": ShaderSpec.shared_var_name(ShaderSpec.SharedVar.VIEW_POS),
		"v_assign": "%s = obj_to_view_pos_ctx(VERTEX, svCtx);" % ShaderSpec.shared_var_name(ShaderSpec.SharedVar.VIEW_POS),
		"needs_ctx": true,
	},
	ShaderSpec.SharedVar.VIEW_NORMAL: {
		"type": "vec3",
		"name": ShaderSpec.shared_var_name(ShaderSpec.SharedVar.VIEW_NORMAL),
		"v_assign": "%s = obj_to_view_normal_ctx(NORMAL, svCtx);" % ShaderSpec.shared_var_name(ShaderSpec.SharedVar.VIEW_NORMAL),
		"needs_ctx": true,
	},
	ShaderSpec.SharedVar.WORLD_UV: {
		"type": "vec2",
		"name": ShaderSpec.shared_var_name(ShaderSpec.SharedVar.WORLD_UV),
		"v_assign": "%s = UV;" % ShaderSpec.shared_var_name(ShaderSpec.SharedVar.WORLD_UV),
		"needs_ctx": false,
	},
	ShaderSpec.SharedVar.OBJECT_NORMAL: {
		"type": "vec3",
		"name": ShaderSpec.shared_var_name(ShaderSpec.SharedVar.OBJECT_NORMAL),
		"v_assign": "%s = NORMAL;" % ShaderSpec.shared_var_name(ShaderSpec.SharedVar.OBJECT_NORMAL),
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
		if def.get("needs_ctx", false) and not ctxInjectedFrag:
			fragment_lines.append("TransformCtx svCtx = make_ctx(MODEL_MATRIX, MODEL_NORMAL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX, INV_PROJECTION_MATRIX);")
			ctxInjectedFrag = true
		decl_lines.append("varying %s %s;" % [def["type"], def["name"]])
		vertex_lines.append(def["v_assign"])
	return out

func build_global_declarations() -> String:
	if decl_lines.is_empty():
		return ""
	return "\n".join(decl_lines)

func build_vertex_code() -> String:
	if vertex_lines.is_empty():
		return ""
	return "// SHARED VARYINGS (VERTEX)\n" + "\n".join(vertex_lines) + "\n"

func build_fragment_code() -> String:
	if fragment_lines.is_empty():
		return ""
	return "// SHARED VARYINGS (FRAGMENT)\n" + "\n".join(fragment_lines) + "\n"

func get_var_name(key: int) -> String:
	if not VARS.has(key):
		return ""
	return VARS[key]["name"]
