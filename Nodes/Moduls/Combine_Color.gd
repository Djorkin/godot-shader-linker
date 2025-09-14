@tool
class_name CombineColorModule
extends ShaderModule

enum Mode { RGB, HSV, HSL }
@export_enum("RGB", "HSV", "HSL") var mode: int = Mode.RGB

func _init() -> void:
	super._init()
	module_name = "Combine Color"
	configure_input_sockets()
	configure_output_sockets()

func configure_input_sockets() -> void:
	input_sockets = [
		InputSocket.new("R", InputSocket.SocketType.FLOAT, 0.0),
		InputSocket.new("G", InputSocket.SocketType.FLOAT, 0.0),
		InputSocket.new("B", InputSocket.SocketType.FLOAT, 0.0),
	]

func configure_output_sockets() -> void:
	output_sockets = [
		OutputSocket.new("Color", OutputSocket.SocketType.VEC4),
	]
	for s in output_sockets:
		s.set_parent_module(self)

func get_include_files() -> Array[String]:
	return [PATHS.INC["COLOR_CONVERSIONS"]]

func get_uniform_definitions() -> Dictionary:
	var u := {}
	u["mode"] = [ShaderSpec.ShaderType.INT, mode, ShaderSpec.UniformHint.ENUM, ["RGB","HSV","HSL"]]
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
	var uid := unique_id
	var args := get_input_args()
	var r := "0.0"
	if args.size() > 0:
		r = String(args[0])
	var g := "0.0"
	if args.size() > 1:
		g = String(args[1])
	var b := "0.0"
	if args.size() > 2:
		b = String(args[2])
	var col_expr := "vec4(%s, %s, %s, 1.0)" % [r, g, b]
	match int(mode):
		Mode.RGB:
			col_expr = "vec4(%s, %s, %s, 1.0)" % [r, g, b]
		Mode.HSV:
			col_expr = "vec4(hsv_to_rgb(vec3(%s, %s, %s)), 1.0)" % [r, g, b]
		Mode.HSL:
			col_expr = "vec4(hsl_to_rgb(vec3(%s, %s, %s)), 1.0)" % [r, g, b]
		_:
			pass
	var code := "\n// %s: %s (FRAG)\n" % [module_name, uid]
	if "Color" in active:
		var out_col := outputs.get("Color", "color_%s" % uid)
		code += "vec4 %s = %s;\n" % [out_col, col_expr]
	return {"fragment_combine_color_%s" % uid: {"stage": "fragment", "code": code}}

func set_uniform_override(name: String, value) -> void:
	if name == "mode":
		mode = int(value)
	super.set_uniform_override(name, value)
