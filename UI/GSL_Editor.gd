@tool
extends Control

var Parser_inst : Parser = Parser.new()
var SSL_inst : ServerStatusListener = ServerStatusListener.new()
var Saver_inst : ShaderSaver = ShaderSaver.new()
var GSL_logger : GslLogger = GslLogger.get_logger()

@onready var action_panel = %Action_Panel
@onready var status_module = %Status_Panel
@onready var log_module = %LOG
@onready var settings_ui = %Settings

enum SaveMode { NONE, SHADER, MATERIAL }
var save_mode: int = SaveMode.NONE


func _ready() -> void:
	add_child(Saver_inst)
	load_gsl_settings()
	SSL_inst.server_status_changed.connect(_on_server_status_changed)
	SSL_inst.check_server()
	status_module.refresh_status.connect(_on_refresh_status)
	SSL_inst.material_data_received.connect(_on_material_data_received)
	Parser_inst.builder_ready.connect(builder_ready)
	GSL_logger.message_emitted.connect(_on_log_message)
	action_panel.create_shader.connect(_on_create_shader_pressed)
	action_panel.create_material.connect(_on_create_material_pressed)
	action_panel.bake_aabb.connect(_on_bake_aabb_pressed)
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

func _on_refresh_status() -> void:
	if not SSL_inst:
		return
	GSL_logger.log_info("Refreshing server status")
	SSL_inst.check_server()

func _on_create_shader_pressed() -> void:
	save_mode = SaveMode.SHADER
	if _can_request_material():
		SSL_inst.request_material()

func _on_create_material_pressed() -> void:
	save_mode = SaveMode.MATERIAL
	if _can_request_material():
		SSL_inst.request_material()

func _on_bake_aabb_pressed() -> void:
	AabbBake.bake_subtree(get_tree().get_edited_scene_root())
	GSL_logger.log_success("AABB baked")

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
		Saver_inst.texture_base_dir = base_dir

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
		cleaned = "res://GSL_Textures"
	if not cleaned.begins_with("res://"):
		cleaned = "res://" + cleaned.trim_prefix("res://")
	if cleaned.ends_with("/"):
		cleaned = cleaned.left(cleaned.length() - 1)
	ProjectSettings.set_setting("gsl/texture_base_dir", cleaned)
	ProjectSettings.save()
	if Saver_inst:
		Saver_inst.texture_base_dir = cleaned

func _on_material_data_received(data: Dictionary) -> void:
	Parser_inst.data_transfer(data)


func _can_request_material() -> bool:
	if not SSL_inst:
		return false
	match SSL_inst.current_status:
		ServerStatusListener.Status.CONNECTED:
			return true
		ServerStatusListener.Status.DISCONNECTED:
			GSL_logger.log_warning("Cannot link material: Blender server is disconnected")
		ServerStatusListener.Status.CHECKING_PORT:
			GSL_logger.log_warning("Still checking Blender server status, please wait")
		ServerStatusListener.Status.ERROR:
			GSL_logger.log_error("Cannot link material: Blender server is in error state")
	return false
