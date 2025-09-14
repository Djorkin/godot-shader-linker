@tool
class_name SeparateXYZModule
extends ShaderModule

func _init() -> void:
	super._init()
	module_name = "Separate XYZ"
	configure_input_sockets()
	configure_output_sockets()

func configure_input_sockets() -> void:
	input_sockets = [
		InputSocket.new("Vector", InputSocket.SocketType.VEC3, Vector3(0.0, 0.0, 0.0)),
	]

func configure_output_sockets() -> void:
	output_sockets = [
		OutputSocket.new("X", OutputSocket.SocketType.FLOAT),
		OutputSocket.new("Y", OutputSocket.SocketType.FLOAT),
		OutputSocket.new("Z", OutputSocket.SocketType.FLOAT),
	]
	for s in output_sockets:
		s.set_parent_module(self)

func get_uniform_definitions() -> Dictionary:
	var u := {}
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
	var v := "vec3(0.0)"
	if args.size() > 0:
		v = String(args[0])
	var code := "\n// %s: %s (FRAG)\n" % [module_name, uid]
	if "X" in active:
		var out_x := outputs.get("X", "x_%s" % uid)
		code += "float %s = (%s).x;\n" % [out_x, v]
	if "Y" in active:
		var out_y := outputs.get("Y", "y_%s" % uid)
		code += "float %s = (%s).y;\n" % [out_y, v]
	if "Z" in active:
		var out_z := outputs.get("Z", "z_%s" % uid)
		code += "float %s = (%s).z;\n" % [out_z, v]
	return {"fragment_separate_xyz_%s" % uid: {"stage": "fragment", "code": code}}
