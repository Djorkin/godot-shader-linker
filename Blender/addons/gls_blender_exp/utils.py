# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later
import re


def sanitize(text: str) -> str:
    text = text.replace(" ", "_").replace(".", "_")
    return re.sub(r"[^0-9A-Za-z_]+", "_", text)


def make_node_id(name: str, idx: int) -> str:
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
