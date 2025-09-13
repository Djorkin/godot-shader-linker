# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name VectorMathModule
extends ShaderModule


enum Operation {
	ADD,
	SUBTRACT,
	MULTIPLY,
	DIVIDE,
	MULTIPLY_ADD,
	CROSS_PRODUCT,
	PROJECT,
	REFLECT,
	REFRACT,
	FACEFORWARD,
	DOT_PRODUCT,
	DISTANCE,
	LENGTH,
	SCALE,
	NORMALIZE,
	ABSOLUTE,
	POWER,
	SIGN,
	MINIMUM,
	MAXIMUM,
	FLOOR,
	CEIL,
	FRACTION,
	MODULO,
	WRAP,
	SNAP,
	SINE,
	COSINE,
	TANGENT,
}

@export_enum(
	"Add",
	"Subtract",
	"Multiply",
	"Divide",
	"Multiply Add",
	"Cross Product",
	"Project",
	"Reflect",
	"Refract",
	"Faceforward",
	"Dot Product",
	"Distance",
	"Length",
	"Scale",
	"Normalize",
	"Absolute",
	"Power",
	"Sign",
	"Minimum",
	"Maximum",
	"Floor",
	"Ceil",
	"Fraction",
	"Modulo",
	"Wrap",
	"Snap",
	"Sine",
	"Cosine",
	"Tangent"
) var operation: int = Operation.ADD


func _init() -> void:
	super._init()
	module_name = "Vector Math"
	configure_input_sockets()
	configure_output_sockets()


func configure_input_sockets() -> void:
	input_sockets = [
		InputSocket.new("A", InputSocket.SocketType.VEC3, Vector3(0.0, 0.0, 0.0)),
	]
	var op := int(operation)
	var unary_ops := PackedInt32Array([
		Operation.NORMALIZE,
		Operation.LENGTH,
		Operation.ABSOLUTE,
		Operation.SIGN,
		Operation.FLOOR,
		Operation.CEIL,
		Operation.FRACTION,
		Operation.SINE,
		Operation.COSINE,
		Operation.TANGENT,
	])
	var ternary_ops := PackedInt32Array([
		Operation.MULTIPLY_ADD,
		Operation.REFRACT,
		Operation.FACEFORWARD,
		Operation.WRAP,
	])
	if op in unary_ops:
		pass
	elif op == Operation.SCALE:
		input_sockets.append(InputSocket.new("B", InputSocket.SocketType.FLOAT, 1.0))
	elif op in [
		Operation.ADD,
		Operation.SUBTRACT,
		Operation.MULTIPLY,
		Operation.DIVIDE,
		Operation.CROSS_PRODUCT,
		Operation.PROJECT,
		Operation.REFLECT,
		Operation.DOT_PRODUCT,
		Operation.DISTANCE,
		Operation.MINIMUM,
		Operation.MAXIMUM,
		Operation.MODULO,
		Operation.POWER,
		Operation.SNAP,
	]:
		input_sockets.append(InputSocket.new("B", InputSocket.SocketType.VEC3, Vector3(0.0, 0.0, 0.0)))
	elif op in ternary_ops:
		match op:
			Operation.REFRACT:
				input_sockets.append(InputSocket.new("B", InputSocket.SocketType.VEC3, Vector3(0.0, 0.0, 0.0)))
				input_sockets.append(InputSocket.new("C", InputSocket.SocketType.FLOAT, 1.45))
			Operation.FACEFORWARD:
				input_sockets.append(InputSocket.new("B", InputSocket.SocketType.VEC3, Vector3(0.0, 0.0, 0.0)))
				input_sockets.append(InputSocket.new("C", InputSocket.SocketType.VEC3, Vector3(0.0, 0.0, 1.0)))
			Operation.MULTIPLY_ADD:
				input_sockets.append(InputSocket.new("B", InputSocket.SocketType.VEC3, Vector3(0.0, 0.0, 0.0)))
				input_sockets.append(InputSocket.new("C", InputSocket.SocketType.VEC3, Vector3(0.0, 0.0, 0.0)))
			Operation.WRAP:
				input_sockets.append(InputSocket.new("B", InputSocket.SocketType.VEC3, Vector3(1.0, 1.0, 1.0)))
				input_sockets.append(InputSocket.new("C", InputSocket.SocketType.VEC3, Vector3(0.0, 0.0, 0.0)))
			_:
				pass


func configure_output_sockets() -> void:
	output_sockets = [
		OutputSocket.new("Vector", OutputSocket.SocketType.VEC3),
		OutputSocket.new("Value", OutputSocket.SocketType.FLOAT),
	]
	for s in output_sockets:
		s.set_parent_module(self)


func get_include_files() -> Array[String]:
	return [PATHS.INC["MATH"]]


func get_uniform_definitions() -> Dictionary:
	var u := {}
	u["operation"] = [ShaderSpec.ShaderType.INT, operation, ShaderSpec.UniformHint.ENUM, [
		"Add","Subtract","Multiply","Divide","Multiply Add","Cross Product","Project","Reflect","Refract","Faceforward","Dot Product","Distance","Length","Scale","Normalize","Absolute","Power","Sign","Minimum","Maximum","Floor","Ceil","Fraction","Modulo","Wrap","Snap","Sine","Cosine","Tangent"
	]]
	var op := int(operation)
	for s in get_input_sockets():
		if s.source and not (op == Operation.SCALE and s.name == "B"):
			continue
		u[s.name.to_lower()] = s.to_uniform()
	return u


func get_code_blocks() -> Dictionary:
	var active := get_active_output_sockets()
	if active.is_empty():
		return {}
	var outputs := get_output_vars()
	var uid := unique_id
	var a := "vec3(0.0)"
	var b := "vec3(0.0)"
	var c := "0.0"
	var args := get_input_args()
	if args.size() >= 1:
		a = String(args[0])
	if args.size() >= 2:
		b = String(args[1])
	if args.size() >= 3:
		c = String(args[2])

	var vec_expr := get_vec_expr(a, b, c)
	var val_expr := get_val_expr(a, b)

	var code := "\n// %s: %s (FRAG)\n" % [module_name, uid]
	if "Vector" in active and vec_expr != "":
		var out_vec := outputs.get("Vector", "vec_%s" % uid)
		code += "vec3 %s = %s;\n" % [out_vec, vec_expr]
	if "Value" in active and val_expr != "":
		var out_val := outputs.get("Value", "val_%s" % uid)
		code += "float %s = %s;\n" % [out_val, val_expr]
	return {"fragment_vmath_%s" % uid: {"stage": "fragment", "code": code}}


func get_vec_expr(a: String, b: String, c: String) -> String:
	match int(operation):
		Operation.ADD:
			return "((%s) + (%s))" % [a, b]
		Operation.SUBTRACT:
			return "((%s) - (%s))" % [a, b]
		Operation.MULTIPLY:
			return "((%s) * (%s))" % [a, b]
		Operation.DIVIDE:
			return "((%s) / max(abs(%s), vec3(1e-8)))" % [a, b]
		Operation.MULTIPLY_ADD:
			return "((%s) * (%s) + (%s))" % [a, b, c]
		Operation.CROSS_PRODUCT:
			return "cross((%s), (%s))" % [a, b]
		Operation.PROJECT:
			return "((dot(%s,%s) / max(dot(%s,%s), 1e-8)) * (%s))" % [a, b, b, b, b]
		Operation.REFLECT:
			return "reflect((%s), normalize(%s))" % [a, b]
		Operation.REFRACT:
			return "refract((%s), normalize(%s), (%s))" % [a, b, c]
		Operation.FACEFORWARD:
			return "faceforward((%s), (%s), (%s))" % [a, b, c]
		Operation.SCALE:
			return "((%s) * vec3(%s))" % [a, b]
		Operation.NORMALIZE:
			return "normalize(%s)" % [a]
		Operation.ABSOLUTE:
			return "abs(%s)" % [a]
		Operation.POWER:
			return "pow((%s), (%s))" % [a, b]
		Operation.SIGN:
			return "sign(%s)" % [a]
		Operation.MINIMUM:
			return "min((%s), (%s))" % [a, b]
		Operation.MAXIMUM:
			return "max((%s), (%s))" % [a, b]
		Operation.FLOOR:
			return "floor(%s)" % [a]
		Operation.CEIL:
			return "ceil(%s)" % [a]
		Operation.FRACTION:
			return "fract(%s)" % [a]
		Operation.MODULO:
			return "mod((%s), max(abs(%s), vec3(1e-8)))" % [a, b]
		Operation.WRAP:
			return "mix((%s), (mod((%s) - (%s), max(abs((%s) - (%s)), vec3(1e-8))) + (%s)), step(vec3(1e-8), abs((%s) - (%s))))" % [c, a, c, b, c, c, b, c]
		Operation.SNAP:
			return "(floor((%s) / max(abs(%s), vec3(1e-8)) + vec3(0.5)) * max(abs(%s), vec3(1e-8))) * step(vec3(1e-8), abs((%s)))" % [a, b, b, b]
		Operation.SINE:
			return "sin(%s)" % [a]
		Operation.COSINE:
			return "cos(%s)" % [a]
		Operation.TANGENT:
			return "tan(%s)" % [a]
		_:
			return ""


func get_val_expr(a: String, b: String) -> String:
	match int(operation):
		Operation.DOT_PRODUCT:
			return "dot((%s), (%s))" % [a, b]
		Operation.DISTANCE:
			return "distance((%s), (%s))" % [a, b]
		Operation.LENGTH:
			return "length(%s)" % [a]
		_:
			return ""


func get_input_args() -> Array:
	var args := []
	var op := int(operation)
	for s in get_input_sockets():
		var expr: String
		if op == Operation.SCALE and s.name == "B":
			expr = get_prefixed_name("b")
		elif s.source:
			var source_vars = s.source.parent_module.get_output_vars()
			var from_type = s.source.type_name()
			var to_type = s.type_name()
			expr = SocketCompatibility.convert(source_vars[s.source.name], from_type, to_type)
		else:
			expr = get_prefixed_name(s.name.to_lower())
		args.append(expr)
	return args


func set_uniform_override(name: String, value) -> void:
	if name == "operation":
		var new_op := int(value)
		if new_op != operation:
			operation = new_op
			configure_input_sockets()
	super.set_uniform_override(name, value)
