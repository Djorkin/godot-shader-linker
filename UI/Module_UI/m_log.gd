@tool
extends PanelContainer



@onready var log: RichTextLabel = %Log
@onready var clear_button: Button = %ClearButton


func _ready() -> void:
	clear_button.icon = get_theme_icon("Clear", "EditorIcons")


func append_line(text: String) -> void:
	log.text += text + "\n"


func clear() -> void:
	log.clear()
	log.text = ""


func _on_clear_button_pressed() -> void:
	clear()
