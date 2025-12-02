# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name ColorRampModule
extends ShaderModule

enum Mode { CONST, LINEAR }

@export var mode: int = Mode.LINEAR
@export var gradient: Gradient = Gradient.new()


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
	for socket in output_sockets:
		socket.set_parent_module(self)

func get_include_files() -> Array[String]:
	return [PATHS.INC["COLOR_RAMP"]]

func get_uniform_definitions() -> Dictionary:
	var uniforms := {}
	for socket in get_input_sockets():
		if socket.source:
			continue
		uniforms[socket.name.to_lower()] = socket.to_uniform()
	var hints := ["CONST", "LINEAR"]
	# opt_mode синхронизирован с локальным enum Mode и Gradient.interpolation_mode
	uniforms["opt_mode"] = [ShaderSpec.ShaderType.INT, mode, ShaderSpec.UniformHint.ENUM, hints]
	uniforms["colormap"] = [ShaderSpec.ShaderType.SAMPLER2D]
	return uniforms

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

	var call_line := ""
	var p_cm = get_prefixed_name("colormap")
	match int(mode):
		Mode.CONST:
			call_line = "\tvaltorgb_lut_nearest(fac, %s, outcol, outa);" % [p_cm]
		Mode.LINEAR:
			call_line = "\tvaltorgb_lut(fac, %s, outcol, outa);" % [p_cm]
		_:
			call_line = "\tvaltorgb_lut(fac, %s, outcol, outa);" % [p_cm]

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
		mode = int(value)
		if mode == Mode.CONST:
			gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		else:
			gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_LINEAR
	elif name == "mode":
		if String(value).to_upper() == "CONSTANT":
			mode = Mode.CONST
			gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		else:
			mode = Mode.LINEAR
			gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_LINEAR
	elif name == "stops":
		update_gradient_from_stops(value)
	else:
		super.set_uniform_override(name, value)

func update_gradient_from_stops(stops) -> void:
	if typeof(stops) != TYPE_ARRAY:
		return

	for stop in stops:
		if typeof(stop) != TYPE_ARRAY or stop.size() < 2:
			continue
		var pos_raw = stop[0]
		var col_raw = stop[1]
		var pos := float(pos_raw)

		var col := Color(1, 1, 1, 1)
		if typeof(col_raw) == TYPE_ARRAY and col_raw.size() >= 4:
			col = Color(col_raw[0], col_raw[1], col_raw[2], col_raw[3])

		gradient.add_point(pos, col)


func register_gradient_resource(builder: ShaderBuilder) -> void:
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 257
	var uniform_name := get_prefixed_name("colormap")
	builder.uniform_object_resources[uniform_name] = tex
