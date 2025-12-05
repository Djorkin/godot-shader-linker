# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later



from typing import Any


def _mode_index(n: Any) -> int:
    for attr in ("mode", "color_space", "space"):
        if hasattr(n, attr):
            try:
                val = str(getattr(n, attr)).upper()
                if "RGB" in val:
                    return 0
                if "HSV" in val:
                    return 1
                if "HSL" in val:
                    return 2
            except Exception:
                pass
    return 0


def handle(n, node_info: dict, params: dict, mat) -> None:
    params["mode"] = _mode_index(n)
    try:
        node_info["inputs"] = ["Color"]
    except Exception:
        pass
