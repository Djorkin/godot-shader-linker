# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Обработчик ShaderNodeTexImage для экспортера GSL: чтение настроек изображения и опциональное копирование текстур в проект Godot.

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
import shutil

logger = get_logger().getChild("handlers.tex_image")


def handle(n, node_info: dict, params: dict, mat) -> None:
    # интерполяция
    interp_map = {"Linear": 0, "Closest": 1, "Cubic": 2}
    params["interpolation"] = interp_map.get(getattr(n, "interpolation", "Linear"), 0)

    # проекция
    proj_map = {"FLAT": 0, "BOX": 1, "SPHERE": 2, "TUBE": 3}
    params["projection"] = proj_map.get(getattr(n, "projection", "FLAT"), 0)

    # смешивание по коробке (projection_blend)
    params["box_blend"] = float(getattr(n, "projection_blend", 0.0))

    # режим повторения/обрезки
    ext_map = {"REPEAT": 0, "EXTEND": 1, "CLIP": 2, "MIRROR": 3}
    params["extension"] = ext_map.get(getattr(n, "extension", "REPEAT"), 0)

    # цветовое пространство
    cs_map = {"SRGB": 0, "NON-COLOR": 1, "NONE": 1}
    cs_attr = None
    if hasattr(n, "image") and getattr(n, "image") is not None:
        img = n.image
        cs_attr = getattr(img, "colorspace_settings", None)
    if cs_attr is None:
        cs_attr = getattr(n, "colorspace_settings", None)
    cs_key = cs_attr.name.upper() if cs_attr else "SRGB"
    params["color_space"] = cs_map.get(cs_key, 0)

    # режим альфа
    alpha_map = {"STRAIGHT": 0, "PREMULTIPLIED": 1, "CHANNEL_PACKED": 2, "NONE": 3}
    params["alpha_mode"] = alpha_map.get(getattr(n, "alpha_mode", "STRAIGHT"), 0)

    # копирование текстуры в проект Godot
    img = getattr(n, "image", None)
    if img and getattr(img, "filepath", None):
        src_path = ""
        try:
            if bpy is None:
                return
            src_path = bpy.path.abspath(img.filepath)
            export_base_dir = get_export_base_dir()
            if export_base_dir and os.path.exists(src_path):
                mat_name_safe = sanitize(mat.name)
                tex_dir = os.path.join(export_base_dir, TEXTURE_DIR_NAME, mat_name_safe)
                os.makedirs(tex_dir, exist_ok=True)

                dest_path = os.path.join(tex_dir, os.path.basename(src_path))

                need_copy = True
                if os.path.exists(dest_path):
                    need_copy = os.path.getsize(dest_path) != os.path.getsize(src_path)
                if need_copy:
                    shutil.copy2(src_path, dest_path)
                    logger.info(f"Скопирована текстура: {dest_path}")

                rel_path = os.path.relpath(dest_path, export_base_dir).replace("\\", "/")
                params["image_path"] = f"res://{rel_path}"
            else:
                params["image_path"] = src_path.replace("\\", "/")
        except Exception as e:
            logger.error(f"Не удалось скопировать текстуру '{getattr(img, 'name', '?') }': {e}")
            if src_path:
                params["image_path"] = src_path.replace("\\", "/")
