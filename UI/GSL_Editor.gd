# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
extends Control

@export var saver: ShaderSaver

var mapper = Mapper.new()
var _builder = ShaderBuilder.new()
var parser = Parser.new()
const ServerStatusListener = preload("res://addons/godot_shader_linker_(gsl)/CORE/ServerStatusListener.gd")
var SSL = ServerStatusListener.new()
var _save_mode: String = ""  # "shader" или "material"

func _ready() -> void:
	if not saver:
		saver = ShaderSaver.new()
		add_child(saver)
	SSL.start()
	parser.builder_ready.connect(builder_ready)

func _exit_tree() -> void:
	SSL.stop()

func _on_create_shader_pressed() -> void:
	_save_mode = "shader"
	parser.send_request()

func _on_create_material_pressed() -> void:
	_save_mode = "material"
	parser.send_request()

func builder_ready(builder: ShaderBuilder) -> void:
	if _save_mode == "shader":
		saver.save_shader(builder)
	elif _save_mode == "material":
		saver.save_material(builder)
	_save_mode = ""
