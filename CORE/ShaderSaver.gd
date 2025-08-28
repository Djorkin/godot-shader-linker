# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name ShaderSaver
extends Node

var save_path: String = "res://addons/godot_shader_linker_(gsl)/Assets/Mat/"

var file_dialog: EditorFileDialog
var current_builder: ShaderBuilder
var waiting_uniform_textures := {}
var waiting_material: ShaderMaterial
var waiting_material_path: String = ""
var fs_connected: bool = false

func _enter_tree() -> void:
	configure_file_dialog()

func configure_file_dialog() -> void:
	file_dialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	file_dialog.connect("file_selected", _on_file_selected)
	add_child(file_dialog)

func save_shader_dialog(builder: ShaderBuilder) -> void:
	current_builder = builder
	file_dialog.title = "Сохранить шейдер"
	file_dialog.filters = ["*.gdshader; Godot Shader File"]
	file_dialog.current_dir = save_path
	file_dialog.popup_centered(Vector2i(800, 600))

func save_material_dialog(builder: ShaderBuilder) -> void:
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
		material = create_material(current_builder)
		material.take_over_path(path)
	
	if material.shader == null:
		material.shader = Shader.new()
	material.shader.code = current_builder.build_shader()

	print_rich("[color=yellow]GSL[/color] Подготовка привязки текстур к материалу…")
	var no_pending := bind_available_textures_and_collect_waiting(material, current_builder)

	var err = ResourceSaver.save(material, path, ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
	handle_save_result(err, path, "Материал")

	if not no_pending:
		waiting_material = material
		waiting_material_path = path
		subscribe_fs_signals_once()
		var fs = EditorInterface.get_resource_filesystem()
		if fs:
			# Список ожидаемых путей
			var wait_list: PackedStringArray = []
			for uname in waiting_uniform_textures.keys():
				wait_list.append(str(waiting_uniform_textures[uname]))
			print_rich("[color=yellow]GSL[/color] Ждём импорт ресурсов (кол-во: %d)" % wait_list.size())
			if fs.has_method("reimport_files"):
				print_rich("[color=yellow]GSL[/color] Запрос reimport_files для ожидаемых путей…")
				fs.call("reimport_files", wait_list)
			else:
				print_rich("[color=yellow]GSL[/color] reimport_files недоступен, выполняю scan()…")
				fs.scan()

func create_material(builder: ShaderBuilder) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = builder.build_shader()
	material.shader = shader
	return material

func bind_available_textures_and_collect_waiting(material: ShaderMaterial, builder: ShaderBuilder) -> bool:
	waiting_uniform_textures.clear()
	if not builder or not builder.uniform_resources:
		print_rich("[color=yellow]GSL[/color] Нет текстур для привязки")
		return true
	var bound := 0
	var waiting := 0
	for uname in builder.uniform_resources.keys():
		var res_path: String = str(builder.uniform_resources[uname])
		if ResourceLoader.exists(res_path):
			var tex := load(res_path) as Texture2D
			if tex:
				material.set_shader_parameter(uname, tex)
				bound += 1
				print_rich("[color=green]GSL[/color] Привязал %s ← %s" % [uname, res_path])
			else:
				push_warning("Не удалось загрузить Texture2D: %s" % res_path)
		else:
			waiting_uniform_textures[uname] = res_path
			waiting += 1
			print_rich("[color=yellow]GSL[/color] Ожидаю импорт: %s" % res_path)
	print_rich("[color=yellow]GSL[/color] Привязано: %d, ожидается: %d" % [bound, waiting])
	return waiting_uniform_textures.is_empty()

func subscribe_fs_signals_once() -> void:
	if fs_connected:
		return
	var fs = EditorInterface.get_resource_filesystem()
	if not fs:
		push_warning("FS недоступна, не смогу отследить импорт ресурсов")
		return
	if not fs.is_connected("filesystem_changed", Callable(self, "_on_fs_changed")):
		fs.filesystem_changed.connect(self._on_fs_changed)
		print_rich("[color=yellow]GSL[/color] Подписка: filesystem_changed")
	if fs.has_signal("resources_reimported") and not fs.is_connected("resources_reimported", Callable(self, "_on_resources_reimported")):
		fs.resources_reimported.connect(self._on_resources_reimported)
		print_rich("[color=yellow]GSL[/color] Подписка: resources_reimported")
	fs_connected = true

func unsubscribe_fs_signals() -> void:
	if not fs_connected:
		return
	var fs = EditorInterface.get_resource_filesystem()
	if fs:
		if fs.is_connected("filesystem_changed", Callable(self, "_on_fs_changed")):
			fs.filesystem_changed.disconnect(self._on_fs_changed)
		if fs.has_signal("resources_reimported") and fs.is_connected("resources_reimported", Callable(self, "_on_resources_reimported")):
			fs.resources_reimported.disconnect(self._on_resources_reimported)
		print_rich("[color=yellow]GSL[/color] Отписка от сигналов FS")
	fs_connected = false

func _on_resources_reimported(paths: PackedStringArray) -> void:
	print_rich("[color=yellow]GSL[/color] resources_reimported: %d шт." % paths.size())
	finalize_waiting_if_ready()

func _on_fs_changed() -> void:
	print_rich("[color=yellow]GSL[/color] filesystem_changed")
	finalize_waiting_if_ready()

func finalize_waiting_if_ready() -> void:
	if waiting_uniform_textures.is_empty():
		unsubscribe_fs_signals()
		return
	var resolved: Array = []
	for uname in waiting_uniform_textures.keys():
		var res_path: String = str(waiting_uniform_textures[uname])
		if ResourceLoader.exists(res_path):
			var tex := load(res_path) as Texture2D
			if tex and is_instance_valid(waiting_material):
				waiting_material.set_shader_parameter(uname, tex)
				resolved.append(uname)
				print_rich("[color=green]GSL[/color] Привязал (ожидал) %s ← %s" % [uname, res_path])
	for uname in resolved:
		waiting_uniform_textures.erase(uname)
	if waiting_uniform_textures.is_empty():
		if is_instance_valid(waiting_material) and waiting_material_path != "":
			var err = ResourceSaver.save(waiting_material, waiting_material_path, ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
			handle_save_result(err, waiting_material_path, "Материал (обновлён текстурами)")
		waiting_material = null
		waiting_material_path = ""
		unsubscribe_fs_signals()
	else:
		print_rich("[color=yellow]GSL[/color] Ещё ожидается: %d" % waiting_uniform_textures.size())

func handle_save_result(error: Error, path: String, type: String) -> void:
	match error:
		OK:
			print_rich("[color=green]%s успешно сохранён:[/color] %s" % [type, path])
			EditorInterface.get_resource_filesystem().scan()
		_:
			var error_msg = "Ошибка сохранения %s (код %d)" % [type, error]
			push_error(error_msg)
