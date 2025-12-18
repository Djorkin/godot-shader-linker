@tool
extends PanelContainer


signal create_shader
signal create_material
signal bake_aabb


func _on_create_shader_pressed() -> void:
	create_shader.emit()

func _on_create_material_pressed() -> void:
	create_material.emit()

func _on_bake_aabb_pressed() -> void:
	bake_aabb.emit()
