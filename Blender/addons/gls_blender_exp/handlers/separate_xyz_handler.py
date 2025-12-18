# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later



def handle(n, node_info: dict, params: dict, mat) -> None:
    # Вход один: Vector. Экспортер уже положит незапитанное значение в params["vector"].
    try:
        node_info["inputs"] = ["Vector"]
    except Exception:
        pass
