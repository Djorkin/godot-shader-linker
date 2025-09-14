# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Экспорт материалов: преобразование графа узлов Blender в структуру для JSON.

Назначение:
- Сбор описания активного материала в главном потоке.
- Унификация параметров узлов и делегирование специфики в handlers.

Экспортируемые функции:
- collect_material_data() -> dict
- gather_material() -> dict
"""


import threading

try:
    import bpy  # type: ignore
except Exception:  # pragma: no cover
    bpy = None  # type: ignore

from .utils import make_node_id as _make_node_id, bl_to_gsl_class
from .logger import get_logger
from .registry import get_node_handler
from .link_adapters import get_link_adapter

logger = get_logger().getChild("exporter")


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


def collect_material_data() -> dict:
    """Возвращает описание текущего материала, выполняясь гарантированно в главном потоке Blender.
    Если вызвано не из главного потока, выполнение делегируется через bpy.app.timers.
    """
    if bpy is None:
        return {"error": "bpy unavailable"}

    if threading.current_thread() is threading.main_thread():
        return gather_material()

    result_holder: dict = {}
    done_evt = threading.Event()

    def _task():
        try:
            result_holder["data"] = gather_material()
        except Exception as e:  # pragma: no cover
            result_holder["data"] = {"error": str(e)}
        finally:
            done_evt.set()
        return None

    bpy.app.timers.register(_task)

    if not done_evt.wait(timeout=2.0):
        logger.warning("Timeout waiting for main thread in collect_material_data")
        return {"error": "timeout"}
    return result_holder.get("data", {"error": "unknown"})



def gather_material() -> dict:
    """Сбор данных о материале. Обязательно вызывать из главного потока!"""
    obj = bpy.context.object  # type: ignore[attr-defined]
    if obj is None:
        return {"error": "no active object"}

    mat = obj.active_material
    if mat is None:
        return {"error": "object has no active material"}

    if not mat.use_nodes:
        return {"error": "material.use_nodes is False"}

    tree = mat.node_tree

    nodes: list[dict] = []
    node_id_map: dict = {}

    # collect nodes
    for idx, n in enumerate(tree.nodes):
        node_id = _make_node_id(n.name or n.bl_idname, idx)
        node_id_map[n] = node_id

        node_info = {
            "id": node_id,
            "name": n.name,
            "class": bl_to_gsl_class(n.bl_idname),
            "inputs": [s.name for s in n.inputs if _is_visible_socket(s)],
            "outputs": [s.name for s in n.outputs if _is_visible_socket(s)],
        }

        params: dict = {}

        # unconnected inputs
        for s in n.inputs:
            if s.is_linked:
                continue
            if not _is_visible_socket(s):
                continue
            # socket must have default_value
            if not hasattr(s, "default_value"):
                continue
            dv = s.default_value
            if dv is None:
                continue

            param_name = s.name.lower().replace(" ", "_")

            try:
                import mathutils  # type: ignore
                vector_types = (mathutils.Vector, mathutils.Color, mathutils.Euler)
                EulerType = mathutils.Euler
            except Exception:
                vector_types = tuple()
                EulerType = None

            import math
            if (EulerType is not None) and isinstance(dv, EulerType):
                params[param_name] = [round(math.degrees(a), 3) for a in dv]
            elif isinstance(dv, vector_types):
                params[param_name] = list(dv)
            elif isinstance(dv, bool):
                params[param_name] = bool(dv)
            elif isinstance(dv, int):
                params[param_name] = int(dv)
            elif isinstance(dv, float):
                params[param_name] = float(dv)
            elif hasattr(dv, "__iter__") and hasattr(dv, "__len__"):
                try:
                    seq = [float(x) for x in dv]
                    params[param_name] = seq
                except Exception:
                    try:
                        ln = len(dv)
                    except Exception:
                        ln = 3
                    params[param_name] = [0.0] * ln
            else:
                params[param_name] = 0.0

        handler = get_node_handler(n.bl_idname)
        if handler:
            handler(n, node_info, params, mat)

        if params:
            node_info["params"] = params

        nodes.append(node_info)

    # collect links
    links: list[str] = []
    for l in tree.links:
        if l.from_node is None or l.to_node is None:
            continue

        from_id = node_id_map.get(l.from_node)
        to_id = node_id_map.get(l.to_node)
        if not from_id or not to_id:
            continue

        # Индексы сокетов по умолчанию – как в Blender.
        out_idx = l.from_node.outputs.find(l.from_socket.name)
        in_idx = l.to_node.inputs.find(l.to_socket.name)

        # Нормализация индекса выхода для узлов с единым логическим выходом в Godot
        # Map Range в Godot имеет один выход Result (index 0), даже если в Blender есть расхождения
        if getattr(l.from_node, "bl_idname", "") == "ShaderNodeMapRange":
            out_idx = 0

        adapter = get_link_adapter(l.to_node.bl_idname)
        if adapter:
            new_idx = adapter(l.to_node, l.to_socket, in_idx)
            if new_idx is None:
                # skip link to inactive socket (e.g., third input when op is not 3-input)
                continue
            in_idx = new_idx

        # формат: "from_id,out_idx,to_id,in_idx"
        links.append(f"{from_id},{out_idx},{to_id},{in_idx}")

    data = {
        "material": mat.name,
        "nodes": nodes,
        "links": links,
    }

    logger.info(f"Material exported: name='{mat.name}', nodes={len(nodes)}, links={len(links)}")

    return data
