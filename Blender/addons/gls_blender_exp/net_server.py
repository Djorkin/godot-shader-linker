# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

from __future__ import annotations

from .server import launch_server as _server_launch, stop_server as _server_stop
from .exporter import (
    collect_material_data as _export_collect,
    gather_material as _export_gather,
)


def launch_server() -> None:
    _server_launch()


def stop_server() -> None:
    _server_stop()


def _collect_material_data() -> dict:
    return _export_collect()


def _gather_material() -> dict:
    return _export_gather()