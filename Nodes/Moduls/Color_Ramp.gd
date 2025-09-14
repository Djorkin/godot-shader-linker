# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name ColorRampModule
extends ShaderModule

enum OptMode { LUT, CONST, LINEAR, EASE }

@export var opt_mode: int = OptMode.LUT

func _init() -> void:
	super._init()
	module_name = "Color Ramp"
	configure_input_sockets()
	configure_output_sockets()

func configure_input_sockets() -> void:
	input_sockets = [
		InputSocket.new("Fac", InputSocket.SocketType.FLOAT, 0.5),
	]

func configure_output_sockets() -> void:
	output_sockets = [
		OutputSocket.new("Color", OutputSocket.SocketType.VEC4),
		OutputSocket.new("Alpha", OutputSocket.SocketType.FLOAT),
	]
	for s in output_sockets:
		s.set_parent_module(self)

func get_include_files() -> Array[String]:
	return [PATHS.INC["COLOR_RAMP"]]

func get_uniform_definitions() -> Dictionary:
	var u := {}
	# Unlinked Fac
	for s in get_input_sockets():
		if s.source:
			continue
		u[s.name.to_lower()] = s.to_uniform()
	# Branch-specific uniforms
	match int(opt_mode):
		OptMode.CONST:
			u["edge"] = [ShaderSpec.ShaderType.FLOAT, 0.5]
			u["color1"] = [ShaderSpec.ShaderType.VEC4, Color(0,0,0,1), ShaderSpec.UniformHint.SOURCE_COLOR]
			u["color2"] = [ShaderSpec.ShaderType.VEC4, Color(1,1,1,1), ShaderSpec.UniformHint.SOURCE_COLOR]
		OptMode.LINEAR, OptMode.EASE:
			u["mulbias"] = [ShaderSpec.ShaderType.VEC3, Vector3(1.0, 0.0, 0.0)]
			u["color1"] = [ShaderSpec.ShaderType.VEC4, Color(0,0,0,1), ShaderSpec.UniformHint.SOURCE_COLOR]
			u["color2"] = [ShaderSpec.ShaderType.VEC4, Color(1,1,1,1), ShaderSpec.UniformHint.SOURCE_COLOR]
		OptMode.LUT:
			u["colormap"] = [ShaderSpec.ShaderType.SAMPLER2D]
			# lut_nearest не нужен как uniform в GLSL: выбираем ветку на этапе генерации
		_:
			pass
	u["opt_mode"] = [ShaderSpec.ShaderType.INT, opt_mode, ShaderSpec.UniformHint.ENUM, ["LUT","CONST","LINEAR","EASE"]]
	return u

func get_code_blocks() -> Dictionary:
	var active := get_active_output_sockets()
	if active.is_empty():
		return {}
	var uid := unique_id
	var outputs := get_output_vars()
	var args := get_input_args()
	var fac_expr := "0.5"
	if args.size() > 0:
		fac_expr = String(args[0])

	# Сформировать вызов внутри GEN-функций без if в GLSL
	var call_line := ""
	match int(opt_mode):
		OptMode.CONST:
			var p_edge = get_prefixed_name("edge")
			var p_c1 = get_prefixed_name("color1")
			var p_c2 = get_prefixed_name("color2")
			call_line = "\tvaltorgb_opti_constant(fac, %s, %s, %s, outcol, outa);" % [p_edge, p_c1, p_c2]
		OptMode.LINEAR:
			var p_mb = get_prefixed_name("mulbias")
			var p_c1l = get_prefixed_name("color1")
			var p_c2l = get_prefixed_name("color2")
			call_line = "\tvaltorgb_opti_linear(fac, vec2(%s.x, %s.y), %s, %s, outcol, outa);" % [p_mb, p_mb, p_c1l, p_c2l]
		OptMode.EASE:
			var p_mbe = get_prefixed_name("mulbias")
			var p_c1e = get_prefixed_name("color1")
			var p_c2e = get_prefixed_name("color2")
			call_line = "\tvaltorgb_opti_ease(fac, vec2(%s.x, %s.y), %s, %s, outcol, outa);" % [p_mbe, p_mbe, p_c1e, p_c2e]
		OptMode.LUT:
			var p_cm = get_prefixed_name("colormap")
			var use_nearest := false
			var ov = get_uniform_override("lut_nearest")
			if ov != null and typeof(ov) == TYPE_BOOL and ov:
				use_nearest = true
			if use_nearest:
				call_line = "\tvaltorgb_lut_nearest(fac, %s, outcol, outa);" % [p_cm]
			else:
				call_line = "\tvaltorgb_lut(fac, %s, outcol, outa);" % [p_cm]
		_:
			pass

	var tmpl_funcs := """
	// {module}: {uid} (GEN)
	vec4 color_ramp_{uid}(float fac) {{
		vec4 outcol; float outa;
{call}
		return outcol;
	}}
	float alpha_ramp_{uid}(float fac) {{
		vec4 outcol; float outa;
{call}
		return outa;
	}}
	"""
	var funcs_code := generate_code_block("functions", tmpl_funcs, {
		"module": module_name,
		"uid": uid,
		"call": call_line,
	})

	var out_col := outputs.get("Color", "color_%s" % uid)
	var out_a := outputs.get("Alpha", "alpha_%s" % uid)
	var tmpl_frag := """
	// {module}: {uid} (FRAG)
	vec4 {out_col} = color_ramp_{uid}({fac});
	float {out_a} = alpha_ramp_{uid}({fac});
	"""
	var frag_code := generate_code_block("fragment", tmpl_frag, {
		"module": module_name,
		"uid": uid,
		"out_col": out_col,
		"out_a": out_a,
		"fac": fac_expr,
	})

	return {
		"functions_color_ramp_%s" % uid: {"stage": "functions", "code": funcs_code},
		"fragment_color_ramp_%s" % uid: {"stage": "fragment", "code": frag_code},
	}

func set_uniform_override(name: String, value) -> void:
	if name == "opt_mode":
		opt_mode = int(value)
	super.set_uniform_override(name, value)
