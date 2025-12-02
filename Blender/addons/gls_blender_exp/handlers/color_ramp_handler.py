# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Обработчик ShaderNodeValToRGB (Color Ramp) для экспортера GSL.

Новая логика (v0.3+):
- Без LUT и mulbias/edge.
- Всегда экспортируем все точки ColorRamp как массив stops.
- Режим интерполяции сводим к двум вариантам: CONSTANT или LINEAR
  (режим EASE и прочие сводятся к LINEAR).

Экспортируемые функции:
- handle(n, node_info: dict, params: dict, mat) -> None
"""

from ..logger import get_logger

try:
    import bpy  # type: ignore
except Exception:
    bpy = None  # type: ignore

logger = get_logger().getChild("handlers.color_ramp")


def _get_interp(coba) -> str:
    try:
        return str(getattr(coba, "interpolation", getattr(coba, "ipotype", "LINEAR")).upper())
    except Exception:
        return "LINEAR"


def _color4_from_element(el):
    try:
        c = getattr(el, "color")
        return float(c[0]), float(c[1]), float(c[2]), float(c[3])
    except Exception:
        # Legacy fields r,g,b,a
        return (
            float(getattr(el, "r", 0.0)),
            float(getattr(el, "g", 0.0)),
            float(getattr(el, "b", 0.0)),
            float(getattr(el, "a", 1.0)),
        )
def handle(n, node_info: dict, params: dict, mat) -> None:
    # Обозначаем класс Godot-узла явно
    node_info["class"] = "ColorRampModule"
    # Уточняем сокеты для UI/отладки
    node_info["inputs"] = ["Fac"]
    node_info["outputs"] = ["Color", "Alpha"]

    try:
        coba = n.color_ramp
    except Exception:
        coba = None

    if not coba or getattr(coba, "elements", None) is None or len(coba.elements) < 1:
        logger.warning("ColorRamp без точек, узел будет проигнорирован")
        return

    stops = []
    try:
        for el in coba.elements:
            pos = float(getattr(el, "position", getattr(el, "pos", 0.0)))
            r, g, b, a = _color4_from_element(el)
            stops.append([pos, [r, g, b, a]])
    except Exception as exc:
        logger.error(f"Не удалось собрать точки ColorRamp '{getattr(n, 'name', '?')}': {exc}")
        return

    if not stops:
        logger.warning("ColorRamp без валидных точек, узел будет проигнорирован")
        return

    params["stops"] = stops

    interp = _get_interp(coba)
    if interp == "CONSTANT":
        params["mode"] = "CONSTANT"
    else:
        # LINEAR, EASE и всё остальное сводим к LINEAR.
        params["mode"] = "LINEAR"
