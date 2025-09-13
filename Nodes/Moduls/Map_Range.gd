@tool
class_name MapRangeModule
extends ShaderModule


enum DataType { FLOAT, VECTOR }
enum Mode { LINEAR, STEPPED, SMOOTHSTEP, SMOOTHERSTEP }

@export_enum("Float","Vector") var data_type: int = DataType.FLOAT
@export_enum("Linear","Stepped","Smoothstep","Smootherstep") var mode: int = Mode.LINEAR
@export var clamp: bool = true


func _init() -> void:
	super._init()
	module_name = "Map Range"
	configure_input_sockets()
	configure_output_sockets()


func configure_input_sockets() -> void:
	var is_vec := int(data_type) == DataType.VECTOR
	input_sockets = []
	if is_vec:
		input_sockets.append(InputSocket.new("Vector", InputSocket.SocketType.VEC3, Vector3(0.0, 0.0, 0.0)))
		input_sockets.append(InputSocket.new("From Min", InputSocket.SocketType.VEC3, Vector3(0.0, 0.0, 0.0)))
		input_sockets.append(InputSocket.new("From Max", InputSocket.SocketType.VEC3, Vector3(1.0, 1.0, 1.0)))
		input_sockets.append(InputSocket.new("To Min", InputSocket.SocketType.VEC3, Vector3(0.0, 0.0, 0.0)))
		input_sockets.append(InputSocket.new("To Max", InputSocket.SocketType.VEC3, Vector3(1.0, 1.0, 1.0)))
	else:
		input_sockets.append(InputSocket.new("Value", InputSocket.SocketType.FLOAT, 0.0))
		input_sockets.append(InputSocket.new("From Min", InputSocket.SocketType.FLOAT, 0.0))
		input_sockets.append(InputSocket.new("From Max", InputSocket.SocketType.FLOAT, 1.0))
		input_sockets.append(InputSocket.new("To Min", InputSocket.SocketType.FLOAT, 0.0))
		input_sockets.append(InputSocket.new("To Max", InputSocket.SocketType.FLOAT, 1.0))
	if int(mode) == Mode.STEPPED:
		if is_vec:
			input_sockets.append(InputSocket.new("Steps", InputSocket.SocketType.VEC3, Vector3(4.0, 4.0, 4.0)))
		else:
			input_sockets.append(InputSocket.new("Steps", InputSocket.SocketType.FLOAT, 4.0))


func configure_output_sockets() -> void:
	output_sockets = []
	var is_vec := int(data_type) == DataType.VECTOR
	var out_type := OutputSocket.SocketType.FLOAT
	if is_vec:
		out_type = OutputSocket.SocketType.VEC3
	output_sockets.append(OutputSocket.new("Result", out_type))
	for s in output_sockets:
		s.set_parent_module(self)


func get_include_files() -> Array[String]:
	return []


func get_uniform_definitions() -> Dictionary:
	var u := {}
	u["data_type"] = [ShaderSpec.ShaderType.INT, data_type, ShaderSpec.UniformHint.ENUM, ["Float","Vector"]]
	u["mode"] = [ShaderSpec.ShaderType.INT, mode, ShaderSpec.UniformHint.ENUM, ["Linear","Stepped","Smoothstep","Smootherstep"]]
	u["clamp"] = [ShaderSpec.ShaderType.BOOL, clamp]
	for s in get_input_sockets():
		if s.source:
			continue
		u[s.name.to_lower().replace(" ", "_")] = s.to_uniform()
	return u


func get_code_blocks() -> Dictionary:
	var active := get_active_output_sockets()
	if active.is_empty():
		return {}
	var args := get_input_args()
	var uid := unique_id
	var is_vec := int(data_type) == DataType.VECTOR
	var is_steps := int(mode) == Mode.STEPPED

	var code := "\n// %s: %s (FRAG)\n" % [module_name, uid]

	if is_vec:
		var val := "vec3(0.0)"
		if args.size() > 0:
			val = String(args[0])
		var fmin := "vec3(0.0)"
		if args.size() > 1:
			fmin = String(args[1])
		var fmax := "vec3(1.0)"
		if args.size() > 2:
			fmax = String(args[2])
		var tmin := "vec3(0.0)"
		if args.size() > 3:
			tmin = String(args[3])
		var tmax := "vec3(1.0)"
		if args.size() > 4:
			tmax = String(args[4])
		var steps := "vec3(4.0)"
		if args.size() > 5:
			steps = String(args[5])
		var denom := "(%s) - (%s)" % [fmax, fmin]
		var denom_safe := "sign(%s) * max(abs(%s), vec3(1e-8))" % [denom, denom]
		var t := "((%s) - (%s)) / (%s)" % [val, fmin, denom_safe]
		var t_clamped := "clamp(%s, vec3(0.0), vec3(1.0))" % t
		var t_used := t
		if clamp:
			t_used = t_clamped
		var s_expr := "(%s*%s*%s*(%s*(%s*6.0 - 15.0) + 10.0))" % [t_used, t_used, t_used, t_used, t_used]
		if int(mode) == Mode.LINEAR:
			code += "vec3 out_%s = mix((%s), (%s), %s);\n" % [uid, tmin, tmax, t_used]
		elif int(mode) == Mode.STEPPED:
			var k := "max((%s), vec3(1.0))" % steps
			var ts := "(round(%s * ((%s) - vec3(1.0))) / max((%s) - vec3(1.0), vec3(1.0)))" % [t_used, k, k]
			code += "vec3 out_%s = mix((%s), (%s), %s);\n" % [uid, tmin, tmax, ts]
		elif int(mode) == Mode.SMOOTHSTEP:
			code += "vec3 out_%s = mix((%s), (%s), smoothstep(vec3(0.0), vec3(1.0), %s));\n" % [uid, tmin, tmax, t_used]
		else:
			code += "vec3 out_%s = mix((%s), (%s), %s);\n" % [uid, tmin, tmax, s_expr]
		if "Result" in active:
			var out_vec := get_output_vars().get("Result", "res_%s" % uid)
			code += "vec3 %s = out_%s;\n" % [out_vec, uid]
	else:
		var valf := "0.0"
		if args.size() > 0:
			valf = String(args[0])
		var fminf := "0.0"
		if args.size() > 1:
			fminf = String(args[1])
		var fmaxf := "1.0"
		if args.size() > 2:
			fmaxf = String(args[2])
		var tminf := "0.0"
		if args.size() > 3:
			tminf = String(args[3])
		var tmaxf := "1.0"
		if args.size() > 4:
			tmaxf = String(args[4])
		var stepsf := "4.0"
		if args.size() > 5:
			stepsf = String(args[5])
		var denomf := "(%s) - (%s)" % [fmaxf, fminf]
		var denomf_safe := "sign(%s) * max(abs(%s), 1e-8)" % [denomf, denomf]
		var tf := "((%s) - (%s)) / (%s)" % [valf, fminf, denomf_safe]
		var tf_clamped := "clamp(%s, 0.0, 1.0)" % tf
		var tf_used := tf
		if clamp:
			tf_used = tf_clamped
		var s_expr_f := "(%s*%s*%s*(%s*(%s*6.0 - 15.0) + 10.0))" % [tf_used, tf_used, tf_used, tf_used, tf_used]
		if int(mode) == Mode.LINEAR:
			code += "float out_%s = mix((%s), (%s), %s);\n" % [uid, tminf, tmaxf, tf_used]
		elif int(mode) == Mode.STEPPED:
			var kf := "max((%s), 1.0)" % stepsf
			var tsf := "(round(%s * ((%s) - 1.0)) / max((%s) - 1.0, 1.0))" % [tf_used, kf, kf]
			code += "float out_%s = mix((%s), (%s), %s);\n" % [uid, tminf, tmaxf, tsf]
		elif int(mode) == Mode.SMOOTHSTEP:
			code += "float out_%s = mix((%s), (%s), smoothstep(0.0, 1.0, %s));\n" % [uid, tminf, tmaxf, tf_used]
		else:
			code += "float out_%s = mix((%s), (%s), %s);\n" % [uid, tminf, tmaxf, s_expr_f]
		if "Result" in active:
			var out_val := get_output_vars().get("Result", "val_%s" % uid)
			code += "float %s = out_%s;\n" % [out_val, uid]

	return {"fragment_maprange_%s" % uid: {"stage": "fragment", "code": code}}


func set_uniform_override(name: String, value) -> void:
	if name == "data_type":
		var v := int(value)
		if v != data_type:
			data_type = v
			configure_input_sockets()
			configure_output_sockets()
	elif name == "mode":
		var m := int(value)
		if m != mode:
			mode = m
			configure_input_sockets()
	elif name == "clamp":
		clamp = bool(value)
	super.set_uniform_override(name, value)
