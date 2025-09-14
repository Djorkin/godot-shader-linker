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
from .logger import get_logger, get_logs
from .exporter import collect_material_data

logger = get_logger().getChild("server")

# Экземпляр HTTP‑сервера и поток его запуска
_server: HTTPServer | None = None
_server_thread: threading.Thread | None = None


class GSLRequestHandler(BaseHTTPRequestHandler):
    """HTTP‑обработчик GSL: отдаёт JSON с описанием активного материала."""

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/link":
            self._handle_link()
        elif parsed.path == "/logs":
            self._handle_logs(parsed.query)
        else:
            self.send_error(404)

    # Отключаем стандартный спам логов BaseHTTPRequestHandler в консоль
    def log_message(self, format, *args):  # noqa: A003  (совпадает по имени с базовым API)
        return

    def _handle_link(self):
        """Сериализует активный материал в JSON и отправляет клиенту."""
        data = collect_material_data()
        payload = json.dumps(data, ensure_ascii=False).encode()

        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def _handle_logs(self, query: str):
        """Выдаёт последние записи логов. Параметр limit ограничивает количество."""
        try:
            args = parse_qs(query)
            limit = None
            if "limit" in args and args["limit"]:
                try:
                    limit = int(args["limit"][0])
                except Exception:
                    limit = None
            data = get_logs(limit=limit)
            payload = json.dumps(data, ensure_ascii=False).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        except Exception as e:
            logger.error(f"Ошибка отдачи логов: {e}")
            self.send_error(500)


def _send_udp_json(payload: dict, port: int):
    """Отправляет JSON‑сообщение по UDP (используется для статусов)."""
    try:
        msg = json.dumps(payload).encode()
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.sendto(msg, (HOST, port))
        sock.close()
    except Exception as e:
        logger.error(f"Не удалось отправить UDP на порт {port}: {e}")


def _notify_godot(status: str):
    """Посылает статус сервера в Godot."""
    _send_udp_json({"status": status}, GODOT_UDP_PORT)


def _start_server():
    """Создаёт и запускает HTTP‑сервер (внутренний рабочий поток)."""
    global _server
    try:
        _server = HTTPServer((HOST, PORT), GSLRequestHandler)
        _server.serve_forever()
    except Exception as e:
        logger.error(f"HTTP‑сервер остановлен: {e}")


def launch_server() -> None:
    """Запускает сервер в отдельном демонизированном потоке (если еще не запущен)."""
    global _server_thread
    if _server_thread and _server_thread.is_alive():
        return
    _server_thread = threading.Thread(target=_start_server, daemon=True)
    _server_thread.start()
    logger.info(f"HTTP‑сервер запущен: http://{HOST}:{PORT}")
    _notify_godot("started")


def stop_server() -> None:
    """Останавливает сервер и поток запуска, отправляет уведомление в Godot."""
    global _server, _server_thread
    if _server is None and (_server_thread is None or not _server_thread.is_alive()):
        return
    if _server:
        try:
            _server.shutdown()
            _server.server_close()
        except Exception as e:
            logger.error(f"Ошибка остановки сервера: {e}")
        _server = None
    if _server_thread and _server_thread.is_alive():
        _server_thread.join(timeout=1.0)
    _server_thread = None
    _notify_godot("stopped")
    logger.info("HTTP‑сервер остановлен")
