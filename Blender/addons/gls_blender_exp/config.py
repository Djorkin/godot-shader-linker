# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Конфигурация аддона GSL Exporter: сетевые параметры и вспомогательные функции.

Назначение:
- Хранить HOST/PORT и порты UDP для статусов/логов.
- Возвращать базовый путь экспорта в проект Godot из настроек аддона.

Конфигурация аддона GSL Exporter.
Здесь хранятся сетевые параметры и функции доступа к путям проекта.
"""

from __future__ import annotations

try:
    import bpy  # type: ignore
except Exception:
    bpy = None  # type: ignore

# Хост и порт HTTP‑сервера для обмена данными с Godot
HOST: str = "127.0.0.1"
PORT: int = 5050

# Порт для UDP‑уведомлений о статусе (started/stopped)
GODOT_UDP_PORT: int = 6020

# Порт для UDP‑логов (структурированный JSON)
LOG_UDP_PORT: int = 6021

# Имя каталога в корне проекта Godot для копирования текстур
TEXTURE_DIR_NAME: str = "GSL_Texture"


def get_export_base_dir() -> str:
    """
    Возвращает путь к корню проекта Godot, куда копируются текстуры.
    Источник — настройки аддона (Addon Preferences > godot_project_path).
    Пустая строка означает, что копирование отключено.
    """
    try:
        if bpy is None:
            return ""
        for _ad_name, ad in bpy.context.preferences.addons.items():
            prefs = getattr(ad, "preferences", None)
            if prefs and hasattr(prefs, "godot_project_path"):
                return prefs.godot_project_path
    except Exception:
        pass
    return ""
