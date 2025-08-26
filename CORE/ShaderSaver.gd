# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name ShaderSaver
extends Node

var save_path: String = "res://addons/godot_shader_linker_(gsl)/Assets/Mat/"

var file_dialog: EditorFileDialog
var current_builder: ShaderBuilder

func _enter_tree() -> void:
	configure_file_dialog()

func configure_file_dialog() -> void:
	file_dialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	file_dialog.connect("file_selected", _on_file_selected)
	add_child(file_dialog)

func save_shader(builder: ShaderBuilder) -> void:
	current_builder = builder
	file_dialog.title = "Сохранить шейдер"
	file_dialog.filters = ["*.gdshader; Godot Shader File"]
	file_dialog.current_dir = save_path
	file_dialog.popup_centered(Vector2i(800, 600))

func save_material(builder: ShaderBuilder) -> void:
	current_builder = builder
	file_dialog.title = "Сохранить материал"
	file_dialog.filters = ["*.tres; Godot Material File"]
	file_dialog.current_dir = save_path
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_file_selected(path: String) -> void:
	if path.ends_with(".gdshader"):
		save_shader_file(path)
	elif path.ends_with(".tres"):
		save_material_file(path)

func save_shader_file(path: String) -> void:
	var shader: Shader
	if ResourceLoader.exists(path):
		shader = load(path) as Shader
		if shader == null:
			push_error("Не удалось загрузить существующий шейдер: %s" % path)
			return
	else:
		shader = Shader.new()
		shader.take_over_path(path)
	
	shader.code = current_builder.build_shader()
	
	var err = ResourceSaver.save(shader, path, ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
	handle_save_result(err, path, "Шейдер")

func save_material_file(path: String) -> void:
	if not current_builder:
		push_error("ShaderBuilder не инициализирован!")
		return
	
	var material: ShaderMaterial
	if ResourceLoader.exists(path):
		material = load(path) as ShaderMaterial
		if material == null:
			push_error("Файл существует, но не является ShaderMaterial: %s" % path)
			return
	else:
		material = current_builder.create_material()
		material.take_over_path(path)
	
	if material.shader == null:
		material.shader = Shader.new()
	material.shader.code = current_builder.build_shader()

	var err = ResourceSaver.save(material, path, ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
	handle_save_result(err, path, "Материал")

func handle_save_result(error: Error, path: String, type: String) -> void:
	match error:
		OK:
			print_rich("[color=green]%s успешно сохранён:[/color] %s" % [type, path])
			EditorInterface.get_resource_filesystem().scan()
		_:
			var error_msg = "Ошибка сохранения %s (код %d)" % [type, error]
			push_error(error_msg)
