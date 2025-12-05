# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name ShaderSaver
extends Node

var save_path: String = "res://GSL_Textures"

var file_dialog: EditorFileDialog
var current_builder: ShaderBuilder
var waiting_uniform_textures := {}
var waiting_material: ShaderMaterial
var waiting_material_path: String = ""
var fs_connected: bool = false
var texture_copy_policy: String = "copy_if_outside"
var current_material_name: String = ""

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
	file_dialog.title = "Save Shader"
	file_dialog.filters = ["*.gdshader; Godot Shader File"]
	file_dialog.current_dir = save_path
	file_dialog.popup_centered(Vector2i(800, 600))

func save_material_dialog(builder: ShaderBuilder) -> void:
	current_builder = builder
	file_dialog.title = "Save Material"
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
			push_error("Failed to load existing shader: %s" % path)
			return
	else:
		shader = Shader.new()
		shader.take_over_path(path)
	
	shader.code = current_builder.build_shader()
	
	var err = ResourceSaver.save(shader, path, ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
	handle_save_result(err, path, "Shader")

func save_material_file(path: String) -> void:
	if not current_builder:
		push_error("ShaderBuilder is not initialized!")
		return
	
	var material: ShaderMaterial
	if ResourceLoader.exists(path):
		material = load(path) as ShaderMaterial
		if material == null:
			push_error("File exists but is not a ShaderMaterial: %s" % path)
			return
	else:
		material = create_material(current_builder)
		material.take_over_path(path)
	
	if material.shader == null:
		material.shader = Shader.new()
	material.shader.code = current_builder.build_shader()

	current_material_name = path.get_file().get_basename()

	var no_pending := bind_available_textures_and_collect_waiting(material, current_builder)

	var err = ResourceSaver.save(material, path, ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
	handle_save_result(err, path, "Material")

	if not no_pending:
		waiting_material = material
		waiting_material_path = path
		subscribe_fs_signals_once()
		var fs = EditorInterface.get_resource_filesystem()
		if fs:
			fs.scan()
	else:
		current_material_name = ""

func create_material(builder: ShaderBuilder) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = builder.build_shader()
	material.shader = shader
	return material

func bind_available_textures_and_collect_waiting(material: ShaderMaterial, builder: ShaderBuilder) -> bool:
	waiting_uniform_textures.clear()
	if not builder:
		print_rich("[color=yellow]GSL[/color] No builder, nothing to bind")
		return true
	var bound := 0
	var waiting := 0
	if builder.uniform_resources:
		for uname in builder.uniform_resources.keys():
			var res_path: String = str(builder.uniform_resources[uname])
			res_path = ensure_texture_path(res_path, current_material_name)
			if ResourceLoader.exists(res_path):
				var tex := load(res_path) as Texture2D
				if tex:
					material.set_shader_parameter(uname, tex)
					bound += 1
				else:
					push_warning("Failed to load Texture2D: %s" % res_path)
			else:
				waiting_uniform_textures[uname] = res_path
				waiting += 1
	if builder.uniform_object_resources:
		for oname in builder.uniform_object_resources.keys():
			var res: Resource = builder.uniform_object_resources[oname]
			if res and res is Texture2D:
				material.set_shader_parameter(oname, res)
				bound += 1
	#print_rich("[color=yellow]GSL[/color] Bound: %d, pending: %d" % [bound, waiting])
	return waiting_uniform_textures.is_empty()

func subscribe_fs_signals_once() -> void:
	if fs_connected:
		return
	var fs = EditorInterface.get_resource_filesystem()
	if not fs:
		push_warning("FS is unavailable, cannot track resource import")
		return
	if not fs.is_connected("filesystem_changed", Callable(self, "_on_fs_changed")):
		fs.filesystem_changed.connect(self._on_fs_changed)
	if fs.has_signal("resources_reimported") and not fs.is_connected("resources_reimported", Callable(self, "_on_resources_reimported")):
		fs.resources_reimported.connect(self._on_resources_reimported)
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
	fs_connected = false

func _on_resources_reimported(paths: PackedStringArray) -> void:
	finalize_waiting_if_ready()

func _on_fs_changed() -> void:
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
	for uname in resolved:
		waiting_uniform_textures.erase(uname)
	if waiting_uniform_textures.is_empty():
		if is_instance_valid(waiting_material) and waiting_material_path != "":
			var err = ResourceSaver.save(waiting_material, waiting_material_path, ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
			handle_save_result(err, waiting_material_path, "Material (updated with textures)")
		waiting_material = null
		waiting_material_path = ""
		unsubscribe_fs_signals()


func handle_save_result(error: Error, path: String, type: String) -> void:
	match error:
		OK:
			print_rich("[color=green]%s saved successfully:[/color] %s" % [type, path])
			EditorInterface.get_resource_filesystem().scan()
		_:
			var error_msg = "Save error %s (code %d)" % [type, error]
			push_error(error_msg)


func ensure_texture_path(raw_path: String, material_name: String) -> String:
	if raw_path.is_empty():
		return raw_path
	# Если путь уже внутри res://, ничего не делаем
	if raw_path.begins_with("res://"):
		return raw_path
	# Если политика не предполагает копирование, вернуть как есть
	if texture_copy_policy != "copy_if_outside":
		return raw_path
	var abs_src := raw_path
	if not abs_src.begins_with("user://") and not abs_src.begins_with("res://"):
		abs_src = raw_path
	var base_dir := save_path
	if base_dir.is_empty():
		base_dir = "res://GSL_Textures"
	base_dir = base_dir.rstrip("/")
	if not material_name.is_empty():
		base_dir += "/" + material_name

	var project_abs := ProjectSettings.globalize_path(base_dir)
	var dir := DirAccess.open(project_abs)
	if dir == null:
		var mk_err := DirAccess.make_dir_recursive_absolute(project_abs)
		if mk_err != OK:
			return raw_path
		dir = DirAccess.open(project_abs)
	var file_name := raw_path.get_file()
	var dst_abs := project_abs.path_join(file_name)
	if FileAccess.file_exists(dst_abs):
		var src_f := FileAccess.open(abs_src, FileAccess.READ)
		var dst_f := FileAccess.open(dst_abs, FileAccess.READ)
		if src_f and dst_f and src_f.get_length() == dst_f.get_length():
			return base_dir + "/" + file_name
	DirAccess.copy_absolute(abs_src, dst_abs)
	return base_dir + "/" + file_name
