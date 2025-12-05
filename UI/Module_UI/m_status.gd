@tool
extends PanelContainer


@onready var color_rect: TextureRect = %ColorRect
@onready var info: Label = %Info
@onready var shader = preload("res://addons/godot_shader_linker_(gsl)/UI/status_dot.gdshader")


func _ready() -> void:
	color_rect.material = ShaderMaterial.new()
	color_rect.material.shader = shader
	color_rect.material.set_shader_parameter("dot_color", Color.GRAY)
	color_rect.material.set_shader_parameter("radius", 0.07)
	color_rect.material.set_shader_parameter("edge_smooth", 0.17)

func set_status(status: ServerStatusListener.Status) -> void:
	info.text = ServerStatusListener.get_status_message(status)
	color_rect.material.set_shader_parameter("dot_color", ServerStatusListener.get_status_color(status))
