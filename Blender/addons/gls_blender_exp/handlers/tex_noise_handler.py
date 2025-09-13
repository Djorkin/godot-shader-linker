# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Обработчик ShaderNodeTexNoise для экспортера GSL.

Экспортируемые функции:
- handle(n, node_info: dict, params: dict, mat) -> None
"""

def handle(n, node_info: dict, params: dict, mat) -> None:
    dims_map = {"1D": 0, "2D": 1, "3D": 2, "4D": 3}
    try:
        dim_val = getattr(n, "noise_dimensions", getattr(n, "noise_dimensionality", "3D"))
        params["dimensions"] = dims_map.get(str(dim_val).upper(), 2)
    except Exception:
        pass

    if hasattr(n, "normalize"):
        params["normalize"] = bool(getattr(n, "normalize"))

    ft_attr = None
    if hasattr(n, "fractal_type"):
        ft_attr = getattr(n, "fractal_type")
    elif hasattr(n, "musgrave_type"):
        ft_attr = getattr(n, "musgrave_type")
    elif hasattr(n, "noise_type"):
        ft_attr = getattr(n, "noise_type")

    if ft_attr is not None:
        if isinstance(ft_attr, int):
            params["fractal_type"] = int(ft_attr)
        else:
            ft_map = {
                "MULTIFRACTAL": 0,
                "RIDGED_MULTIFRACTAL": 1,
                "HYBRID_MULTIFRACTAL": 2,
                "FBM": 3,
                "HETERO_TERRAIN": 4,
            }
            ft_val = str(ft_attr).upper().replace(" ", "_")
            params["fractal_type"] = ft_map.get(ft_val, 3)

    for attr_name in ["lacunarity", "gain", "offset"]:
        if hasattr(n, attr_name):
            try:
                params[attr_name] = float(getattr(n, attr_name))
            except Exception:
                pass
