# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Обработчик ShaderNodeMath для экспортера GSL.

Экспортируемые функции:
- handle(n, node_info: dict, params: dict, mat) -> None
"""

def handle(n, node_info: dict, params: dict, mat) -> None:
    op_map = {
        "ADD": 0,
        "SUBTRACT": 1,
        "MULTIPLY": 2,
        "DIVIDE": 3,
        "MULTIPLY_ADD": 4,
        "POWER": 5,
        "LOGARITHM": 6,
        "SQRT": 7,
        "INVERSE_SQRT": 8,
        "ABSOLUTE": 9,
        "EXPONENT": 10,
        "SINE": 11,
        "COSINE": 12,
        "TANGENT": 13,
        "FLOOR": 14,
        "CEIL": 15,
        "FRACT": 16,
        "FRACTION": 16,
        "MINIMUM": 17,
        "MAXIMUM": 18,
        "LESS_THAN": 19,
        "GREATER_THAN": 20,
        "SIGN": 21,
        "MODULO": 22,
        "TRUNCATED_MODULO": 23,
        "FLOORED_MODULO": 24,
        "WRAP": 25,
        "SNAP": 26,
        "PINGPONG": 27,
        "ARCTAN2": 28,
        "ATAN2": 28,
        "COMPARE": 29,
        "ROUND": 30,
        "TRUNC": 31,
        "TRUNCATE": 31,
        "SMOOTH_MIN": 32,
        "SMOOTH_MAX": 33,
        "ARCSINE": 34,
        "ASIN": 34,
        "ARCCOSINE": 35,
        "ACOS": 35,
        "ARCTANGENT": 36,
        "ATAN": 36,
        "HYPERBOLIC_SINE": 37,
        "SINH": 37,
        "HYPERBOLIC_COSINE": 38,
        "COSH": 38,
        "HYPERBOLIC_TANGENT": 39,
        "TANH": 39,
        "TO_RADIANS": 40,
        "RADIANS": 40,
        "TO_DEGREES": 41,
        "DEGREES": 41,
    }

    raw_op = getattr(n, "operation", "ADD")
    op_val = str(raw_op).upper().replace(" ", "_")
    op_idx = op_map.get(op_val, 0)
    params["operation"] = op_idx
    try:
        params["bl_operation"] = str(raw_op)
    except Exception:
        params["bl_operation"] = "ADD"

    try:
        params["use_clamp"] = bool(getattr(n, "use_clamp", False))
    except Exception:
        params["use_clamp"] = False

    params.pop("value", None)
    try:
        a_sock = n.inputs[0]
        if not a_sock.is_linked and hasattr(a_sock, "default_value"):
            params["a"] = float(a_sock.default_value)
    except Exception:
        pass
    try:
        b_sock = n.inputs[1]
        if not b_sock.is_linked and hasattr(b_sock, "default_value"):
            params["b"] = float(b_sock.default_value)
    except Exception:
        pass

    three_input_ops = {"MULTIPLY_ADD", "COMPARE", "WRAP", "SMOOTH_MIN", "SMOOTH_MAX"}
    needs_c = op_val in three_input_ops
    if needs_c and len(n.inputs) > 2:
        try:
            c_sock = n.inputs[2]
            if not c_sock.is_linked and hasattr(c_sock, "default_value"):
                params["c"] = float(c_sock.default_value)
        except Exception:
            pass

    unary_ops = {
        "ABSOLUTE","LOGARITHM","SQRT","INVERSE_SQRT","EXPONENT",
        "SINE","COSINE","TANGENT","FLOOR","CEIL","FRACT","FRACTION",
        "ROUND","TRUNC","TRUNCATE","SIGN",
        "ARCSINE","ARCCOSINE","ARCTANGENT",
        "HYPERBOLIC_SINE","HYPERBOLIC_COSINE","HYPERBOLIC_TANGENT",
        "TO_RADIANS","TO_DEGREES"
    }

    if needs_c:
        node_info["inputs"] = ["A", "B", "C"]
    elif op_val in unary_ops:
        node_info["inputs"] = ["A"]
    else:
        node_info["inputs"] = ["A", "B"]
