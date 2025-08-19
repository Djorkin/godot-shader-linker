# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
extends Control

var Parser_inst = Parser.new()
var SSL = ServerStatusListener.new()
var Saver_inst = ShaderSaver.new()

var save_mode: String   # "shader" || "material"

func _ready() -> void:
	add_child(Saver_inst)
	SSL.start()
	Parser_inst.builder_ready.connect(builder_ready)

func _exit_tree() -> void:
	SSL.stop()

func _on_create_shader_pressed() -> void:
	save_mode = "shader"
	Parser_inst.send_request()

func _on_create_material_pressed() -> void:
	save_mode = "material"
	Parser_inst.send_request()

func builder_ready(builder: ShaderBuilder) -> void:
	if save_mode == "shader":
		Saver_inst.save_shader(builder)
	elif save_mode == "material":
		Saver_inst.save_material(builder)
	save_mode = ""
