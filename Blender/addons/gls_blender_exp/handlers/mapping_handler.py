# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Обработчик ShaderNodeMapping для экспортера GSL.

Экспортируемые функции:
- handle(n, node_info: dict, params: dict, mat) -> None
"""

from ..utils import sanitize

def handle(n, node_info: dict, params: dict, mat) -> None:
    mapping_enum = getattr(n, "vector_type", "POINT")
    mapping_enum_map = {"POINT": 0, "TEXTURE": 1, "VECTOR": 2, "NORMAL": 3}
    params["mapping_type"] = mapping_enum_map.get(str(mapping_enum).upper(), 0)
    node_info["mode"] = getattr(n, "vector_type", "")
