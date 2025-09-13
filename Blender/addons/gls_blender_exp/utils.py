# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Утилиты общего назначения для экспортера GSL.

Экспортируемые функции:
- sanitize(text: str) -> str
- make_node_id(name: str, idx: int) -> str
- bl_to_gsl_class(bl_id: str) -> str
"""

import re


def sanitize(text: str) -> str:
    """
    Приводит текст к безопасному для идентификаторов виду: заменяет пробелы/точки на подчёркивания
    и убирает прочие недопустимые символы.
    """
    text = text.replace(" ", "_").replace(".", "_")
    return re.sub(r"[^0-9A-Za-z_]+", "_", text)


def make_node_id(name: str, idx: int) -> str:
    """
    Формирует детерминированный идентификатор узла вида: <sanitized_name>_NNN
    """
    return f"{sanitize(name)}_{idx:03d}"


def bl_to_gsl_class(bl_id: str) -> str:
    """
    Преобразует имя класса Blender (например, ShaderNodeMath) в имя модуля GSL (MathModule).
    """
    if bl_id.startswith("ShaderNode"):
        core = bl_id[len("ShaderNode"):]
    else:
        core = bl_id
    return f"{core}Module"
