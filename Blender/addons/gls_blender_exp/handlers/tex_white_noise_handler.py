# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

def handle(n, node_info: dict, params: dict, mat) -> None:

    dims_map = {"1D": 0, "2D": 1, "3D": 2, "4D": 3}

    # Попытка получить строковое представление измерения из нескольких возможных атрибутов
    dim_attr = None
    for attr in ("noise_dimensions", "noise_dimensionality", "dimensions"):
        if hasattr(n, attr):
            dim_attr = getattr(n, attr)
            break

    try:
        if isinstance(dim_attr, int):
            # Если Blender вернул индекс напрямую
            params["dimensions"] = int(dim_attr)
        else:
            dim_str = str(dim_attr).upper()
            params["dimensions"] = dims_map.get(dim_str, 2)
    except Exception:
        # По умолчанию 3D
        params["dimensions"] = 2
