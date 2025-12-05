@tool
extends PanelContainer


signal create_shader
signal create_material
signal cpu_data
signal custom_action


func _on_create_shader_pressed() -> void:
	create_shader.emit()

func _on_create_material_pressed() -> void:
	create_material.emit()

func _on_cpu_data_pressed() -> void:
	cpu_data.emit()
