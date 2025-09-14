# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name TextureCoordModule
extends ShaderModule

func _init() -> void:
	super._init()
	module_name = "Texture Coordinate"
	
	output_sockets = [
		OutputSocket.new("Generated", OutputSocket.SocketType.VEC3),
		OutputSocket.new("Normal", OutputSocket.SocketType.VEC3),
		OutputSocket.new("UV", OutputSocket.SocketType.VEC3),
		OutputSocket.new("Object", OutputSocket.SocketType.VEC3),
		OutputSocket.new("Camera", OutputSocket.SocketType.VEC3),
		OutputSocket.new("Window", OutputSocket.SocketType.VEC3),
		OutputSocket.new("Reflection", OutputSocket.SocketType.VEC3)
	]
	
	for socket in output_sockets:
		socket.set_parent_module(self)

func get_include_files() -> Array[String]:
	return [PATHS.INC["COORDS"], PATHS.INC["TEX_COORD"]]

func get_required_shared_varyings() -> Array[int]:
	var active: Array[String] = get_active_output_sockets()
	var req: Array[int] = []
	if "Camera" in active:
		req.append(ShaderSpec.SharedVar.VIEW_POS)
	if "Reflection" in active:
		req.append(ShaderSpec.SharedVar.WORLD_POS)
		req.append(ShaderSpec.SharedVar.WORLD_NORMAL)
	return req

func get_output_vars() -> Dictionary:
	var vars = {
		"Generated": "v_generated",
		"Object":    "v_object",
		"Normal":    "v_normal",
		"Camera":    "v_camera",
		"UV":        "v_uv",
		"Window":    "v_window",
		"Reflection": "v_reflection_%s" % unique_id
	}
	return vars


func get_code_blocks() -> Dictionary:
	var outputs = get_output_vars()
	var active: Array[String] = get_active_output_sockets()
	
	var vertex_code := ""
	var fragment_code := ""
	var globals: Array[String] = []
	
	var vert_outputs := {
		"Generated": outputs.get("Generated", ""),
		"Object": outputs.get("Object", ""),
		"Normal": outputs.get("Normal", ""),
		"Camera": outputs.get("Camera", "")
	}

	var needs_reflection_data := "Reflection" in active
	

	for key in vert_outputs.keys():
		if key in active and key != "Camera" and not vert_outputs[key].is_empty():
			globals.append("varying vec3 %s;" % vert_outputs[key])


	var vertex_lines := []

	if "Generated" in active:
		vertex_lines.append("{gen} = get_generated(VERTEX);")
	if "Object" in active:
		vertex_lines.append("{obj} = get_object(VERTEX);")
	if "Normal" in active:
		vertex_lines.append("{normal} = normalize(NORMAL* ROT_X(-90.0));")

	
	if vertex_lines.size() > 0:
		vertex_code = generate_code_block(
			"vertex",
			"// {module}\n" + "\n".join(vertex_lines),
			{
				"uuid": unique_id,
				"module": module_name,
				"gen": vert_outputs["Generated"],
				"obj": vert_outputs["Object"],
				"normal": vert_outputs["Normal"],
				"camera": vert_outputs["Camera"]
			}
		).strip_edges()
	
	var fragment_lines := []

	if "UV" in active:
		fragment_lines.append("vec3 {uv} = get_uv(UV);")
	if "Window" in active:
		fragment_lines.append("vec3 {window} = get_window(SCREEN_UV);")
	if "Camera" in active:
		fragment_lines.append("vec3 {camera} = %s * ROT_Y(180.0);" % ShaderSpec.shared_var_name(ShaderSpec.SharedVar.VIEW_POS))
	if needs_reflection_data:
		fragment_lines.append("vec3 {reflection} = get_reflection(VIEW_MATRIX, sv_world_pos, sv_world_normal);")
	
	if fragment_lines.size() > 0:
		fragment_code = generate_code_block(
			"fragment",
			"// {module}\n" + "\n".join(fragment_lines),
			{
				"uuid": unique_id,
				"module": module_name,
				"uv": outputs.get("UV", ""),
				"window": outputs.get("Window", ""),
				"camera": outputs.get("Camera", ""),
				"reflection": outputs.get("Reflection", "")
			}
		).strip_edges()
	
	var blocks = {}
	if globals.size() > 0:
		var globals_code := "\n".join(globals)
		var g_key = "global_texcoord_%s" % str(globals_code.hash())
		blocks[g_key] = {
			"stage": "global",
			"code": globals_code
		}
	
	if !vertex_code.is_empty():
		var v_key = "vertex_texcoord_%s" % str(vertex_code.hash())
		blocks[v_key] = {
			"stage": "vertex",
			"code": vertex_code
		}
	
	if !fragment_code.is_empty():
		blocks["fragment_%s" % unique_id] = {
			"stage": "fragment",
			"code": fragment_code
		}
	
	return blocks

func get_compile_defines() -> Array[String]:
	var active: Array[String] = get_active_output_sockets()
	var arr: Array[String] = []
	if "Generated" in active:
		arr.append("NEED_AABB")
	return arr

func get_required_instance_uniforms() -> Array[int]:
	var active: Array[String] = get_active_output_sockets()
	if "Generated" in active:
		return [ShaderSpec.InstanceUniform.BBOX]
	return []
