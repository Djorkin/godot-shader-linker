# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later



from __future__ import annotations

from typing import Iterable


def _is_visible_socket(s) -> bool:
    try:
        linked = bool(getattr(s, "is_linked", False))
        if getattr(s, "enabled", True) is False and not linked:
            return False
        if getattr(s, "is_hidden", False) is True and not linked:
            return False
        if getattr(s, "hide", False) is True and not linked:
            return False
    except Exception:
        pass
    return True


def _visible_names(sockets: Iterable) -> list[str]:
    names: list[str] = []
    for s in sockets:
        if _is_visible_socket(s):
            names.append(str(getattr(s, "name", "")))
    return names


def handle(n, node_info: dict, params: dict, mat) -> None:
    # data_type: поддержка int/str, позже перепроверим по видимым сокетам
    def _dt_index(attr) -> int:
        try:
            if isinstance(attr, int):
                return 1 if attr != 0 else 0
            s = str(attr).upper()
            if "VECTOR" in s:
                return 1
            return 0
        except Exception:
            return 0
    params["data_type"] = _dt_index(getattr(n, "data_type", "FLOAT"))

    # mode (интерполяция)
    mode_map = {"LINEAR": 0, "STEPPED": 1, "SMOOTHSTEP": 2, "SMOOTHERSTEP": 3}
    try:
        # В разных версиях Blender свойство может называться по-разному
        mode_raw = getattr(n, "interpolation_type", None)
        if mode_raw is None:
            mode_raw = getattr(n, "interpolation", "LINEAR")
        mode_raw = str(mode_raw).upper()
        params["mode"] = mode_map.get(mode_raw, 0)
    except Exception:
        params["mode"] = 0

    # clamp
    try:
        params["clamp"] = bool(getattr(n, "clamp", False))
    except Exception:
        params["clamp"] = False

    # Видимые входы/выходы
    vis_inputs = _visible_names(getattr(n, "inputs", []))
    vis_outputs = _visible_names(getattr(n, "outputs", []))

    # Уточняем data_type по первому видимому входу (Vector → VECTOR, иначе FLOAT)
    # Это страхует от расхождений в n.data_type между версиями Blender
    if vis_inputs:
        inferred_dt = 1 if vis_inputs[0].strip().upper() == "VECTOR" else 0
        try:
            params["data_type"] = int(inferred_dt)
        except Exception:
            params["data_type"] = inferred_dt

    # В JSON унифицируем название выхода как "Result" вне зависимости от Blender
    node_info["outputs"] = ["Result"]

    # Перезаписываем inputs только видимыми именами
    node_info["inputs"] = vis_inputs

    # Фильтруем params: оставляем только соответствующие видимым входам ключи
    allowed_keys = {name.lower().replace(" ", "_") for name in vis_inputs}
    # Steps может называться по-разному, но в Map Range это именно "Steps"
    if any(name.upper() == "STEPS" for name in vis_inputs):
        allowed_keys.add("steps")

    for k in list(params.keys()):
        if k not in allowed_keys and k not in ("data_type", "mode", "clamp"):
            params.pop(k, None)

    # Если Steps видим и не связан — заберём фактическое значение прямо из сокета текущего режима
    try:
        if any(name.upper() == "STEPS" for name in vis_inputs):
            _steps_sock = next((s for s in getattr(n, "inputs", [])
                                if str(getattr(s, "name", "")) == "Steps" and _is_visible_socket(s)), None)
            if _steps_sock is not None and not bool(getattr(_steps_sock, "is_linked", False)) and hasattr(_steps_sock, "default_value"):
                params["steps"] = getattr(_steps_sock, "default_value")
    except Exception:
        pass

    # Приведение типов значений в зависимости от data_type
    dt = int(params.get("data_type", 0))
    def _to_float(v):
        try:
            if hasattr(v, "__iter__") and hasattr(v, "__len__"):
                seq = list(v)
                if len(seq) > 0:
                    return float(seq[0])
            return float(v)
        except Exception:
            return v

    def _to_vec3(v):
        try:
            if hasattr(v, "__iter__") and hasattr(v, "__len__"):
                lst = [float(x) for x in v]
                if len(lst) >= 3:
                    return lst[:3]
                if len(lst) == 2:
                    return [lst[0], lst[1], lst[1]]
                if len(lst) == 1:
                    return [lst[0], lst[0], lst[0]]
            f = float(v)
            return [f, f, f]
        except Exception:
            return v

    range_keys = ("from_min", "from_max", "to_min", "to_max")
    if dt == 0:  # FLOAT
        for k in range_keys:
            if k in params:
                params[k] = _to_float(params[k])
        if "value" in params:
            params["value"] = _to_float(params["value"])
        if "steps" in params:
            params["steps"] = _to_float(params["steps"])
    else:  # VECTOR
        for k in range_keys:
            if k in params:
                params[k] = _to_vec3(params[k])
        if "vector" in params:
            params["vector"] = _to_vec3(params["vector"])
        if "steps" in params:
            params["steps"] = _to_vec3(params["steps"])  # Steps должен быть vec3 в Vector-режиме

    # Если вход Steps не связан, не переопределяем значение: оставляем текущее из UI Blender
    try:
        steps_socket = next((s for s in getattr(n, "inputs", []) if str(getattr(s, "name", "")) == "Steps"), None)
        steps_linked = bool(getattr(steps_socket, "is_linked", False)) if steps_socket else False
    except Exception:
        steps_linked = False

    if not steps_linked:
        pass
