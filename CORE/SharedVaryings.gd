# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name SharedVaryings
extends Object

# Централизованные shared varying: фиксированные имена, без UID.
# Модули запрашивают нужные ключи, а мы генерируем объявления и vertex-код один раз.

const VARS := {
	"world_pos": {
		"type": "vec3",
		"name": "sv_world_pos",
		"v_assign": "sv_world_pos = obj_to_world_pos_ctx(VERTEX, make_ctx(MODEL_MATRIX, MODEL_NORMAL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX, INV_PROJECTION_MATRIX));",
	},
	"world_normal": {
		"type": "vec3",
		"name": "sv_world_normal",
		"v_assign": "sv_world_normal = obj_to_world_normal_ctx(NORMAL, make_ctx(MODEL_MATRIX, MODEL_NORMAL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX, INV_PROJECTION_MATRIX));",
	},
	"view_pos": {
		"type": "vec3",
		"name": "sv_view_pos",
		"v_assign": "sv_view_pos = obj_to_view_pos_ctx(VERTEX, make_ctx(MODEL_MATRIX, MODEL_NORMAL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX, INV_PROJECTION_MATRIX));",
	},
	"view_normal": {
		"type": "vec3",
		"name": "sv_view_normal",
		"v_assign": "sv_view_normal = obj_to_view_normal_ctx(NORMAL, make_ctx(MODEL_MATRIX, MODEL_NORMAL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX, INV_PROJECTION_MATRIX));",
	},
	"world_uv": {
		"type": "vec2",
		"name": "sv_world_uv",
		"v_assign": "sv_world_uv = UV;",
	},
}

static var _session_builder_id: int = -1
static var _requested: = {}
static var _decl_lines: Array[String] = []
static var _vertex_lines: Array[String] = []

static func reset() -> void:
	_session_builder_id = -1
	_requested.clear()
	_decl_lines.clear()
	_vertex_lines.clear()

static func _ensure_session(builder: Object) -> void:
	var bid := 0
	if builder != null and builder is Object:
		bid = builder.get_instance_id()
	if bid != _session_builder_id:
		reset()
		_session_builder_id = bid

# Запросить общий набор varying; возвращает mapping ключ->имя переменной
static func request(keys: Array, builder: Object = null) -> Dictionary:
	_ensure_session(builder)
	var out := {}
	for key in keys:
		if not VARS.has(key):
			continue
		var def: Dictionary = VARS[key]
		out[key] = def["name"]
		if _requested.has(key):
			continue
		_requested[key] = true
		_decl_lines.append("varying %s %s;" % [def["type"], def["name"]])
		_vertex_lines.append(def["v_assign"])
	return out

static func build_global_declarations() -> String:
	if _decl_lines.is_empty():
		return ""
	return "// SHARED VARYINGS\n\n" + "\n".join(_decl_lines) + "\n"

static func build_vertex_code() -> String:
	if _vertex_lines.is_empty():
		return ""
	return "// SHARED VARYINGS (VERTEX)\n" + "\n".join(_vertex_lines) + "\n"

static func get_var_name(key: String) -> String:
	if not VARS.has(key):
		return ""
	return VARS[key]["name"] 
