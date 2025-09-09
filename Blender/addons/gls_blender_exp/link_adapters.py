from typing import Callable, Optional, Union

_LinkAdapter = Callable[[object, object, int], Optional[int]]


def _mix_link_index(to_node, to_socket, fallback_idx: int) -> Optional[int]:
    try:
        visible_inputs = [s for s in to_node.inputs if getattr(s, "enabled", True)]
        return visible_inputs.index(to_socket)
    except ValueError:
        return max(0, fallback_idx - 1)


def _math_link_index(to_node, to_socket, fallback_idx: int) -> Optional[int]:
    try:
        op_val = str(getattr(to_node, "operation", "ADD")).upper().replace(" ", "_")
    except Exception:
        op_val = "ADD"
    three_input_ops = {"MULTIPLY_ADD", "COMPARE", "WRAP", "SMOOTH_MIN", "SMOOTH_MAX"}
    unary_ops = {
        "ABSOLUTE","LOGARITHM","SQRT","INVERSE_SQRT","EXPONENT",
        "SINE","COSINE","TANGENT","FLOOR","CEIL","FRACT","FRACTION",
        "ROUND","TRUNC","TRUNCATE","SIGN",
        "ARCSINE","ARCCOSINE","ARCTANGENT",
        "HYPERBOLIC_SINE","HYPERBOLIC_COSINE","HYPERBOLIC_TANGENT",
        "TO_RADIANS","TO_DEGREES"
    }
    need_inputs = 3 if op_val in three_input_ops else (1 if op_val in unary_ops else 2)

    all_inputs = list(to_node.inputs)
    try:
        target_pos = all_inputs.index(to_socket)
    except ValueError:
        target_pos = 0

    if target_pos >= need_inputs:
        return None
    return target_pos


_REGISTRY: dict[str, _LinkAdapter] = {
    "ShaderNodeMix": _mix_link_index,
    "ShaderNodeMath": _math_link_index,
}


def get_link_adapter(bl_idname: str) -> Optional[_LinkAdapter]:
    return _REGISTRY.get(bl_idname)
