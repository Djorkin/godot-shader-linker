@tool
class_name TexWhiteNoiseModule
extends ShaderModule


enum DimensionType { D1, D2, D3, D4 }
@export_enum("1D", "2D", "3D", "4D") var dimensions: int = DimensionType.D3


func _init() -> void:
	super._init()
	module_name = "White Noise"
	input_sockets = [
		InputSocket.new("Vector", InputSocket.SocketType.VEC3, Vector3.ZERO),
		InputSocket.new("W", InputSocket.SocketType.FLOAT, 0.0),
	]
	output_sockets = [
		OutputSocket.new("Value", OutputSocket.SocketType.FLOAT),
		OutputSocket.new("Color", OutputSocket.SocketType.VEC4),
	]
	for s in output_sockets:
		s.set_parent_module(self)


func get_include_files() -> Array[String]:
	return [
		PATHS.INC["COORDS"],
		PATHS.INC["TEX_COORD"],
		PATHS.INC["BLENDER_HASH"],
	]


func get_uniform_definitions() -> Dictionary:
	var u: Dictionary = {}
	u["dimensions"] = [ShaderSpec.ShaderType.INT, dimensions, ShaderSpec.UniformHint.ENUM, ["1D", "2D", "3D", "4D"]]
	for s in get_input_sockets():
		if s.source:
			continue
		u[s.name.to_lower()] = s.to_uniform()
	return u


func get_code_blocks() -> Dictionary:
	var active := get_active_output_sockets()
	if active.is_empty():
		return {}

	var outputs := get_output_vars()
	var args := get_input_args()
	var uid := unique_id
	var blocks: Dictionary = {}

	var dims_i: int = int(dimensions)
	var dims_override = get_uniform_override("dimensions")
	if dims_override != null:
		dims_i = int(dims_override)

	var vector_expr := "vec3(0.0)"
	if dims_i != DimensionType.D1:
		var idx_vec := 0
		if input_sockets[idx_vec].source == null:
			var varying_name := "gen_vec_%s" % uid
			var global_decl := """
	varying vec3 %s;
	""" % varying_name
			var vertex_code := """
	// {module}: {uid} (VERTEX)
	{varying} = get_generated(VERTEX);
	""".format({
				"module": module_name,
				"uid": uid,
				"varying": varying_name,
			}).strip_edges()
			blocks["global_genvec_%s" % uid] = {"stage": "global", "code": global_decl}
			blocks["vertex_%s" % uid] = {"stage": "vertex", "code": vertex_code}
			vector_expr = varying_name
		else:
			vector_expr = String(args[0])

	var w_expr := String(args[1])

	var frag_code := "\n// %s: %s (FRAG)\n" % [module_name, uid]
	match dims_i:
		DimensionType.D1:
			frag_code += "float value_%s = hash_float_to_float(%s);\n" % [uid, w_expr]
			frag_code += "vec3 color_rgb_%s = vec3(hash_float_to_float(%s), hash_vec2_to_float(vec2(%s, 1.0)), hash_vec2_to_float(vec2(%s, 2.0)));\n" % [uid, w_expr, w_expr, w_expr]
		DimensionType.D2:
			frag_code += "vec2 v2_%s = %s.xy;\n" % [uid, vector_expr]
			frag_code += "float value_%s = hash_vec2_to_float(v2_%s);\n" % [uid, uid]
			frag_code += "vec3 color_rgb_%s = vec3(hash_vec2_to_float(v2_%s), hash_vec3_to_float(vec3(v2_%s, 1.0)), hash_vec3_to_float(vec3(v2_%s, 2.0)));\n" % [uid, uid, uid, uid]
		DimensionType.D3:
			frag_code += "float value_%s = hash_vec3_to_float(%s);\n" % [uid, vector_expr]
			frag_code += "vec3 color_rgb_%s = hash_vec3_to_vec3(%s);\n" % [uid, vector_expr]
		_:
			frag_code += "vec4 v4_%s = vec4(%s, %s);\n" % [uid, vector_expr, w_expr]
			frag_code += "float value_%s = hash_vec4_to_float(v4_%s);\n" % [uid, uid]
			frag_code += "vec3 color_rgb_%s = hash_vec4_to_vec4(v4_%s).rgb;\n" % [uid, uid]

	if "Value" in active:
		var out_val := outputs.get("Value", "value_%s" % uid)
		frag_code += "float %s = value_%s;\n" % [out_val, uid]
	if "Color" in active:
		var out_col := outputs.get("Color", "color_%s" % uid)
		frag_code += "vec4 %s = vec4(color_rgb_%s, 1.0);\n" % [out_col, uid]

	blocks["fragment_white_noise_%s" % uid] = {"stage": "fragment", "code": frag_code}
	return blocks


func get_required_instance_uniforms() -> Array[int]:
	var idx_vec := 0
	if dimensions != DimensionType.D1 and input_sockets.size() > 0 and input_sockets[idx_vec].source == null:
		return [ShaderSpec.InstanceUniform.BBOX]
	return []


func get_compile_defines() -> Array[String]:
	var defs: Array[String] = []
	if input_sockets.size() > 0 and input_sockets[0].source == null and dimensions != DimensionType.D1:
		defs.append("NEED_AABB")
	return defs
