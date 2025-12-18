# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

class_name ShaderSpec

enum ShaderType { INT, FLOAT, BOOL, VEC3, VEC4, SAMPLER2D }
enum UniformHint { NONE, RANGE, ENUM, SOURCE_COLOR, SCREEN_TEXTURE, CUSTOM }
enum Stage { GLOBAL, FUNCTIONS, VERTEX, FRAGMENT }
enum SharedVar { WORLD_POS, WORLD_NORMAL, VIEW_POS, VIEW_NORMAL, WORLD_UV, OBJECT_NORMAL }
enum InstanceUniform { BBOX }

static func format_uniform_hint(hint, hint_params) -> String:
	if typeof(hint) == TYPE_STRING:
		var s: String = hint
		return s.strip_edges()

	if typeof(hint) != TYPE_INT:
		return ""

	match int(hint):
		UniformHint.NONE:
			return ""
		UniformHint.RANGE:
			var mn := 0.0
			var mx := 1.0
			var st := 0.01
			if typeof(hint_params) == TYPE_DICTIONARY:
				mn = float(hint_params.get("min", mn))
				mx = float(hint_params.get("max", mx))
				st = float(hint_params.get("step", st))
			elif typeof(hint_params) == TYPE_ARRAY and hint_params.size() >= 2:
				mn = float(hint_params[0])
				mx = float(hint_params[1])
				if hint_params.size() >= 3:
					st = float(hint_params[2])
			return "hint_range(%s,%s,%s)" % [mn, mx, st]
		UniformHint.ENUM:
			if typeof(hint_params) == TYPE_ARRAY and hint_params.size() > 0:
				var quoted: Array[String] = []
				for v in hint_params:
					quoted.append("\"%s\"" % str(v))
				return "hint_enum(%s)" % ",".join(quoted)
			return ""
		UniformHint.SOURCE_COLOR:
			return "source_color"
		UniformHint.SCREEN_TEXTURE:
			return "hint_screen_texture"
		UniformHint.CUSTOM:
			if typeof(hint_params) == TYPE_STRING:
				return (hint_params as String).strip_edges()
			return ""
		_:
			return ""

static func format_uniform_value(value, type: String) -> String:
	match typeof(value):
		TYPE_VECTOR3:
			var v3: Vector3 = value
			return "vec3(%s, %s, %s)" % [v3.x, v3.y, v3.z]
		TYPE_VECTOR4:
			var v4: Vector4 = value
			return "vec4(%s, %s, %s, %s)" % [v4.x, v4.y, v4.z, v4.w]
		TYPE_COLOR:
			var c: Color = value
			return "vec4(%s, %s, %s, %s)" % [c.r, c.g, c.b, c.a]
		TYPE_FLOAT:
			return "%s" % value
		TYPE_INT:
			return "%d" % value
		TYPE_BOOL:
			if value:
				return "true"
			return "false"
		_:
			return str(value)

static func shader_type_to_glsl(type: int) -> String:
	match type:
		ShaderType.INT:
			return "int"
		ShaderType.FLOAT:
			return "float"
		ShaderType.BOOL:
			return "bool"
		ShaderType.VEC3:
			return "vec3"
		ShaderType.VEC4:
			return "vec4"
		ShaderType.SAMPLER2D:
			return "sampler2D"
		_:
			return ""

static func decode_uniform_spec(spec) -> Dictionary:
	if typeof(spec) != TYPE_ARRAY:
		return {}
	var arr: Array = spec
	if arr.size() == 0:
		return {}

	var type_str = shader_type_to_glsl(int(arr[0]))
	var def_val = null
	var hint_val = null
	var hint_params = null

	if arr.size() >= 2:
		def_val = arr[1]
	if arr.size() >= 3:
		hint_val = arr[2]
	if arr.size() >= 4:
		hint_params = arr[3]

	return {
		"type": type_str,
		"default": def_val,
		"hint": hint_val,
		"hint_params": hint_params,
	}

static func stage_from(stage) -> int:
	var stage_enum := Stage.FRAGMENT
	match typeof(stage):
		TYPE_STRING:
			var stage_str := (stage as String).to_lower()
			match stage_str:
				"global":
					stage_enum = Stage.GLOBAL
				"functions":
					stage_enum = Stage.FUNCTIONS
				"vertex":
					stage_enum = Stage.VERTEX
				"fragment":
					stage_enum = Stage.FRAGMENT
				_:
					stage_enum = Stage.FRAGMENT
		TYPE_INT:
			stage_enum = int(stage)
		_:
			stage_enum = Stage.FRAGMENT
	return stage_enum

static func stage_function_name(stage_enum: int) -> String:
	if stage_enum == Stage.VERTEX:
		return "vertex"
	if stage_enum == Stage.FRAGMENT:
		return "fragment"
	return "fragment"

static func shared_var_name(var_enum: int) -> String:
	match var_enum:
		SharedVar.WORLD_POS:
			return "sv_world_pos"
		SharedVar.WORLD_NORMAL:
			return "sv_world_normal"
		SharedVar.VIEW_POS:
			return "sv_view_pos"
		SharedVar.VIEW_NORMAL:
			return "sv_view_normal"
		SharedVar.WORLD_UV:
			return "sv_world_uv"
		SharedVar.OBJECT_NORMAL:
			return "sv_object_normal"
		_:
			return ""
