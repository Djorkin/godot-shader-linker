@tool
extends Control

var Parser_inst : Parser
var SSL_inst : ServerStatusListener 
var Saver_inst : ShaderSaver 
var GSL_logger : GslLogger

@onready var action_panel = %Action_Panel
@onready var status_module = %Status_Panel
@onready var log_module = %LOG
@onready var settings_ui = %Settings

enum SaveMode { NONE, SHADER, MATERIAL }
var save_mode: int = SaveMode.NONE

signal request_cpu_data_update


func _init() -> void:
	Saver_inst = ShaderSaver.new()
	GSL_logger = GslLogger.new()	
	Parser_inst = Parser.new(GSL_logger)
	SSL_inst = ServerStatusListener.new(GSL_logger)


func _ready() -> void:
	add_child(Saver_inst)
	load_gsl_settings()
	SSL_inst.server_status_changed.connect(_on_server_status_changed)
	SSL_inst.check_server()
	Parser_inst.builder_ready.connect(builder_ready)
	GSL_logger.message_emitted.connect(_on_log_message)
	action_panel.create_shader.connect(_on_create_shader_pressed)
	action_panel.create_material.connect(_on_create_material_pressed)
	action_panel.cpu_data.connect(_on_cpu_data_pressed)
	settings_ui.debug_logging_changed.connect(_on_debug_logging_changed)
	settings_ui.json_debug_changed.connect(_on_json_debug_changed)
	settings_ui.json_dir_path_changed.connect(_on_json_dir_path_changed)
	settings_ui.save_tex_path_changed.connect(_on_save_tex_path_changed)

func _exit_tree() -> void:
	if SSL_inst:
		SSL_inst.shutdown()
		SSL_inst = null


func _process(_delta: float) -> void:
	if SSL_inst:
		SSL_inst.poll_udp()

func _on_server_status_changed(status: ServerStatusListener.Status) -> void:
	call_deferred("update_server_status", status)

func update_server_status(status: ServerStatusListener.Status) -> void:
	status_module.set_status(status)

func _on_log_message(text: String) -> void:
	log_module.append_line(text)

func _on_create_shader_pressed() -> void:
	save_mode = SaveMode.SHADER
	Parser_inst.send_request()

func _on_create_material_pressed() -> void:
	save_mode = SaveMode.MATERIAL
	Parser_inst.send_request()

func _on_cpu_data_pressed() -> void:
	emit_signal("request_cpu_data_update")

func builder_ready(builder: ShaderBuilder) -> void:
	if save_mode == SaveMode.SHADER:
		Saver_inst.save_shader_dialog(builder)
	elif save_mode == SaveMode.MATERIAL:
		Saver_inst.save_material_dialog(builder)
	save_mode = SaveMode.NONE


func _on_debug_logging_changed(enabled: bool) -> void:
	GSL_logger.debug_logging = enabled
	ProjectSettings.set_setting("gsl/debug_logging", enabled)
	ProjectSettings.save()


func _on_json_debug_changed(enabled: bool) -> void:
	Parser_inst.json_debug_enabled = enabled
	ProjectSettings.set_setting("gsl/json_debug_enabled", enabled)
	ProjectSettings.save()


func _on_json_dir_path_changed(path: String) -> void:
	Parser_inst.set_json_dir_path(path)
	ProjectSettings.set_setting("gsl/json_dir_path", path)
	ProjectSettings.save()


func load_gsl_settings() -> void:
	var debug_enabled := ProjectSettings.get_setting("gsl/debug_logging", false)
	var json_enabled := ProjectSettings.get_setting("gsl/json_debug_enabled", false)
	var json_path := str(ProjectSettings.get_setting("gsl/json_dir_path", "user://gsl_logs"))
	var base_dir := str(ProjectSettings.get_setting("gsl/texture_base_dir", "res://GSL_Textures"))

	if Saver_inst:
		Saver_inst.save_path = base_dir

	GSL_logger.debug_logging = debug_enabled
	Parser_inst.json_debug_enabled = json_enabled
	Parser_inst.set_json_dir_path(json_path)

	if settings_ui:
		settings_ui.set_debug_logging_enabled(debug_enabled)
		settings_ui.set_json_debug_enabled(json_enabled)
		settings_ui.set_json_dir_path(json_path)
		settings_ui.set_tex_dir_path(base_dir)



func _on_save_tex_path_changed(path: String) -> void:
	var cleaned := path.strip_edges()
	if cleaned.is_empty():
		return
	if not cleaned.begins_with("res://"):
		cleaned = "res://" + cleaned.trim_prefix("res://")
	if cleaned.ends_with("/"):
		cleaned = cleaned.left(cleaned.length() - 1)
	ProjectSettings.set_setting("gsl/texture_base_dir", cleaned)
	ProjectSettings.save()
	if Saver_inst:
		Saver_inst.save_path = cleaned
