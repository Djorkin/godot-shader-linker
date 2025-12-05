extends RefCounted
class_name GslLogger

var debug_logging: bool = false

enum LogLevel {
	INFO,
	WARNING,
	ERROR,
	DEBUG
}

signal message_emitted(message: String)

func log_(message: String, level: LogLevel = LogLevel.INFO) -> void:
	message_emitted.emit(message)

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
