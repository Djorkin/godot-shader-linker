@tool
extends EditorPlugin

var my_ui
var shortcut: Shortcut

func _enter_tree():
	my_ui = preload("res://addons/godot_shader_linker_(gsl)/UI/GSL_Editor.tscn").instantiate()
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_BOTTOM, my_ui)
	my_ui.request_cpu_data_update.connect(_on_request_cpu_data_update)
	
	shortcut = Shortcut.new()
	var input_event = InputEventKey.new()
	input_event.keycode = KEY_G
	input_event.ctrl_pressed = true
	shortcut.events = [input_event]
	
	if not InputMap.has_action("gsl_toggle_panel"):
		InputMap.add_action("gsl_toggle_panel")
	var evs := InputMap.action_get_events("gsl_toggle_panel")
	if evs.is_empty():
		InputMap.action_add_event("gsl_toggle_panel", input_event)
	
	update_keybindings()

func _exit_tree():
	if my_ui:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_BOTTOM, my_ui)
		my_ui.queue_free()
	
	if InputMap.has_action("gsl_toggle_panel"):
		InputMap.erase_action("gsl_toggle_panel")

func _input(event: InputEvent):
	if Engine.is_editor_hint() and InputMap.has_action("gsl_toggle_panel"):
		if event.is_action_pressed("gsl_toggle_panel"):
			toggle_panel()

func toggle_panel():
	if my_ui:
		my_ui.visible = !my_ui.visible
		get_editor_interface().get_base_control().queue_redraw()

func update_keybindings():
	var editor_settings = get_editor_interface().get_editor_settings()
	editor_settings.set_setting("shortcuts/gsl_toggle_panel", shortcut)

func _get_plugin_name():
	return "GSL"

func _get_plugin_icon():
	return get_editor_interface().get_editor_theme().get_icon("Shader", "EditorIcons")

func _on_request_cpu_data_update() -> void:
	var root = get_editor_interface().get_edited_scene_root()
	if root:
		CpuShaderData.update_subtree(root, true)
