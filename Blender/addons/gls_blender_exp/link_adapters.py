# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later


from typing import Callable, Optional


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


def _vector_math_link_index(to_node, to_socket, fallback_idx: int) -> Optional[int]:
    try:
        op_val = str(getattr(to_node, "operation", "ADD")).upper().replace(" ", "_")
    except Exception:
        op_val = "ADD"
    # Группировка операций по арности
    unary_ops = {
        "NORMALIZE","LENGTH","ABSOLUTE","SIGN","FLOOR","CEIL","FRACTION",
        "SINE","COSINE","TANGENT"
    }
    ternary_ops = {"MULTIPLY_ADD", "REFRACT", "FACEFORWARD", "WRAP"}
    need_inputs = 3 if op_val in ternary_ops else (1 if op_val in unary_ops else 2)

    all_inputs = list(getattr(to_node, "inputs", []))
    try:
        target_pos = all_inputs.index(to_socket)
    except ValueError:
        target_pos = 0
    return target_pos if target_pos < need_inputs else None


def _map_range_link_index(to_node, to_socket, fallback_idx: int) -> Optional[int]:
    def _visible_inputs(node) -> list[str]:
        names: list[str] = []
        try:
            for s in getattr(node, "inputs", []):
                if getattr(s, "enabled", True) is False:
                    continue
                if getattr(s, "is_hidden", False) is True:
                    continue
                if getattr(s, "hide", False) is True:
                    continue
                names.append(str(getattr(s, "name", "")))
        except Exception:
            names = []
        return names

    names = _visible_inputs(to_node)

    if not names:
        # Fallback: построить по data_type с учётом int/str и режима
        def _dt_index(attr) -> int:
            try:
                if isinstance(attr, int):
                    return 1 if attr != 0 else 0
                s = str(attr).upper()
                return 1 if "VECTOR" in s else 0
            except Exception:
                return 0
        dt = _dt_index(getattr(to_node, "data_type", 0))
        names = [
            "Vector", "From Min", "From Max", "To Min", "To Max"
        ] if dt == 1 else [
            "Value", "From Min", "From Max", "To Min", "To Max"
        ]
        try:
            mode_raw = getattr(to_node, "interpolation_type", None)
            if mode_raw is None:
                mode_raw = getattr(to_node, "interpolation", "LINEAR")
            if str(mode_raw).upper() == "STEPPED":
                names.append("Steps")
        except Exception:
            pass

    try:
        name = str(getattr(to_socket, "name", ""))
    except Exception:
        name = ""

    try:
        return names.index(name)
    except ValueError:
        return None


def _white_noise_link_index(to_node, to_socket, fallback_idx: int) -> Optional[int]:
    def _visible_inputs(node) -> list:
        try:
            return [s for s in getattr(node, "inputs", []) if getattr(s, "enabled", True) and not getattr(s, "is_hidden", False) and not getattr(s, "hide", False)]
        except Exception:
            return list(getattr(node, "inputs", []))
    vis = _visible_inputs(to_node)
    try:
        return vis.index(to_socket)
    except ValueError:
        return max(0, fallback_idx - 1)


_REGISTRY: dict[str, _LinkAdapter] = {
    "ShaderNodeMix": _mix_link_index,
    "ShaderNodeMath": _math_link_index,
    "ShaderNodeVectorMath": _vector_math_link_index,
    "ShaderNodeMapRange": _map_range_link_index,
    "ShaderNodeTexWhiteNoise": _white_noise_link_index,
}


def get_link_adapter(bl_idname: str) -> Optional[_LinkAdapter]:
    return _REGISTRY.get(bl_idname)
