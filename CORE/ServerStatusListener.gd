# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name ServerStatusListener

var _udp: PacketPeerUDP
var _thread: Thread
var _running: bool = false
@export var port: int = 6020  # UDP-порт, на котором слушаем сообщения от Blender

func _init(p_port: int = 6020):
	port = p_port

# Запуск фонового прослушивания UDP-порта
func start() -> void:
	if _running:
		return

	_udp = PacketPeerUDP.new()
	var err := _udp.bind(port, "127.0.0.1")
	if err != OK:
		push_error("Failed to bind UDP port %d (%s)" % [port, str(err)])
		return

	_running = true
	_thread = Thread.new()
	_thread.start(Callable(self, "_listen"))

# Корректное завершение работы слушателя
func stop() -> void:
	if not _running:
		return
	_running = false

	if _thread and _thread.is_alive():
		_thread.wait_to_finish()
	_thread = null

	if _udp:
		_udp.close()
	_udp = null

# Внутренний цикл получения статуса сервера
func _listen() -> void:
	while _running:
		while _udp and _udp.get_available_packet_count() > 0:
			var bytes := _udp.get_packet()
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
