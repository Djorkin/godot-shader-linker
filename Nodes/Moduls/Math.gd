# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name MathModule
extends ShaderModule


enum Operation {
	ADD,
	SUBTRACT,
	MULTIPLY,
	DIVIDE,
	MULTIPLY_ADD,
	POWER,
	LOGARITHM,
	SQRT,
	INVERSE_SQRT,
	ABSOLUTE,
	EXPONENT,
	SINE,
	COSINE,
	TANGENT,
	FLOOR,
	CEIL,
	FRACT,
	MINIMUM,
	MAXIMUM,
	LESS_THAN,
	GREATER_THAN,
	SIGN,
	MODULO,
	TRUNCATED_MODULO,
	FLOORED_MODULO,
	WRAP,
	SNAP,
	PINGPONG,
	ATAN2,
	COMPARE,
	ROUND,
	TRUNCATE,
	SMOOTH_MINIMUM,
	SMOOTH_MAXIMUM,
	ARCSINE,
	ARCCOSINE,
	ARCTANGENT,
	HYPERBOLIC_SINE,
	HYPERBOLIC_COSINE,
	HYPERBOLIC_TANGENT,
	TO_RADIANS,
	TO_DEGREES,
}
@export_enum(
	"Add",
	"Subtract",
	"Multiply",
	"Divide",
	"Multiply Add",
	"Power",
	"Logarithm",
	"Square Root",
	"Inverse Square Root",
	"Absolute",
	"Exponent",
	"Sine",
	"Cosine",
	"Tangent",
	"Floor",
	"Ceil",
	"Fract",
	"Minimum",
	"Maximum",
	"Less Than",
	"Greater Than",
	"Sign",
	"Modulo",
	"Truncated Modulo",
	"Floored Modulo",
	"Wrap",
	"Snap",
	"PingPong",
	"Arctan2",
	"Compare",
	"Round",
	"Truncate",
	"Smooth Minimum",
	"Smooth Maximum",
	"Arcsine",
	"Arccosine",
	"Arctangent",
	"Hyperbolic Sine",
	"Hyperbolic Cosine",
	"Hyperbolic Tangent",
	"To Radians",
	"To Degrees"
) var operation: int = Operation.ADD

@export var clamp_result: bool = false


func _init() -> void:
	super._init()
	module_name = "Math"
	configure_input_sockets()
	configure_output_sockets()


func configure_input_sockets() -> void:
	input_sockets = [
		InputSocket.new("A", InputSocket.SocketType.FLOAT, 0.0),
		InputSocket.new("B", InputSocket.SocketType.FLOAT, 0.0),
	]
	var needs_c := false
	var c_default := 0.0
	match operation:
		Operation.MULTIPLY_ADD:
			needs_c = true
			c_default = 0.0
		Operation.COMPARE:
			needs_c = true
			c_default = 0.001
		Operation.WRAP:
			needs_c = true
			c_default = 1.0
			# Для WRAP зададим более подходящие дефолты для B(min) и C(max)
			input_sockets[1] = InputSocket.new("B", InputSocket.SocketType.FLOAT, 0.0)
		Operation.SMOOTH_MINIMUM, Operation.SMOOTH_MAXIMUM:
			needs_c = true
			c_default = 1.0
		_:
			pass
	if needs_c:
		input_sockets.append(InputSocket.new("C", InputSocket.SocketType.FLOAT, c_default))


func configure_output_sockets() -> void:
	output_sockets = [
		OutputSocket.new("Value", OutputSocket.SocketType.FLOAT),
	]
	for s in output_sockets:
		s.set_parent_module(self)


func get_include_files() -> Array[String]:
	return [PATHS.INC["MATH"]]


func get_uniform_definitions() -> Dictionary:
	var u := {}
	u["operation"] = [ShaderSpec.ShaderType.INT, operation, ShaderSpec.UniformHint.ENUM, [
		"Add","Subtract","Multiply","Divide","Multiply Add","Power","Logarithm","Square Root","Inverse Square Root","Absolute","Exponent",
		"Sine","Cosine","Tangent","Floor","Ceil","Fract","Minimum","Maximum","Less Than","Greater Than","Sign","Modulo",
		"Truncated Modulo","Floored Modulo","Wrap","Snap","PingPong","Arctan2","Compare","Round","Truncate","Smooth Minimum","Smooth Maximum",
		"Arcsine","Arccosine","Arctangent","Hyperbolic Sine","Hyperbolic Cosine","Hyperbolic Tangent","To Radians","To Degrees"
	]]
	u["clamp_result"] = [ShaderSpec.ShaderType.BOOL, clamp_result]

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
	var inputs := get_input_args()
	var uid := unique_id
	var val_var := outputs.get("Value", "value_%s" % uid)

	var a := "0.0"
	if inputs.size() >= 1:
		a = String(inputs[0])
	var b := "0.0"
	if inputs.size() >= 2:
		b = String(inputs[1])
	var c := "0.0"
	if inputs.size() >= 3:
		c = String(inputs[2])

	var expr := get_expr(a, b, c)
	var cr := get_prefixed_name("clamp_result")

	var frag_code := """
// {module}: {uid} (FRAG)
float {out} = {expr};
{out} = {cr} ? clamp({out}, 0.0, 1.0) : {out};
""".format({
		"module": module_name,
		"uid": uid,
		"out": val_var,
		"expr": expr,
		"cr": cr,
	})

	return {"fragment_math_%s" % uid: {"stage": "fragment", "code": frag_code}}


func get_expr(a: String, b: String, c: String = "0.0") -> String:
	match int(operation):
		Operation.ADD:
			return "(%s + %s)" % [a, b]
		Operation.SUBTRACT:
			return "(%s - %s)" % [a, b]
		Operation.MULTIPLY:
			return "(%s * %s)" % [a, b]
		Operation.DIVIDE:
			return "(%s / %s)" % [a, b]
		Operation.MULTIPLY_ADD:
			return "((%s * %s) + %s)" % [a, b, c]
		Operation.POWER:
			return "pow(%s, %s)" % [a, b]
		Operation.LOGARITHM:
			return "log(max(%s, 1e-8))" % [a]
		Operation.SQRT:
			return "sqrt(max(%s, 0.0))" % [a]
		Operation.INVERSE_SQRT:
			return "inversesqrt(max(%s, 1e-8))" % [a]
		Operation.ABSOLUTE:
			return "abs(%s)" % [a]
		Operation.EXPONENT:
			return "exp(%s)" % [a]
		# Trigonometric (одноарг.)
		Operation.SINE:
			return "sin(%s)" % [a]
		Operation.COSINE:
			return "cos(%s)" % [a]
		Operation.TANGENT:
			return "tan(%s)" % [a]
		# Rounding
		Operation.ROUND:
			return "round(%s)" % [a]
		Operation.FLOOR:
			return "floor(%s)" % [a]
		Operation.CEIL:
			return "ceil(%s)" % [a]
		Operation.TRUNCATE:
			return "trunc(%s)" % [a]
		Operation.FRACT:
			return "fract(%s)" % [a]
		# Comparison (2-arg / 3-arg)
		Operation.MINIMUM:
			return "min(%s, %s)" % [a, b]
		Operation.MAXIMUM:
			return "max(%s, %s)" % [a, b]
		Operation.LESS_THAN:
			return "((%s) < (%s) ? 1.0 : 0.0)" % [a, b]
		Operation.GREATER_THAN:
			return "((%s) > (%s) ? 1.0 : 0.0)" % [a, b]
		Operation.SIGN:
			return "sign(%s)" % [a]
		Operation.COMPARE:
			return "(abs((%s) - (%s)) <= abs(%s) ? 1.0 : 0.0)" % [a, b, c]
		Operation.SMOOTH_MINIMUM:
			return "(min(%s, %s) - (max(abs(%s) - abs((%s) - (%s)), 0.0) * max(abs(%s) - abs((%s) - (%s)), 0.0)) / (4.0 * max(abs(%s), 1e-8)))" % [a, b, c, a, b, c, a, b, c, a]
		Operation.SMOOTH_MAXIMUM:
			return "(max(%s, %s) + (max(abs(%s) - abs((%s) - (%s)), 0.0) * max(abs(%s) - abs((%s) - (%s)), 0.0)) / (4.0 * max(abs(%s), 1e-8)))" % [a, b, c, a, b, c, a, b, c, a]
		# Modulo / step-like
		Operation.MODULO:
			return "mod(%s, %s)" % [a, b]
		Operation.TRUNCATED_MODULO:
			return "((%s) - (%s) * trunc((%s)/max(%s, 1e-8)))" % [a, b, a, b]
		Operation.FLOORED_MODULO:
			return "((%s) - (%s) * floor((%s)/max(%s, 1e-8)))" % [a, b, a, b]
		Operation.WRAP:
			return "(mod((%s) - (%s), max((%s) - (%s), 1e-8)) + (%s))" % [a, b, c, b, b]
		Operation.SNAP:
			return "((abs(%s) < 1e-8) ? 0.0 : (floor((%s) / max(abs(%s), 1e-8) + 0.5) * max(abs(%s), 1e-8)))" % [b, a, b, b]
		Operation.PINGPONG:
			return "((abs(%s) < 1e-8) ? 0.0 : (abs(%s) - abs(mod(%s, 2.0*abs(%s)) - abs(%s))))" % [b, b, a, b, b]
		# Angle with two args
		Operation.ATAN2:
			return "atan(%s, %s)" % [a, b]
		# New trigonometric & conversions
		Operation.ARCSINE:
			return "asin(%s)" % [a]
		Operation.ARCCOSINE:
			return "acos(%s)" % [a]
		Operation.ARCTANGENT:
			return "atan(%s)" % [a]
		Operation.HYPERBOLIC_SINE:
			return "(0.5 * (exp(%s) - exp(-(%s))))" % [a, a]
		Operation.HYPERBOLIC_COSINE:
			return "(0.5 * (exp(%s) + exp(-(%s))))" % [a, a]
		Operation.HYPERBOLIC_TANGENT:
			return "((exp(2.0*(%s)) - 1.0) / (exp(2.0*(%s)) + 1.0))" % [a, a]
		Operation.TO_RADIANS:
			return "radians(%s)" % [a]
		Operation.TO_DEGREES:
			return "degrees(%s)" % [a]

		_:
			return String(a)


func set_uniform_override(name: String, value) -> void:
	match name:
		"use_clamp":
			name = "clamp_result"
		"c":
			name = "c"
		_:
			pass
	if name == "operation":
		var new_op := int(value)
		if new_op != operation:
			operation = new_op
			configure_input_sockets()
	super.set_uniform_override(name, value)
