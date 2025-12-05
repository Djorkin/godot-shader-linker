# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

"""
HTTP/UDP сервер GSL. Отвечает на запросы Godot и уведомляет о статусе.
"""
from __future__ import annotations

import json
import threading
import socket
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

try:
    import bpy  # type: ignore
except Exception:
    bpy = None  # type: ignore

from .config import HOST, PORT, GODOT_UDP_PORT
from .exporter import collect_material_data

# Экземпляр HTTP‑сервера и поток его запуска
_server: HTTPServer | None = None
_server_thread: threading.Thread | None = None


class GSLRequestHandler(BaseHTTPRequestHandler):

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/link":
            self._handle_link()
        else:
            self.send_error(404)

    # Отключаем стандартный спам логов BaseHTTPRequestHandler в консоль
    def log_message(self, format, *args):  # noqa: A003  (совпадает по имени с базовым API)
        return

    def _handle_link(self):
        data = collect_material_data()
        payload = json.dumps(data, ensure_ascii=False).encode()

        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

def _send_udp_json(payload: dict, port: int):
    msg = json.dumps(payload).encode()
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.sendto(msg, (HOST, port))
    sock.close()


def _notify_godot(status: str):
    _send_udp_json({"status": status}, GODOT_UDP_PORT)


def _start_server():
    global _server
    _server = HTTPServer((HOST, PORT), GSLRequestHandler)
    _server.serve_forever()


def launch_server() -> None:
    global _server_thread
    if _server_thread and _server_thread.is_alive():
        return
    _server_thread = threading.Thread(target=_start_server, daemon=True)
    _server_thread.start()
    _notify_godot("started")


def stop_server() -> None:
    global _server, _server_thread
    if _server is None and (_server_thread is None or not _server_thread.is_alive()):
        return
    if _server:
        _server.shutdown()
        _server.server_close()
        _server = None
    if _server_thread and _server_thread.is_alive():
        _server_thread.join(timeout=1.0)
    _server_thread = None
    _notify_godot("stopped")
