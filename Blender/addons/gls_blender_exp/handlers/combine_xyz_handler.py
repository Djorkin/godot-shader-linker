# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Обработчик ShaderNodeCombineXYZ для экспортера GSL.

Экспортируемые функции:
- handle(n, node_info: dict, params: dict, mat) -> None
"""

def handle(n, node_info: dict, params: dict, mat) -> None:
    # Экспортер уже положит незапитанные значения X/Y/Z в params["x"/"y"/"z"].
    # Здесь можно только подсказать сигнатуру входов для отладки/UI.
    try:
        node_info["inputs"] = ["X", "Y", "Z"]
    except Exception:
        pass
