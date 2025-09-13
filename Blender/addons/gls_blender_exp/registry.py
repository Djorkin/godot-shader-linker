# SPDX-Copyright (C) 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Реестр обработчиков узлов Blender для экспортера GSL.

Назначение:
- Хранить соответствие bl_idname → функция-обработчик.

Экспортируемые сущности:
- get_node_handler(bl_idname: str) -> Optional[Callable]
"""

from typing import Callable, Optional

from .handlers.mapping_handler import handle as _handle_mapping
from .handlers.tex_image_handler import handle as _handle_tex_image
from .handlers.mix_handler import handle as _handle_mix
from .handlers.math_handler import handle as _handle_math
from .handlers.tex_noise_handler import handle as _handle_tex_noise
from .handlers.tex_white_noise_handler import handle as _handle_tex_white_noise
from .handlers.normal_map_handler import handle as _handle_normal_map
from .handlers.bump_handler import handle as _handle_bump
from .handlers.vector_math_handler import handle as _handle_vector_math
from .handlers.map_range_handler import handle as _handle_map_range
from .handlers.combine_color_handler import handle as _handle_combine_color
from .handlers.separate_color_handler import handle as _handle_separate_color
from .handlers.combine_xyz_handler import handle as _handle_combine_xyz
from .handlers.separate_xyz_handler import handle as _handle_separate_xyz

_NodeHandler = Callable[[object, dict, dict, object], None]

_REGISTRY: dict[str, _NodeHandler] = {
    "ShaderNodeMapping": _handle_mapping,
    "ShaderNodeTexImage": _handle_tex_image,
    "ShaderNodeMix": _handle_mix,
    "ShaderNodeMath": _handle_math,
    "ShaderNodeTexNoise": _handle_tex_noise,
    "ShaderNodeNormalMap": _handle_normal_map,
    "ShaderNodeBump": _handle_bump,
    "ShaderNodeVectorMath": _handle_vector_math,
    "ShaderNodeMapRange": _handle_map_range,
    "ShaderNodeTexWhiteNoise": _handle_tex_white_noise,
    "ShaderNodeCombineColor": _handle_combine_color,
    "ShaderNodeSeparateColor": _handle_separate_color,
    "ShaderNodeCombineXYZ": _handle_combine_xyz,
    "ShaderNodeSeparateXYZ": _handle_separate_xyz,
}

def get_node_handler(bl_idname: str) -> Optional[_NodeHandler]:
    return _REGISTRY.get(bl_idname)
