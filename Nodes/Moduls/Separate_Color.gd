@tool
class_name SeparateColorModule
extends ShaderModule

enum Mode { RGB, HSV, HSL }
@export_enum("RGB", "HSV", "HSL") var mode: int = Mode.RGB

func _init() -> void:
	super._init()
	module_name = "Separate Color"
	configure_input_sockets()
	configure_output_sockets()

func configure_input_sockets() -> void:
	input_sockets = [
		InputSocket.new("Color", InputSocket.SocketType.VEC4, Vector4(0.0, 0.0, 0.0, 1.0)),
	]

func configure_output_sockets() -> void:
	output_sockets = [
		OutputSocket.new("R", OutputSocket.SocketType.FLOAT),
		OutputSocket.new("G", OutputSocket.SocketType.FLOAT),
		OutputSocket.new("B", OutputSocket.SocketType.FLOAT),
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
	var col := "vec4(0.0, 0.0, 0.0, 1.0)"
	if args.size() > 0:
		col = String(args[0])
	var r_expr := ""
	var g_expr := ""
	var b_expr := ""
	match int(mode):
		Mode.RGB:
			r_expr = "(%s).r" % col
			g_expr = "(%s).g" % col
			b_expr = "(%s).b" % col
		Mode.HSV:
			r_expr = "rgb_to_hsv((%s).rgb).x" % col
			g_expr = "rgb_to_hsv((%s).rgb).y" % col
			b_expr = "rgb_to_hsv((%s).rgb).z" % col
		Mode.HSL:
			r_expr = "rgb_to_hsl((%s).rgb).x" % col
			g_expr = "rgb_to_hsl((%s).rgb).y" % col
			b_expr = "rgb_to_hsl((%s).rgb).z" % col
		_:
			r_expr = "(%s).r" % col
			g_expr = "(%s).g" % col
			b_expr = "(%s).b" % col
	var code := "\n// %s: %s (FRAG)\n" % [module_name, uid]
	if "R" in active:
		var out_r := outputs.get("R", "r_%s" % uid)
		code += "float %s = %s;\n" % [out_r, r_expr]
	if "G" in active:
		var out_g := outputs.get("G", "g_%s" % uid)
		code += "float %s = %s;\n" % [out_g, g_expr]
	if "B" in active:
		var out_b := outputs.get("B", "b_%s" % uid)
		code += "float %s = %s;\n" % [out_b, b_expr]
	return {"fragment_separate_color_%s" % uid: {"stage": "fragment", "code": code}}

func set_uniform_override(name: String, value) -> void:
	if name == "mode":
		mode = int(value)
	super.set_uniform_override(name, value)
