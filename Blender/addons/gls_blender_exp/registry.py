from typing import Callable, Optional

from .handlers.mapping_handler import handle as _handle_mapping
from .handlers.tex_image_handler import handle as _handle_tex_image
from .handlers.mix_handler import handle as _handle_mix
from .handlers.math_handler import handle as _handle_math
from .handlers.tex_noise_handler import handle as _handle_tex_noise
from .handlers.normal_map_handler import handle as _handle_normal_map
from .handlers.bump_handler import handle as _handle_bump

_NodeHandler = Callable[[object, dict, dict, object], None]

_REGISTRY: dict[str, _NodeHandler] = {
    "ShaderNodeMapping": _handle_mapping,
    "ShaderNodeTexImage": _handle_tex_image,
    "ShaderNodeMix": _handle_mix,
    "ShaderNodeMath": _handle_math,
    "ShaderNodeTexNoise": _handle_tex_noise,
    "ShaderNodeNormalMap": _handle_normal_map,
    "ShaderNodeBump": _handle_bump,
}

def get_node_handler(bl_idname: str) -> Optional[_NodeHandler]:
    return _REGISTRY.get(bl_idname)
