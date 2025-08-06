# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name PrincipledBSDFModule
extends ShaderModule

func _init() -> void:
	super._init()
	module_name = "Principled BSDF"
	
	_input_sockets = [
		InputSocket.new("Base_Color", InputSocket.SocketType.VEC4, Vector4(0.8, 0.8, 0.8, 1.0)), # 0
		InputSocket.new("Metallic", InputSocket.SocketType.FLOAT, 0.0), # 1
		InputSocket.new("Roughness", InputSocket.SocketType.FLOAT, 0.5), # 2
		InputSocket.new("IOR", InputSocket.SocketType.FLOAT, 1.45), # 3
		InputSocket.new("Alpha", InputSocket.SocketType.FLOAT, 1.0), # 4
		InputSocket.new("Normal", InputSocket.SocketType.VEC3, Vector3(0.0, 0.0, 0.0)), # 5
		InputSocket.new("Weight", InputSocket.SocketType.FLOAT, 1.0), # 6
		InputSocket.new("Diffuse_Roughness", InputSocket.SocketType.FLOAT, 0.0), # 7
		InputSocket.new("Subsurface_Weight", InputSocket.SocketType.FLOAT, 0.0), # 8
		InputSocket.new("Subsurface_Radius", InputSocket.SocketType.VEC3, Vector3(1.0, 0.2, 0.1)), # 9
		InputSocket.new("Subsurface_Scale", InputSocket.SocketType.FLOAT, 0.05), # 10
		InputSocket.new("Subsurface_IOR", InputSocket.SocketType.FLOAT, 1.4), # 11
		InputSocket.new("Subsurface_Anisotropy", InputSocket.SocketType.FLOAT, 0.0), # 12
		InputSocket.new("Specular_IOR_Level", InputSocket.SocketType.FLOAT, 0.5), # 13
		InputSocket.new("Specular_Tint", InputSocket.SocketType.VEC4, Vector4(1.0, 1.0, 1.0, 1.0)), # 14
		InputSocket.new("Anisotropic", InputSocket.SocketType.FLOAT, 0.0), # 15
		InputSocket.new("Anisotropic_Rotation", InputSocket.SocketType.FLOAT, 0.0), # 16
		InputSocket.new("Tangent", InputSocket.SocketType.VEC3, Vector3(0.0, 0.0, 0.0)), # 17
		InputSocket.new("Transmission_Weight", InputSocket.SocketType.FLOAT, 0.0), # 18
		InputSocket.new("Coat_Weight", InputSocket.SocketType.FLOAT, 0.0), # 19
		InputSocket.new("Coat_Roughness", InputSocket.SocketType.FLOAT, 0.0), # 20
		InputSocket.new("Coat_IOR", InputSocket.SocketType.FLOAT, 1.45), # 21
		InputSocket.new("Coat_Tint", InputSocket.SocketType.VEC4, Vector4(1.0, 1.0, 1.0, 1.0)), # 22
		InputSocket.new("Coat_Normal", InputSocket.SocketType.VEC3, Vector3(0.0, 0.0, 0.0)), # 23
		InputSocket.new("Sheen_Weight", InputSocket.SocketType.FLOAT, 0.0), # 24
		InputSocket.new("Sheen_Roughness", InputSocket.SocketType.FLOAT, 0.0), # 25
		InputSocket.new("Sheen_Tint", InputSocket.SocketType.VEC4, Vector4(1.0, 1.0, 1.0, 1.0)), # 26
		InputSocket.new("Emission", InputSocket.SocketType.VEC4, Vector4(0.0, 0.0, 0.0, 1.0)), # 27
		InputSocket.new("Emission_Strength", InputSocket.SocketType.FLOAT, 0.0), # 28
		InputSocket.new("Thin_Film_Thickness", InputSocket.SocketType.FLOAT, 0.0), # 29
		InputSocket.new("Thin_Film_IOR", InputSocket.SocketType.FLOAT, 1.33), # 30
	]
	_output_sockets = [
		OutputSocket.new("BSDF", OutputSocket.SocketType.SHADER)
	]
	
	for socket in _output_sockets:
		socket.set_parent_module(self)


func get_include_files() -> Array[String]:
	return [PATHS.INC["PHYSICAL"], PATHS.INC["MATH"], PATHS.INC["MATERIAL"], PATHS.INC["BSDF_PRINCILED"]]

func get_output_sockets() -> Array[OutputSocket]:
	return _output_sockets

func get_uniform_definitions() -> Dictionary:
	var u = {}
	for s in get_input_sockets():
		if s.source:
			continue
		var name = s.name.to_lower()
		if name == "screen_texture":
			u["SCREEN_TEXTURE"] = {"type":"sampler2D", "hint":"hint_screen_texture"}
			continue
		var def = s.to_uniform()

		# Добавляем подсказки (hint) в зависимости от типа параметра
		match s.name:
			"Base_Color", "Specular_Tint", "Coat_Tint", "Sheen_Tint", "Emission":
				def["hint"] = "source_color"
			"Metallic", "Roughness", "Alpha", "Transmission_Weight", "Coat_Weight", "Coat_Roughness", "Sheen_Weight", "Sheen_Roughness", "IOR_Level":
				def["hint"] = "hint_range(0,1)"
			"IOR":
				def["hint"] = "hint_range(1.0,100.0)"
			"Coat_IOR":
				def["hint"] = "hint_range(1.0,4.0)"
			"Emission_Strength":
				def["hint"] = "hint_range(0,100)"
			"Specular_IOR_Level":
				def["hint"] = "hint_range(0,1)"
			_:
				pass

		u[name] = def
	return u

func get_compile_defines() -> Array[String]:
	var defs: Array[String] = []

	# Проверка Transmission первична — при наличии Transmission нужен и ALPHA_TRANSFER.
	var trans_socket := _input_sockets[18]
	var trans_val = _uniform_overrides.get("Transmission_Weight", _uniform_overrides.get("transmission_weight", trans_socket.default))
	var has_transmission := trans_socket.source != null or float(trans_val) > 0.0
	if has_transmission:
		defs.append("ALPHA_TRANSFER")
		defs.append("TRANSMISSION")
		return defs

	# Иначе проверяем Alpha
	var alpha_socket := _input_sockets[4]
	var alpha_val = _uniform_overrides.get("Alpha", _uniform_overrides.get("alpha", alpha_socket.default))
	if alpha_socket.source != null or not is_equal_approx(float(alpha_val), 1.0):
		defs.append("ALPHA_TRANSFER")

	return defs

func get_input_sockets() -> Array[InputSocket]:
	return _input_sockets

func get_code_blocks() -> Dictionary:
	var inputs = _get_input_args()

	# Если вход Normal не подключён, используем встроенную NORMAL
	var normal_expr = ""
	if _input_sockets[5].source == null:
		normal_expr = "NORMAL"
	else:
		normal_expr = inputs[5]

	# Порядок аргументов как в bsdf_mini()
	var args = {
		"base_color": inputs[0],
		"metallic": inputs[1],
		"roughness": inputs[2],
		"ior": inputs[3],
		"alpha": inputs[4],
		"normal": normal_expr, 
		"view": "normalize(VIEW)",
		"weight": "1.0",
		"specular_ior_level": inputs[13],
		"specular_tint": inputs[14],
		"transmission_weight": inputs[18],
		"coat_weight": inputs[19],
		"coat_roughness": inputs[20],
		"coat_ior": inputs[21],
		"coat_tint": inputs[22],
		"cnormal": "NORMAL",
		"sheen_weight": inputs[24],
		"sheen_roughness": inputs[25],
		"sheen_tint": inputs[26],
		"emission": inputs[27],
		"emission_strength": inputs[28],
		"do_multiscatter": "true",
		"render_surface_type": "0",
		"screen_uv": "SCREEN_UV",
		"material_var": get_output_vars()["BSDF"],
		"module": module_name,
		"uid": unique_id,
	}

	var template = """
// {module}: {uid}
Material {material_var} = bsdf_mini(
{base_color}, 
{metallic}, 
{roughness}, 
{ior}, 
{alpha}, 
{normal}, 
{view}, 
{weight}, 
{specular_ior_level}, 
{specular_tint}, 
{transmission_weight}, 
{coat_weight}, 
{coat_roughness}, 
{coat_ior}, 
{coat_tint}, 
{cnormal}, 
{sheen_weight}, 
{sheen_roughness}, 
{sheen_tint}, 
{emission}, 
{emission_strength}, 
{do_multiscatter}, 
{screen_uv}
);
"""
	var blocks = {}
	blocks["fragment_%s" % unique_id] = {"stage":"fragment", "code": generate_code_block("fragment", template, args)}
	return blocks
