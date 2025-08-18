# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name ShaderSaver
extends Node

@export_dir var save_path: String = "res://addons/godot_shader_linker_(gsl)/Assets/Mat/"

var file_dialog: EditorFileDialog
var current_builder: ShaderBuilder
var pending_updates: Array = []

# NOTE: временное решение.
var retry_timer: Timer
var fs_refresh_timer: Timer
const MAX_RETRIES := 10
var retry_count := 0

func _enter_tree() -> void:
	configure_file_dialog()

func configure_file_dialog() -> void:
	file_dialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	file_dialog.connect("file_selected", _on_file_selected)
	add_child(file_dialog)

func set_save_path(new_path: String) -> void:
	save_path = new_path
	if not DirAccess.dir_exists_absolute(save_path):
		DirAccess.make_dir_recursive_absolute(save_path)

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
	
	# Обновляем базу ресурсов, чтобы Godot увидел только что скопированные изображения
	EditorInterface.get_resource_filesystem().scan()
	pending_updates.clear()
	
	#for mod_id in collector.registered_modules:
		#var module = collector.registered_modules[mod_id]
		#for override_key in module.uniform_overrides:
			#var value = module.uniform_overrides[override_key]
			#if override_key == "image_path":
				#var uniform_name = module.get_prefixed_name("image_texture")
				#if typeof(value) == TYPE_STRING:
					#pending_updates.append({
						#"mat_path": path,
						#"uniform": uniform_name,
						#"tex_path": value
					#})
			#else:
				#var uniform_name = module.get_prefixed_name(override_key)
				#material.set_shader_parameter(uniform_name, value)
	
	# если есть незагруженные текстуры – запустим таймер повторных попыток
	if pending_updates.size() > 0:
		start_retry_timer()
	
	var err = ResourceSaver.save(material, path, ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
	handle_save_result(err, path, "Материал")

func start_retry_timer():
	if retry_timer == null:
		retry_timer = Timer.new()
		retry_timer.one_shot = true
		add_child(retry_timer)
	retry_timer.wait_time = 1.0
	# подключаем сигнал только один раз, иначе Godot ругается на дубликаты
	if not retry_timer.timeout.is_connected(process_pending_updates):
		retry_timer.timeout.connect(process_pending_updates)
	retry_timer.start()

func process_pending_updates():
	retry_count += 1
	var still_pending: Array = []
	for item in pending_updates:
		var tex_path = item["tex_path"]
		# ждём, пока появится .import-файл – значит, ресурс готов
		if not FileAccess.file_exists(tex_path + ".import"):
			still_pending.append(item)
			continue
		var tex = load(tex_path)
		if tex:
			var mat = load(item["mat_path"]) as ShaderMaterial
			if mat:
				mat.set_shader_parameter(item["uniform"], tex)
				ResourceSaver.save(mat, item["mat_path"], ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
		else:
			still_pending.append(item)
	pending_updates = still_pending
	if pending_updates.size() > 0 and retry_count < MAX_RETRIES:
		start_retry_timer()
	elif pending_updates.size() == 0:
		if retry_timer:
			retry_timer.stop()
		print("[GSL] All textures connected successfully")
		retry_count = 0
	elif retry_count >= MAX_RETRIES:
		if retry_timer:
			retry_timer.stop()
		print("[GSL] Failed to connect all textures (timeout)")

func handle_save_result(error: Error, path: String, type: String) -> void:
	match error:
		OK:
			notify_success(type, path)
			EditorInterface.get_resource_filesystem().scan()
		_:
			notify_error(error, type)

func notify_success(type: String, path: String) -> void:
	print_rich("[color=green]%s успешно сохранён:[/color] %s" % [type, path])
	# Отложенный refresh, чтобы дождаться импорта ресурса
	call_deferred("refresh_filesystem", path)

func refresh_filesystem(path: String):
	await get_tree().process_frame
	EditorInterface.get_resource_filesystem().scan()
	if fs_refresh_timer == null:
		fs_refresh_timer = Timer.new()
		fs_refresh_timer.one_shot = true
		add_child(fs_refresh_timer)
		fs_refresh_timer.timeout.connect(_on_fs_refresh_timeout)
	fs_refresh_timer.start(0.5)

func _on_fs_refresh_timeout():
	EditorInterface.get_resource_filesystem().scan()

func notify_error(error: Error, type: String) -> void:
	var error_msg = "Ошибка сохранения %s (код %d)" % [type, error]
	push_error(error_msg)
