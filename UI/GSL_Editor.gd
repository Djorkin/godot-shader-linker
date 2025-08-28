# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
extends Control

var Parser_inst = Parser.new()
var SSL = ServerStatusListener.new()
var Saver_inst = ShaderSaver.new()

enum SaveMode { NONE, SHADER, MATERIAL }
var save_mode: int = SaveMode.NONE

func _ready() -> void:
	add_child(Saver_inst)
	SSL.start()
	Parser_inst.builder_ready.connect(builder_ready)

func _exit_tree() -> void:
	SSL.stop()

func _on_create_shader_pressed() -> void:
	save_mode = SaveMode.SHADER
	Parser_inst.send_request()

func _on_create_material_pressed() -> void:
	save_mode = SaveMode.MATERIAL
	Parser_inst.send_request()

func builder_ready(builder: ShaderBuilder) -> void:
	if save_mode == SaveMode.SHADER:
		Saver_inst.save_shader_dialog(builder)
	elif save_mode == SaveMode.MATERIAL:
		Saver_inst.save_material_dialog(builder)
	save_mode = SaveMode.NONE
