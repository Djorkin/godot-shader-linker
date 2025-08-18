# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name Linker

# Глобальная таблица совместимости типов
const SOCKET_COMPAT = preload("res://addons/godot_shader_linker_(gsl)/Nodes/Moduls/Moduls_Base/Sokets/SocketCompatibility.gd")

func link_modules(
	source_module: ShaderModule, 
	socket_out_id: int,
	target_module: ShaderModule, 
	socket_in_id: int) -> void:
	
	var output_sockets = source_module.get_output_sockets()
	if socket_out_id >= output_sockets.size():
		push_error("Invalid output socket index: %d" % socket_out_id)
		return
	
	var output_socket = output_sockets[socket_out_id]
	
	var input_sockets = target_module.get_input_sockets()
	if socket_in_id >= input_sockets.size():
		push_error("Invalid input socket index: %d" % socket_in_id)
		return
	
	var input_socket = input_sockets[socket_in_id]
	
	# Проверка совместимости типов
	var out_type_name: String = output_socket.type_name()
	var in_type_name: String = input_socket.type_name()
	if not SOCKET_COMPAT.is_compatible(out_type_name, in_type_name):
		push_error("Incompatible socket types: %s -> %s" % [out_type_name, in_type_name])
		return
	
	input_socket.source = output_socket
	
	target_module.add_dependency(source_module)

