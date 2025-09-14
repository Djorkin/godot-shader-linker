# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Система логирования GSL.

Назначение:
- Единая точка получения настроенного логгера.
- Вывод в консоль Blender, в UDP (Godot) и накопление в памяти для /logs.

Экспортируемые функции:
- get_logger(reconfigure: bool = False) -> logging.Logger
- get_logs(limit: int | None = None) -> list[dict]
"""

from __future__ import annotations

import json
import logging
import socket
from datetime import datetime, timezone
from collections import deque
import threading

try:
    import bpy  # type: ignore
except Exception:
    bpy = None  # type: ignore

from .config import HOST, LOG_UDP_PORT


def _read_logging_prefs() -> dict:
    """
    Читает настройки логирования из Addon Preferences.
    Возвращает словарь с ключами: debug_logging (bool), log_to_console, log_to_godot, log_udp_port.
    """
    cfg = {
        "debug_logging": False,
        "log_to_console": True,
        "log_to_godot": True,
        "log_udp_port": LOG_UDP_PORT,
    }
    try:
        if bpy is None:
            return cfg
        addon_key = (__package__ or __name__).split(".")[0]
        ad = bpy.context.preferences.addons.get(addon_key)
        prefs = getattr(ad, "preferences", None) if ad else None
        if not prefs:
            return cfg
        cfg["debug_logging"] = bool(getattr(prefs, "debug_logging", cfg["debug_logging"]))
        cfg["log_to_console"] = bool(getattr(prefs, "log_to_console", cfg["log_to_console"]))
        cfg["log_to_godot"] = bool(getattr(prefs, "log_to_godot", cfg["log_to_godot"]))
        cfg["log_udp_port"] = int(getattr(prefs, "log_udp_port", cfg["log_udp_port"]))
    except Exception as e:
        logging.getLogger("GSL.logger").debug(f"_read_logging_prefs failed: {e}")
    return cfg


class _UDPLogHandler(logging.Handler):
    """
    Отправляет записи логов по UDP в Godot в формате JSON.
    """

    def __init__(self, host: str, port: int) -> None:
        super().__init__()
        self._host = host
        self._port = port

    def emit(self, record: logging.LogRecord) -> None:
        try:
            # Текст сообщения формируется форматтером logging
            msg = self.format(record)
            payload = {
                "type": "log",
                "level": record.levelname,
                "message": msg,
                "scope": record.name,
                "ts": datetime.now(timezone.utc).isoformat(),
            }
            data = json.dumps(payload, ensure_ascii=False).encode()
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sock.sendto(data, (self._host, self._port))
            sock.close()
        except Exception:
            # Никогда не пробрасываем исключения из логгера
            pass


class _MemoryLogHandler(logging.Handler):
    """
    Память логов в оперативной памяти (кольцевой буфер) для выдачи через HTTP /logs.
    """

    def __init__(self) -> None:
        super().__init__()

    def emit(self, record: logging.LogRecord) -> None:
        try:
            msg = self.format(record)
            entry = {
                "level": record.levelname,
                "message": msg,
                "scope": record.name,
                "ts": datetime.now(timezone.utc).isoformat(),
            }
            with _LOG_LOCK:
                _LOG_BUFFER.append(entry)
        except Exception:
            pass


_LOGGER_NAME = "GSL"
_LOGGER_CONFIGURED = False
_LOG_BUFFER: deque[dict] = deque(maxlen=200)
_LOG_LOCK = threading.Lock()


def get_logger(reconfigure: bool = False) -> logging.Logger:
    """
    Возвращает настроенный логгер GSL.
    При reconfigure=True перечитывает настройки и перенастраивает хендлеры.
    """
    global _LOGGER_CONFIGURED
    logger = logging.getLogger(_LOGGER_NAME)
    if _LOGGER_CONFIGURED and not reconfigure:
        return logger

    cfg = _read_logging_prefs()

    # Базовый уровень логгера: DEBUG при включённом дебаге, иначе ERROR
    logger.setLevel(logging.DEBUG if cfg.get("debug_logging", False) else logging.ERROR)
    logger.propagate = False

    # Очистить прошлые хендлеры
    logger.handlers[:] = []

    fmt = logging.Formatter("[GSL] %(levelname)s %(name)s: %(message)s")

    if cfg.get("log_to_console", True):
        sh = logging.StreamHandler()
        sh.setFormatter(fmt)
        logger.addHandler(sh)

    if cfg.get("log_to_godot", True):
        uh = _UDPLogHandler(HOST, int(cfg.get("log_udp_port", LOG_UDP_PORT)))
        # Для UDP берём только текст сообщения
        uh.setFormatter(logging.Formatter("%(message)s"))
        logger.addHandler(uh)

    # Память логов включена всегда для /logs
    mh = _MemoryLogHandler()
    mh.setFormatter(logging.Formatter("%(message)s"))
    logger.addHandler(mh)

    _LOGGER_CONFIGURED = True
    return logger


def get_logs(limit: int | None = None) -> list[dict]:
    """
    Возвращает копию буфера логов (последние limit записей, либо все, если limit не задан).
    """
    with _LOG_LOCK:
        data = list(_LOG_BUFFER)
    if limit is not None and limit > 0:
        return data[-limit:]
    return data
