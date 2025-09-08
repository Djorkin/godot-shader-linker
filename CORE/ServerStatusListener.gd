# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name ServerStatusListener

var udp: PacketPeerUDP
var thread: Thread
var running: bool = false
@export var port: int = 6020  # UDP port to listen for Blender messages

func _init(p_port: int = 6020):
	port = p_port

# Start background UDP listening
func start() -> void:
	if running:
		return

	udp = PacketPeerUDP.new()
	var err := udp.bind(port, "127.0.0.1")
	if err != OK:
		push_error("Failed to bind UDP port %d (%s)" % [port, str(err)])
		return

	running = true
	thread = Thread.new()
	thread.start(Callable(self, "listen"))

# Gracefully stop the listener
func stop() -> void:
	if not running:
		return
	running = false

	if thread and thread.is_alive():
		thread.wait_to_finish()
	thread = null

	if udp:
		udp.close()
	udp = null

# Internal loop to receive server status
func listen() -> void:
	while running:
		while udp and udp.get_available_packet_count() > 0:
			var bytes := udp.get_packet()
			var txt := bytes.get_string_from_utf8()
			var obj := JSON.parse_string(txt)
			if typeof(obj) != TYPE_DICTIONARY or not obj.has("status"):
				continue
			match obj["status"]:
				"started":
					print_rich("[color=green]Blender server started[/color]")
				"stopped":
					print_rich("[color=yellow]Blender server stopped[/color]")
		OS.delay_msec(100)
