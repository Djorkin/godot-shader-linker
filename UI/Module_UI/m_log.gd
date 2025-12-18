@tool
extends PanelContainer

var GSL_logger: GslLogger = GslLogger.get_logger()
var max_lines: int = 10000


@onready var log: RichTextLabel = %Log
@onready var clear_button: Button = %ClearButton


func _ready() -> void:
	clear_button.icon = get_theme_icon("Clear", "EditorIcons")


func append_line(text: String) -> void:
	log.text += text + "\n"
	if max_lines > 0:
		var line_count := log.get_line_count()
		if line_count > max_lines:
			var start := line_count - max_lines
			var kept := log.text.get_slice("\n", start)
			log.text = kept + "\n"
			GSL_logger.log_warning("Log truncated to %s lines" % max_lines)


func clear() -> void:
	log.clear()
	log.text = ""


func _on_clear_button_pressed() -> void:
	clear()
