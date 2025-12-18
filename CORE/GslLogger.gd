extends RefCounted
class_name GslLogger

var debug_logging: bool = false

static var instance: GslLogger

static func get_logger() -> GslLogger:
	if instance == null:
		instance = GslLogger.new()
	return instance

enum LogLevel {
	SUCCESS,
	INFO,
	WARNING,
	ERROR,
	DEBUG
}

signal message_emitted(message: String)

func log_(message: String, level: LogLevel = LogLevel.INFO) -> void:
	var prefix := ""
	var color := Color.WHITE
	match level:
		LogLevel.SUCCESS: 
			prefix = "[SUCCESS]"
			color = Color.GREEN
		LogLevel.WARNING: 
			prefix = "[WARNING]"
			color = Color.YELLOW
		LogLevel.ERROR: 
			prefix = "[ERROR]"
			color = Color.RED
		LogLevel.DEBUG: 
			color = Color.WEB_GRAY
		_: 
			color = Color.WHITE
	var formatted := "[color=#%s]%s %s[/color]" % [color.to_html(), prefix, message]
	message_emitted.emit(formatted)

func log_info(message: String) -> void:
	log_(message, LogLevel.INFO)

func log_warning(message: String) -> void:
	log_(message, LogLevel.WARNING)

func log_error(message: String) -> void:
	log_(message, LogLevel.ERROR)

func log_debug(message: String) -> void:
	if not debug_logging:
		return
	log_(message, LogLevel.DEBUG)

func log_success(message: String) -> void:
	log_(message, LogLevel.SUCCESS)
