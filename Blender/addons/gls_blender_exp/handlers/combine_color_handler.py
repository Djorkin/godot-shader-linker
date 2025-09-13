# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Обработчик ShaderNodeCombineColor для экспортера GSL.

Задачи:
- Проставить параметр mode: RGB=0, HSV=1, HSL=2.
- Нормализовать незапитанные входы к ключам r/g/b вне зависимости от режима (H/S/V/L → r/g/b).
- Опционально подсказать список видимых входов.

Экспортируемые функции:
- handle(n, node_info: dict, params: dict, mat) -> None
"""

from typing import Any


def _mode_index(n: Any) -> int:
    for attr in ("mode", "color_space", "space"):
        if hasattr(n, attr):
            try:
                val = str(getattr(n, attr)).upper()
                if "RGB" in val:
                    return 0
                if "HSV" in val:
                    return 1
                if "HSL" in val:
                    return 2
            except Exception:
                pass
    return 0


def handle(n, node_info: dict, params: dict, mat) -> None:
    m = _mode_index(n)
    params["mode"] = m

    # Normalize unlinked inputs to r/g/b keys
    # Blender sockets are R,G,B or H,S,V or H,S,L depending on mode.
    # Exporter has already filled params with lowercased names for unlinked sockets.
    def _move(src: str, dst: str):
        if src in params and dst not in params:
            params[dst] = params.pop(src)

    if m == 0:
        # RGB: map common Blender socket defaults 'red/green/blue' -> r/g/b
        _move("red", "r")
        _move("green", "g")
        _move("blue", "b")
    elif m == 1:
        # HSV: map h->r, s->g, v->b (and synonyms)
        for a, b in (("h", "r"), ("hue", "r"), ("s", "g"), ("saturation", "g"), ("v", "b"), ("value", "b")):
            _move(a, b)
        # Fallback if Blender still exposes red/green/blue keys while in HSV mode
        _move("red", "r")
        _move("green", "g")
        _move("blue", "b")
    else:
        # HSL: map h->r, s->g, l->b (and synonyms)
        for a, b in (("h", "r"), ("hue", "r"), ("s", "g"), ("saturation", "g"), ("l", "b"), ("lightness", "b")):
            _move(a, b)
        # Fallback if Blender still exposes red/green/blue keys while in HSL mode
        _move("red", "r")
        _move("green", "g")
        _move("blue", "b")

    try:
        if m == 0:
            node_info["inputs"] = ["R", "G", "B"]
        elif m == 1:
            node_info["inputs"] = ["H", "S", "V"]
        else:
            node_info["inputs"] = ["H", "S", "L"]
    except Exception:
        pass
