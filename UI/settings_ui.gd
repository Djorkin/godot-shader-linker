@tool
extends MarginContainer


@onready var use_debug: CheckBox = %use_debug
@onready var use_json: CheckBox = %use_json
@onready var save_json: LineEdit = %Save_Json
@onready var save_tex: LineEdit = %Save_tex

signal debug_logging_changed(enabled: bool)
signal json_debug_changed(enabled: bool)
signal json_dir_path_changed(path: String)
signal save_tex_path_changed(path: String)


func _ready() -> void:
	save_json.placeholder_text = "user://gsl_logs"
	save_tex.placeholder_text = "res://GSL_Textures"
	save_json.editable = ProjectSettings.get_setting("gsl/json_debug_enabled", false)


func set_debug_logging_enabled(enabled: bool) -> void:
	use_debug.button_pressed = enabled


func set_json_debug_enabled(enabled: bool) -> void:
	use_json.button_pressed = enabled


func set_json_dir_path(path: String) -> void:
	save_json.text = path

func set_tex_dir_path(path: String) -> void:
	save_tex.text = path

func _on_use_debug_toggled(toggled_on: bool) -> void:
	debug_logging_changed.emit(toggled_on)


func _on_use_json_toggled(toggled_on: bool) -> void:
	json_debug_changed.emit(toggled_on)
	if not toggled_on:
		save_json.editable = false
	else:
		save_json.editable = true


func _on_save_json_text_changed(new_text: String) -> void:
	json_dir_path_changed.emit(new_text)


func _on_save_tex_text_changed(new_text: String) -> void:
	save_tex_path_changed.emit(new_text)
