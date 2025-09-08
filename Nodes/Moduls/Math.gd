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
	POWER,
	LOGARITHM,
	SINE,
	COSINE,
	TANGENT,
	FLOOR,
	CEIL,
	FRACT,
	MINIMUM,
	MAXIMUM,
	MODULO,
	WRAP,
	SNAP,
	PINGPONG,
	ATAN2,
	COMPARE,
	ROUND,
	TRUNCATE,
}

@export_enum(
	"Add",
	"Subtract",
	"Multiply",
	"Divide",
	"Power",
	"Logarithm",
	"Sine",
	"Cosine",
	"Tangent",
	"Floor",
	"Ceil",
	"Fract",
	"Minimum",
	"Maximum",
	"Modulo",
	"Wrap",
	"Snap",
	"PingPong",
	"Arctan2",
	"Compare",
	"Round",
	"Truncate"
) var operation: int = Operation.ADD

@export var clamp_result: bool = false


func _init() -> void:
	super._init()
	module_name = "Math"
	configure_input_sockets()
	configure_output_sockets()


func configure_input_sockets() -> void:
	# Для первой итерации для всех операций оставляем два входа A/B
	input_sockets = [
		InputSocket.new("A", InputSocket.SocketType.FLOAT, 0.0),
		InputSocket.new("B", InputSocket.SocketType.FLOAT, 0.0),
	]

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
		"Add","Subtract","Multiply","Divide","Power","Logarithm","Sine","Cosine","Tangent",
		"Floor","Ceil","Fract","Minimum","Maximum","Modulo","Wrap","Snap","PingPong",
		"Arctan2","Compare","Round","Truncate"
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

	var expr := get_expr(a, b)
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


func get_expr(a: String, b: String) -> String:
	match int(operation):
		Operation.ADD:
			return "(%s + %s)" % [a, b]
		Operation.SUBTRACT:
			return "(%s - %s)" % [a, b]
		_:
			# Заглушка: прокидываем A
			return String(a)


func set_uniform_override(name: String, value) -> void:
	match name:
		"use_clamp":
			name = "clamp_result"
		_:
			pass
	# Обновление конфигурации входов при смене операции (будущие операции могут требовать иной набор входов)
	if name == "operation":
		var new_op := int(value)
		if new_op != operation:
			operation = new_op
			configure_input_sockets()
	super.set_uniform_override(name, value)
