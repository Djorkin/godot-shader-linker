@tool
extends EditorPlugin

var my_ui = preload("res://addons/godot_shader_linker_(gsl)/UI/GSL_Editor.tscn")
var bottom_button


func _enter_tree():
	my_ui = my_ui.instantiate()
	bottom_button = add_control_to_bottom_panel(my_ui, "Shader Linker")
	my_ui.request_cpu_data_update.connect(_on_request_cpu_data_update)

func _exit_tree():
	if my_ui:
		remove_control_from_bottom_panel(my_ui)
		my_ui.queue_free()

func _get_plugin_name():
	return "Shader Linker"

func _get_plugin_icon():
	return get_editor_interface().get_editor_theme().get_icon("Shader", "EditorIcons")

func _on_request_cpu_data_update() -> void:
	var root = get_editor_interface().get_edited_scene_root()
	if root:
		CpuShaderData.update_subtree(root, true)
