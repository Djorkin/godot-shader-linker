# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Обработчик ShaderNodeMix для экспортера GSL.

Экспортируемые функции:
- handle(n, node_info: dict, params: dict, mat) -> None
"""

def handle(n, node_info: dict, params: dict, mat) -> None:
    type_map = {"FLOAT": 0, "VECTOR": 1, "RGBA": 2, "COLOR": 2}
    params["data_type"] = type_map.get(str(getattr(n, "data_type", "RGBA")), 2)

    blend_map = {
        "MIX": 0,
        "DARKEN": 1,
        "MULTIPLY": 2,
        "BURN": 3,
        "LIGHTEN": 4,
        "SCREEN": 5,
        "DODGE": 6,
        "ADD": 7,
        "OVERLAY": 8,
        "SOFT_LIGHT": 9,
        "LINEAR_LIGHT": 10,
        "DIFFERENCE": 11,
        "EXCLUSION": 12,
        "SUBTRACT": 13,
        "DIVIDE": 14,
        "HUE": 15,
        "SATURATION": 16,
        "COLOR": 17,
        "VALUE": 18,
    }
    params["blend_type"] = blend_map.get(str(getattr(n, "blend_type", "MIX")), 0)

    params["clamp_factor"] = bool(getattr(n, "clamp_factor", False))
    params["clamp_result"] = bool(getattr(n, "clamp_result", False))

    factor_mode = str(getattr(n, "factor_mode", "UNIFORM"))
    params["vector_factor_mode"] = 0 if factor_mode.upper() == "UNIFORM" else 1

    try:
        factor_mode_local = str(getattr(n, "factor_mode", "UNIFORM")).upper()
        if factor_mode_local == "UNIFORM":
            fac_socket = n.inputs[0]
            if not fac_socket.is_linked and hasattr(fac_socket, "default_value"):
                fac_val = fac_socket.default_value
                if isinstance(fac_val, (bool, int, float)):
                    fac_val = float(fac_val)
                elif isinstance(fac_val, (list, tuple)) or (hasattr(fac_val, "__iter__") and hasattr(fac_val, "__len__")):
                    tmp_list = [float(x) for x in fac_val]
                    if len(tmp_list) == 1:
                        fac_val = float(tmp_list[0])
                    else:
                        fac_val = tmp_list
                params["factor"] = fac_val
    except Exception:
        pass

    params.pop("a", None)
    params.pop("b", None)

    for sock in n.inputs:
        if getattr(sock, "enabled", True) is False:
            continue
        if getattr(sock, "is_hidden", False) is True or getattr(sock, "hide", False) is True:
            continue
        if sock.is_linked or not hasattr(sock, "default_value"):
            continue
        sock_name_up = str(sock.name).upper()
        target_key: str = ""
        if sock_name_up.startswith("A"):
            target_key = "a"
        elif sock_name_up.startswith("B"):
            target_key = "b"
        elif sock_name_up.startswith("NONUNIFORMFACTOR"):
            target_key = "factor"
        elif sock_name_up.startswith("FACTOR") and "factor" not in params:
            target_key = "factor"
        else:
            continue

        if target_key and target_key != "factor" and target_key in params:
            continue

        dv = sock.default_value
        if dv is None:
            continue

        if isinstance(dv, (bool, int, float)):
            val = float(dv)
        elif hasattr(dv, "__iter__") and hasattr(dv, "__len__"):
            try:
                val = [float(x) for x in dv]
            except Exception:
                val = list(dv)
        else:
            continue

        if isinstance(val, list) and len(val) == 4:
            val = val[:3]

        params[target_key] = val

    data_type = params.get("data_type", 2)
    vec_mode = params.get("vector_factor_mode", 0)
    if data_type == 1:
        if "factor" in params:
            _v = params.get("factor")
            if (isinstance(_v, (list, tuple)) and len(_v) >= 3):
                params["nonuniformfactor"] = params.pop("factor")
                vec_mode = 1
            else:
                vec_mode = 0
        params["vector_factor_mode"] = vec_mode

    if "nonuniformfactor" in params:
        params["vector_factor_mode"] = 1

    if data_type == 2:
        node_info["inputs"] = ["Factor", "A_Color", "B_Color"]
    elif data_type == 1:
        if vec_mode == 0:
            node_info["inputs"] = ["Factor", "A_Vector", "B_Vector"]
        else:
            node_info["inputs"] = ["NonUniformFactor", "A_Vector", "B_Vector"]
    else:
        node_info["inputs"] = ["Factor", "A_Float", "B_Float"]
