@tool
class_name CombineXYZModule
extends ShaderModule

func _init() -> void:
	super._init()
	module_name = "Combine XYZ"
	configure_input_sockets()
	configure_output_sockets()

func configure_input_sockets() -> void:
	input_sockets = [
		InputSocket.new("X", InputSocket.SocketType.FLOAT, 0.0),
		InputSocket.new("Y", InputSocket.SocketType.FLOAT, 0.0),
		InputSocket.new("Z", InputSocket.SocketType.FLOAT, 0.0),
	]

func configure_output_sockets() -> void:
	output_sockets = [
		OutputSocket.new("Vector", OutputSocket.SocketType.VEC3),
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
	var x := "0.0"
	if args.size() > 0:
		x = String(args[0])
	var y := "0.0"
	if args.size() > 1:
		y = String(args[1])
	var z := "0.0"
	if args.size() > 2:
		z = String(args[2])
	var code := "\n// %s: %s (FRAG)\n" % [module_name, uid]
	if "Vector" in active:
		var out_v := outputs.get("Vector", "vec_%s" % uid)
		code += "vec3 %s = vec3(%s, %s, %s);\n" % [out_v, x, y, z]
	return {"fragment_combine_xyz_%s" % uid: {"stage": "fragment", "code": code}}
