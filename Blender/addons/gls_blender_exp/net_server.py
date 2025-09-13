# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Фасад сервера GSL.
Назначение: предоставить стабильные точки входа для внешнего кода и
сохранить обратную совместимость, делегируя работу специализированным модулям.

Экспортируемые функции:
- launch_server()         — запуск HTTP/UDP‑сервера (делегирует в server.launch_server)
- stop_server()           — остановка HTTP/UDP‑сервера (делегирует в server.stop_server)
- _collect_material_data() — сбор описания текущего материала (в главном потоке)
- _gather_material()       — непосредственный сбор данных материала (только в главном потоке)
"""

from __future__ import annotations

from .server import launch_server as _server_launch, stop_server as _server_stop
from .exporter import (
    collect_material_data as _export_collect,
    gather_material as _export_gather,
)


def launch_server() -> None:
    """Запускает HTTP/UDP‑сервер GSL.
    Делегирует выполнение в server.launch_server().
    """
    _server_launch()


def stop_server() -> None:
    """Останавливает HTTP/UDP‑сервер GSL.
    Делегирует выполнение в server.stop_server().
    """
    _server_stop()


def _collect_material_data() -> dict:
    """Возвращает JSON‑описание активного материала, гарантируя выполнение в главном потоке Blender.
    Делегирует выполнение в exporter.collect_material_data().
    """
    return _export_collect()


def _gather_material() -> dict:
    """Собирает данные материала. Должно вызываться только из главного потока Blender.
    Делегирует выполнение в exporter.gather_material().
    """
    return _export_gather()