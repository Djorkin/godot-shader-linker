@tool
extends MarginContainer



signal debug_logging_changed(enabled: bool)
signal json_debug_changed(enabled: bool)
signal json_dir_path_changed(path: String)
signal save_tex_path_changed(path: String)


func set_debug_logging_enabled(enabled: bool) -> void:
	var check_box: CheckBox = %use_debug
	check_box.button_pressed = enabled


func set_json_debug_enabled(enabled: bool) -> void:
	var check_box: CheckBox = %use_json
	check_box.button_pressed = enabled


func set_json_dir_path(path: String) -> void:
	var line_edit: LineEdit = %Save_Json
	line_edit.text = path


func set_tex_dir_path(path: String) -> void:
	var line_edit: LineEdit = %Save_tex
	line_edit.text = path

func _on_use_debug_toggled(toggled_on: bool) -> void:
	debug_logging_changed.emit(toggled_on)


func _on_use_json_toggled(toggled_on: bool) -> void:
	json_debug_changed.emit(toggled_on)


func _on_save_json_text_changed(new_text: String) -> void:
	json_dir_path_changed.emit(new_text)


func _on_save_tex_text_changed(new_text: String) -> void:
	save_tex_path_changed.emit(new_text)
