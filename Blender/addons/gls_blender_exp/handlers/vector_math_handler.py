# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Обработчик ShaderNodeVectorMath для экспортера GSL.

Экспортируемые функции:
- handle(n, node_info: dict, params: dict, mat) -> None
"""

def handle(n, node_info: dict, params: dict, mat) -> None:
    # Map Blender's ShaderNodeVectorMath.operation to Godot VectorMathModule enum index
    op_map = {
        "ADD": 0,
        "SUBTRACT": 1,
        "MULTIPLY": 2,
        "DIVIDE": 3,
        "MULTIPLY_ADD": 4,
        "CROSS_PRODUCT": 5,
        "PROJECT": 6,
        "REFLECT": 7,
        "REFRACT": 8,
        "FACEFORWARD": 9,
        "DOT_PRODUCT": 10,
        "DISTANCE": 11,
        "LENGTH": 12,
        "SCALE": 13,
        "NORMALIZE": 14,
        "ABSOLUTE": 15,
        "POWER": 16,
        "SIGN": 17,
        "MINIMUM": 18,
        "MAXIMUM": 19,
        "FLOOR": 20,
        "CEIL": 21,
        "FRACTION": 22,
        "MODULO": 23,
        "WRAP": 24,
        "SNAP": 25,
        "SINE": 26,
        "COSINE": 27,
        "TANGENT": 28,
    }
    try:
        raw = getattr(n, "operation", "ADD")
        key = str(raw).upper().replace(" ", "_")
        params["operation"] = int(op_map.get(key, 0))
    except Exception:
        params["operation"] = 0

    # Normalize default values for unlinked inputs to keys a/b/c
    def _to_num_or_list(v):
        try:
            if hasattr(v, "__iter__") and hasattr(v, "__len__"):
                lst = [float(x) for x in v]
                if len(lst) == 4:
                    lst = lst[:3]
                return lst
        except Exception:
            pass
        try:
            return float(v)
        except Exception:
            return v

    # Semantic names that Blender uses → normalized slot in Godot
    name_to_slot = {
        "VECTOR": "a",
        "VECTOR_001": "b",
        "VECTOR_002": "c",
        "SCALE": "b",
        "IOR": "c",
        "MIN": "b",
        "MAX": "c",
        "STEP": "b",
    }

    try:
        inputs = list(getattr(n, "inputs", []))
    except Exception:
        inputs = []

    taken = set()
    for s in inputs:
        if getattr(s, "is_linked", False):
            continue
        if not hasattr(s, "default_value"):
            continue
        dv = s.default_value
        if dv is None:
            continue
        name = str(getattr(s, "name", "")).upper().replace(" ", "_")
        slot = name_to_slot.get(name)
        if slot is None:
            # fallback by order A/B/C
            for c in ("a", "b", "c"):
                if c not in params and c not in taken:
                    slot = c
                    break
        if slot is None:
            continue
        params[slot] = _to_num_or_list(dv)
        taken.add(slot)

    # Post-process types to match Godot module socket expectations
    try:
        op = int(params.get("operation", 0))
    except Exception:
        op = 0

    def _vec3_broadcast(x):
        if isinstance(x, (int, float)):
            f = float(x)
            return [f, f, f]
        try:
            if hasattr(x, "__iter__") and hasattr(x, "__len__"):
                lst = [float(v) for v in x]
                if len(lst) == 4:
                    lst = lst[:3]
                if len(lst) == 3:
                    return lst
        except Exception:
            pass
        return x

    def _to_float_strict(x):
        try:
            return float(x)
        except Exception:
            return x

    # Operations where B must be vec3 (exclude Scale where B is float)
    b_vec3_ops = {0, 1, 2, 3, 5, 6, 7, 10, 11, 16, 18, 19, 23, 24, 25, 8, 9}
    if "b" in params and op in b_vec3_ops and op != 13:
        params["b"] = _vec3_broadcast(params["b"])

    # Ternary C expectations
    if op == 8:  # Refract: C is float (IOR)
        if "c" in params:
            params["c"] = _to_float_strict(params["c"])
    elif op in (9, 4, 24):  # Faceforward, Multiply Add, Wrap: C is vec3
        if "c" in params:
            params["c"] = _vec3_broadcast(params["c"])

    # Scale: B is float
    if op == 13 and "b" in params:
        params["b"] = _to_float_strict(params["b"])

    # Ensure Refract IOR (C) is present; backfill from available fields
    if op == 8 and "c" not in params:
        if "ior" in params:
            params["c"] = _to_float_strict(params["ior"])
        elif "scale" in params:
            params["c"] = _to_float_strict(params["scale"])

    # Optional hint for UI/debugging
    try:
        op = int(params.get("operation", 0))
        if op in (0,1,2,3,5,6,7,10,11,18,19,23,16,25,26,27,28):
            node_info["inputs"] = ["A","B"]
        elif op in (4,24,8,9):
            node_info["inputs"] = ["A","B","C"]
        elif op == 13:  # Scale
            node_info["inputs"] = ["A","B"]
        else:
            node_info["inputs"] = ["A"]
    except Exception:
        pass
