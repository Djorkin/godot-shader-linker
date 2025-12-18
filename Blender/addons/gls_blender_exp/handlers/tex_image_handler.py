# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

from ..config import HOST  # HOST используется только чтобы сохранить зависимость модуля от config, если понадобится расширение протокола

try:
    import bpy  # type: ignore
except Exception:
    bpy = None  # type: ignore

import os


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

    # информация о пути к текстуре (Blender → Godot)
    img = getattr(n, "image", None)
    if img and getattr(img, "filepath", None):
        src_path = ""
        try:
            if bpy is None:
                return
            src_path = bpy.path.abspath(img.filepath)
            if src_path:
                params["image_path"] = src_path.replace("\\", "/")
        except Exception:
            if src_path:
                params["image_path"] = src_path.replace("\\", "/")
