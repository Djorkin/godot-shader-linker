# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later



def handle(n, node_info: dict, params: dict, mat) -> None:
    # 1) Определяем операцию (индекс enum модуля Godot)
    op_map = {
        "ADD": 0, "SUBTRACT": 1, "MULTIPLY": 2, "DIVIDE": 3, "MULTIPLY_ADD": 4,
        "CROSS_PRODUCT": 5, "PROJECT": 6, "REFLECT": 7, "REFRACT": 8, "FACEFORWARD": 9,
        "DOT_PRODUCT": 10, "DISTANCE": 11, "LENGTH": 12, "SCALE": 13, "NORMALIZE": 14,
        "ABSOLUTE": 15, "POWER": 16, "SIGN": 17, "MINIMUM": 18, "MAXIMUM": 19,
        "FLOOR": 20, "CEIL": 21, "FRACTION": 22, "MODULO": 23, "WRAP": 24, "SNAP": 25,
        "SINE": 26, "COSINE": 27, "TANGENT": 28,
    }
    try:
        raw = getattr(n, "operation", "ADD")
        key = str(raw).upper().replace(" ", "_")
        params["operation"] = int(op_map.get(key, 0))
    except Exception:
        params["operation"] = 0

    # 2) Хелперы конверсии типов
    def _to_num_or_list(v):
        try:
            if hasattr(v, "__iter__") and hasattr(v, "__len__"):
                lst = [float(x) for x in v]
                if len(lst) >= 3:
                    return lst[:3]
                return lst
        except Exception:
            pass
        try:
            return float(v)
        except Exception:
            return v

    def _vec3_broadcast(x):
        if isinstance(x, (int, float)):
            f = float(x)
            return [f, f, f]
        try:
            if hasattr(x, "__iter__") and hasattr(x, "__len__"):
                lst = [float(v) for v in x]
                if len(lst) >= 3:
                    return lst[:3]
        except Exception:
            pass
        return x

    def _to_float_strict(x):
        try:
            if hasattr(x, "__iter__") and hasattr(x, "__len__"):
                it = list(x)
                if len(it) > 0:
                    return float(it[0])
        except Exception:
            pass
        try:
            return float(x)
        except Exception:
            return x

    # 3) Заполняем слоты строго по индексам входов (только для незапитанных)
    try:
        inputs = list(getattr(n, "inputs", []))
    except Exception:
        inputs = []
    index_to_slot = {0: "a", 1: "b", 2: "c"}
    for idx, s in enumerate(inputs):
        if idx not in index_to_slot:
            continue
        if getattr(s, "is_linked", False):
            continue
        if not hasattr(s, "default_value"):
            continue
        dv = s.default_value
        if dv is None:
            continue
        params[index_to_slot[idx]] = _to_num_or_list(dv)

    # 4) Нормализация типов по операции
    try:
        op = int(params.get("operation", 0))
    except Exception:
        op = 0

    # b как vec3 для большинства бинарных операций (кроме Scale)
    b_vec3_ops = {0,1,2,3,5,6,7,10,11,16,18,19,23,24,25,26,27,28}
    if op in b_vec3_ops and "b" in params and op != 13:
        params["b"] = _vec3_broadcast(params["b"])

    # Специальные случаи
    if op == 13:  # Scale: B = float из 'b' или из 'scale'
        if "scale" in params:
            params["b"] = _to_float_strict(params["scale"])
        if "b" in params:
            params["b"] = _to_float_strict(params["b"])
        params.pop("scale", None)
    if op == 8:  # Refract: C = float; приоритет 'scale'/'ior'
        if "scale" in params:
            params["c"] = _to_float_strict(params["scale"])
        if "ior" in params:
            params["c"] = _to_float_strict(params["ior"])
        if "c" in params:
            params["c"] = _to_float_strict(params["c"])
        params.pop("scale", None)
        params.pop("ior", None)
    if op in (9, 4, 24):  # Faceforward, Multiply Add, Wrap: C = vec3
        if "c" in params:
            params["c"] = _vec3_broadcast(params["c"])
    if op == 16 and "b" in params:  # Power: exponent vec3
        params["b"] = _vec3_broadcast(params["b"])

    # Удаляем generic-ключи, если вдруг остались
    for k in ("vector", "vector_001", "vector_002"):
        if k in params:
            params.pop(k, None)

    # 5) Подсказки по входам
    try:
        if op in (0,1,2,3,5,6,7,10,11,18,19,23,16,25,26,27,28,13):
            node_info["inputs"] = ["A","B"]
        elif op in (4,24,8,9):
            node_info["inputs"] = ["A","B","C"]
        else:
            node_info["inputs"] = ["A"]
    except Exception:
        pass
