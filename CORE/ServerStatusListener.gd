# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name ServerStatusListener

const SERVER_URL := Parser.SERVER_URL

enum Status {
	CONNECTED,
	DISCONNECTED,
	CHECKING_PORT,
	ERROR,
}

var udp: PacketPeerUDP
var udp_port: int = 6020
var udp_bind_failed: bool = false
var logger: GslLogger
var current_status: Status = Status.DISCONNECTED

signal server_status_changed(status: Status)


func _init(new_logger: GslLogger, p_port: int = 6020):
	logger = new_logger
	udp_port = p_port


func set_status(status: Status) -> void:
	if current_status == status:
		return
	current_status = status
	server_status_changed.emit(current_status)


static func get_status_color(status: Status) -> Color:
	match status:
		Status.CONNECTED:
			return Color.GREEN
		Status.CHECKING_PORT:
			return Color.YELLOW
		Status.DISCONNECTED:
			return Color.GRAY
		Status.ERROR:
			return Color.RED
		_:
			return Color.GRAY


static func get_status_message(status: Status) -> String:
	match status:
		Status.CONNECTED:
			return "Connected to Blender"
		Status.CHECKING_PORT:
			return "Checking port"
		Status.DISCONNECTED:
			return "Disconnected from Blender"
		Status.ERROR:
			return "Error"
		_:
			return "Unknown status"


func check_server() -> void:
	set_status(Status.CHECKING_PORT)
	var main_loop := Engine.get_main_loop()
	if main_loop and main_loop is SceneTree:
		var tree: SceneTree = main_loop
		var http := HTTPRequest.new()
		tree.root.add_child(http)
		http.request_completed.connect(_on_status_request_completed.bind(http))
		var err := http.request(SERVER_URL)
		if err != OK:
			set_status(Status.DISCONNECTED)
			logger.log_warning("[color=yellow]Failed to send status request (%s)[/color]" % err)
			http.queue_free()


func _on_status_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	if is_instance_valid(http):
		http.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS:
		set_status(Status.DISCONNECTED)
		logger.log_warning("[color=yellow]Blender server is not available (result %d)[/color]" % result)
		return
	
	if response_code != 200:
		set_status(Status.ERROR)
		logger.log_error("[color=red]Blender server returned code %d[/color]" % response_code)
		return
	
	if body.is_empty():
		set_status(Status.ERROR)
		logger.log_error("[color=red]Empty response from Blender server[/color]")
		return
	
	set_status(Status.CONNECTED)



func shutdown() -> void:
	set_status(Status.DISCONNECTED)
	if udp:
		udp.close()
		udp = null


func ensure_udp_bound() -> void:
	if udp or udp_bind_failed:
		return
	udp = PacketPeerUDP.new()
	var err := udp.bind(udp_port, "127.0.0.1")
	if err != OK:
		udp_bind_failed = true
		logger.log_warning("[color=yellow]Failed to bind UDP port %d (%s)[/color]" % [udp_port, str(err)])
		udp = null


func poll_udp() -> void:
	ensure_udp_bound()
	if not udp:
		return
	while udp.get_available_packet_count() > 0:
		var bytes := udp.get_packet()
		var txt := bytes.get_string_from_utf8()
		var obj := JSON.parse_string(txt)
		if typeof(obj) != TYPE_DICTIONARY or not obj.has("status"):
			continue
		match obj["status"]:
			"started":
				set_status(Status.CONNECTED)
			"stopped":
				set_status(Status.DISCONNECTED)
			"error":
				set_status(Status.ERROR)
