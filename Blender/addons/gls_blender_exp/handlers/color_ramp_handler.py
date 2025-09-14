# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Обработчик ShaderNodeValToRGB (Color Ramp) для экспортера GSL.

Логика:
- Оптимизация (без текстуры): если в ColorRamp ровно 2 точки, режим RGB,
  и тип интерполяции Constant/Linear/Ease — отдаём edge/mulbias и color1/color2,
  устанавливаем opt_mode в CONST/LINEAR/EASE.
- Общий случай: выпекаем LUT 257x1 PNG с помощью Blender API, записываем image_path,
  устанавливаем opt_mode=LUT и, если интерполяция Constant, ставим lut_nearest=true.

Экспортируемые функции:
- handle(n, node_info: dict, params: dict, mat) -> None
"""

from ..config import get_export_base_dir, TEXTURE_DIR_NAME
from ..utils import sanitize
from ..logger import get_logger

try:
    import bpy  # type: ignore
except Exception:
    bpy = None  # type: ignore

import os

logger = get_logger().getChild("handlers.color_ramp")


def _is_two_point_rgb_linear(coba) -> bool:
    try:
        if getattr(coba, "tot", 0) != 2:
            return False
        if str(getattr(coba, "color_mode", "RGB")).upper() != "RGB":
            return False
        ip = str(getattr(coba, "interpolation", getattr(coba, "ipotype", "LINEAR"))).upper()
        return ip in ("LINEAR", "CONSTANT", "EASE")
    except Exception:
        return False


def _get_interp(coba) -> str:
    try:
        return str(getattr(coba, "interpolation", getattr(coba, "ipotype", "LINEAR")).upper())
    except Exception:
        return "LINEAR"


def _compute_mulbias_and_edge(coba):
    e0, e1 = coba.elements[0], coba.elements[1]
    p0 = float(getattr(e0, "position", getattr(e0, "pos", 0.0)))
    p1 = float(getattr(e1, "position", getattr(e1, "pos", 1.0)))
    ip = _get_interp(coba)
    if ip == "CONSTANT":
        edge = max(p0, p1)
        return (None, edge)
    # LINEAR and EASE use mul_bias
    denom = max(1e-8, (p1 - p0))
    mul = 1.0 / denom
    bias = -mul * p0
    return ((mul, bias), None)


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


def _bake_lut_png(n, mat, width=257) -> str | None:
    if bpy is None:
        return None
    try:
        coba = n.color_ramp
        export_base = get_export_base_dir()
        if not export_base:
            return None
        mat_name_safe = sanitize(mat.name)
        node_name_safe = sanitize(n.name)
        tex_dir = os.path.join(export_base, TEXTURE_DIR_NAME, mat_name_safe)
        os.makedirs(tex_dir, exist_ok=True)
        file_name = f"colorramp_{node_name_safe}_{width}.png"
        dest_path = os.path.join(tex_dir, file_name)

        img = bpy.data.images.new(name=f"GSL_ColorRamp_{node_name_safe}", width=width, height=1, alpha=True, float_buffer=False)
        pixels = [0.0] * (width * 4)
        # Заполняем по центрам пикселей: i in [0..width-1] → fac=i/(width-1)
        for i in range(width):
            fac = i / float(width - 1)
            col = coba.evaluate(fac)
            r, g, b, a = float(col[0]), float(col[1]), float(col[2]), float(col[3])
            idx = i * 4
            pixels[idx + 0] = r
            pixels[idx + 1] = g
            pixels[idx + 2] = b
            pixels[idx + 3] = a
        img.pixels = pixels
        img.file_format = 'PNG'
        img.filepath_raw = dest_path
        img.save()
        # Освобождаем Image из bpy, чтобы не копился мусор
        bpy.data.images.remove(img)

        rel_path = os.path.relpath(dest_path, export_base).replace("\\", "/")
        return f"res://{rel_path}"
    except Exception as e:
        logger.error(f"Не удалось выпечь LUT для ColorRamp '{getattr(n, 'name', '?')}': {e}")
        return None


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

    # Оптимизированный путь (2 точки, RGB, Constant/Linear/Ease)
    if coba and _is_two_point_rgb_linear(coba):
        e0, e1 = coba.elements[0], coba.elements[1]
        c0 = _color4_from_element(e0)
        c1 = _color4_from_element(e1)
        interp = _get_interp(coba)
        if interp == "CONSTANT":
            _, edge = _compute_mulbias_and_edge(coba)
            params["edge"] = float(edge)
            params["color1"] = list(c0)
            params["color2"] = list(c1)
            params["opt_mode"] = 1  # CONST
        else:
            (mul, bias), _ = _compute_mulbias_and_edge(coba)
            params["mulbias"] = [float(mul), float(bias), 0.0]
            params["color1"] = list(c0)
            params["color2"] = list(c1)
            params["opt_mode"] = 2 if interp == "LINEAR" else 3  # LINEAR/EASE
        return

    # Общий случай — LUT
    lut_path = _bake_lut_png(n, mat, width=257)
    if lut_path:
        params["image_path"] = lut_path
    interp = _get_interp(getattr(n, "color_ramp", None)) if getattr(n, "color_ramp", None) else "LINEAR"
    params["lut_nearest"] = bool(interp == "CONSTANT")
    params["opt_mode"] = 0  # LUT
