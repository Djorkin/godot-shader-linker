# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

import json
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
import socket
# import bpy only inside Blender, to allow testing outside of Blender
try:
    import bpy
except ImportError:
    bpy = None

import os
import shutil


# folder for textures:
#   EXPORT_BASE_DIR = r"C:/Games/Godot/MyProject"
# if empty, copying will be skipped, path will be passed as is (may not work when moving the project).

# static variable (fallback). If empty, path is taken from
# addon settings (Add-on Preferences > "godot_project_path").
EXPORT_BASE_DIR: str = r""


def _get_export_base_dir() -> str:
    """returns path to godot project. priority:
    1) value in EXPORT_BASE_DIR (if not empty)
    2) addon settings (godot_project_path)
    3) empty string (copying is disabled)
    """
    if EXPORT_BASE_DIR:
        return EXPORT_BASE_DIR

    try:
        import bpy
        # find addon by bl_idname – same as AddonPreferences
        for ad_name, ad in bpy.context.preferences.addons.items():
            prefs = getattr(ad, "preferences", None)
            if prefs and hasattr(prefs, "godot_project_path"):
                return prefs.godot_project_path
    except Exception:
        pass

    return ""

# folder for textures: Assets/Tex_<material_name>/file.png

# folder for textures in godot project: <Project>/GSL_Texture/2.jpg
TEXTURE_DIR_NAME = "GSL_Texture"

# module for data exchange between Blender and Godot: HTTP-server
HOST = "127.0.0.1"
PORT = 5050  # port must match the request from Godot

# port for UDP notifications to Godot
GODOT_UDP_PORT = 6020


_server: HTTPServer | None = None

class GSLRequestHandler(BaseHTTPRequestHandler):
    """test JSON"""

    def do_GET(self):
        if self.path == "/link":
            self._handle_link()
        else:
            self.send_error(404)

    # suppress console output
    def log_message(self, format, *args):
        return


    def _handle_link(self):
        """make JSON description of active material (nodes + links)"""
        data = _collect_material_data()
        payload = json.dumps(data, ensure_ascii=False).encode()

        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

# thread for server
_server_thread = None

def launch_server():
    """start server in separate daemon thread if it's not running"""
    global _server_thread
    if _server_thread and _server_thread.is_alive():
        return
    _server_thread = threading.Thread(target=_start_server, daemon=True)
    _server_thread.start()
    print(f"[GSL Exporter] HTTP-server started on http://{HOST}:{PORT}")
    _notify_godot("started")

def stop_server():
    """properly stop HTTP-server when addon is disabled or Blender is closed"""
    global _server, _server_thread
    if _server is None and (_server_thread is None or not _server_thread.is_alive()):
        return
    if _server:
        try:
            _server.shutdown()
            _server.server_close()
        except Exception as e:
            print(f"[GSL Exporter] Error stopping server: {e}")
        _server = None
    if _server_thread and _server_thread.is_alive():
        _server_thread.join(timeout=1.0)
    _server_thread = None
    _server_thread = None
    _notify_godot("stopped")


def _notify_godot(status: str):
    try:
        msg = json.dumps({"status": status}).encode()
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.sendto(msg, ("127.0.0.1", GODOT_UDP_PORT))
        sock.close()
    except Exception as e:
        print(f"[GSL Exporter] Failed to send notification to Godot: {e}")


def _collect_material_data():
    """Возвращает описание текущего материала, выполняясь гарантированно в главном потоке Blender."""

    if bpy is None:
        return {"error": "bpy unavailable"}

    import threading
    if threading.current_thread() is threading.main_thread():
        return _gather_material()

    result_holder: dict = {}
    done_evt = threading.Event()

    def _task():
        try:
            result_holder["data"] = _gather_material()
        except Exception as e:
            result_holder["data"] = {"error": str(e)}
        finally:
            done_evt.set()
        return None  


    bpy.app.timers.register(_task)

    done_evt.wait()
    return result_holder.get("data", {"error": "unknown"})



def _gather_material():
    """collects data about material. must be executed in main thread!"""

    obj = bpy.context.object  
    if obj is None:
        return {"error": "no active object"}

    mat = obj.active_material
    if mat is None:
        return {"error": "object has no active material"}

    if not mat.use_nodes:
        return {"error": "material.use_nodes is False"}

    tree = mat.node_tree

    def _sanitize(text: str) -> str:
        import re
        text = text.replace(" ", "_").replace(".", "_")
        return re.sub(r"[^0-9A-Za-z_]+", "_", text)

    def _make_node_id(name: str, idx: int) -> str:
        return f"{_sanitize(name)}_{idx:03d}"

    def _bl_to_gsl_class(bl_id: str) -> str:
        """Конвертирует Blender bl_idname в имя модуля GSL (Mapping → MappingModule)."""
        if bl_id.startswith("ShaderNode"):
            core = bl_id[len("ShaderNode"):]
        else:
            core = bl_id
        return f"{core}Module"

    nodes: list[dict] = []
    node_id_map: dict = {}

    # collect nodes
    for idx, n in enumerate(tree.nodes):
        node_id = _make_node_id(n.name or n.bl_idname, idx)
        node_id_map[n] = node_id

        node_info = {
            "id": node_id,
            "name": n.name,
            "class": _bl_to_gsl_class(n.bl_idname),
            "inputs": [s.name for s in n.inputs],
            "outputs": [s.name for s in n.outputs],
        }


        # uniform overrides

        params: dict = {}

        # unconnected inputs
        for s in n.inputs:
            if s.is_linked:
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
            except Exception:
                vector_types = tuple()

            import math
            if isinstance(dv, mathutils.Euler):
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

        if n.bl_idname == "ShaderNodeMapping":
            mapping_enum = getattr(n, "vector_type", "POINT")
            mapping_enum_map = {"POINT": 0, "TEXTURE": 1, "VECTOR": 2, "NORMAL": 3}
            params["mapping_type"] = mapping_enum_map.get(mapping_enum.upper(), 0)

        elif n.bl_idname == "ShaderNodeTexImage":
            # interpolation
            interp_map = {"Linear": 0, "Closest": 1, "Cubic": 2}
            params["interpolation"] = interp_map.get(getattr(n, "interpolation", "Linear"), 0)

            # projection
            proj_map = {"FLAT": 0, "BOX": 1, "SPHERE": 2, "TUBE": 3}
            params["projection"] = proj_map.get(getattr(n, "projection", "FLAT"), 0)

            # box blend (projection_blend)
            params["box_blend"] = float(getattr(n, "projection_blend", 0.0))

            # extension
            ext_map = {"REPEAT": 0, "EXTEND": 1, "CLIP": 2, "MIRROR": 3}
            params["extension"] = ext_map.get(getattr(n, "extension", "REPEAT"), 0)

            # color space
            cs_map = {"SRGB": 0, "NON-COLOR": 1, "NONE": 1}
            cs_attr = None
            if hasattr(n, "image") and getattr(n, "image") is not None:
                img = n.image
                cs_attr = getattr(img, "colorspace_settings", None)
            if cs_attr is None:
                cs_attr = getattr(n, "colorspace_settings", None)
            cs_key = cs_attr.name.upper() if cs_attr else "SRGB"
            params["color_space"] = cs_map.get(cs_key, 0)

            # alpha mode
            alpha_map = {"STRAIGHT": 0, "PREMULTIPLIED": 1, "CHANNEL_PACKED": 2, "NONE": 3}
            params["alpha_mode"] = alpha_map.get(getattr(n, "alpha_mode", "STRAIGHT"), 0)

            # copy texture to godot project

            img = getattr(n, "image", None)
            if img and img.filepath:
                try:
                    src_path = bpy.path.abspath(img.filepath)
                    export_base_dir = _get_export_base_dir()
                    if export_base_dir and os.path.exists(src_path):
                        # make folder: <export_base_dir>/GSL_Texture/<MaterialName>/
                        mat_name_safe = _sanitize(mat.name)
                        tex_dir = os.path.join(export_base_dir, TEXTURE_DIR_NAME, mat_name_safe)
                        os.makedirs(tex_dir, exist_ok=True)

                        dest_path = os.path.join(tex_dir, os.path.basename(src_path))

                        # copy if file is different (by size or missing)
                        need_copy = True
                        if os.path.exists(dest_path):
                            need_copy = os.path.getsize(dest_path) != os.path.getsize(src_path)
                        if need_copy:
                            shutil.copy2(src_path, dest_path)
                            print(f"[GSL Exporter] Copied texture → {dest_path}")

                        # make relative path for godot (res://...)
                        rel_path = os.path.relpath(dest_path, export_base_dir).replace("\\", "/")
                        params["image_path"] = f"res://{rel_path}"
                    else:
                        # if EXPORT_BASE_DIR is not specified – pass absolute path
                        params["image_path"] = src_path.replace("\\", "/")
                except Exception as e:
                    print(f"[GSL Exporter] Failed to copy texture '{img.name}': {e}")
                    params["image_path"] = src_path.replace("\\", "/")

        elif n.bl_idname == "ShaderNodeMix":
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

            # Vector factor mode (only meaningful for VECTOR data_type)
            # blender: "factor_mode" can be "UNIFORM" or "VECTOR"
            factor_mode = str(getattr(n, "factor_mode", "UNIFORM"))
            params["vector_factor_mode"] = 0 if factor_mode.upper() == "UNIFORM" else 1

            # значение фактора берём только если режим UNIFORM,
            # иначе будем захватывать NonUniformFactor ниже по именам сокетов.
            try:
                factor_mode_local = str(getattr(n, "factor_mode", "UNIFORM")).upper()
                if factor_mode_local == "UNIFORM":
                    fac_socket = n.inputs[0]
                    if not fac_socket.is_linked and hasattr(fac_socket, "default_value"):
                        fac_val = fac_socket.default_value
                        # convert to scalar or list
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

            # remove generic-collected values to ensure we use correct active sockets
            params.pop("a", None)
            params.pop("b", None)

            # collect unlinked sockets by name (more robust than relying on indices)
            for sock in n.inputs:
                # skip sockets that are not relevant (hidden for current data_type)
                if getattr(sock, "enabled", True) is False:
                    continue
                if getattr(sock, "is_hidden", False) is True or getattr(sock, "hide", False) is True:
                    continue
                if sock.is_linked or not hasattr(sock, "default_value"):
                    continue
                sock_name_up = str(sock.name).upper()
                # We only need first visible occurrence of each logical socket
                target_key: str = ""
                if sock_name_up.startswith("A"):
                    target_key = "a"
                elif sock_name_up.startswith("B"):
                    target_key = "b"
                elif sock_name_up.startswith("NONUNIFORMFACTOR"):
                    target_key = "factor"
                elif sock_name_up.startswith("FACTOR") and "factor" not in params:
                    # only if we did not capture factor above
                    target_key = "factor"
                else:
                    continue



                # Skip if we already captured this logical key (keep the first visible socket)
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

                # Remove alpha from color if present (RGBA → RGB)
                if isinstance(val, list) and len(val) == 4:
                    val = val[:3]

                params[target_key] = val

            # If vector factor mode is non-uniform – rename param key
            data_type = params.get("data_type", 2)
            vec_mode = params.get("vector_factor_mode", 0)
            if data_type == 1:
                # decide based on actual value shape; if list/vector → nonuniform
                if "factor" in params:
                    _v = params.get("factor")
                    if (isinstance(_v, (list, tuple)) and len(_v) >= 3):
                        # treat as NonUniform vector factor
                        params["nonuniformfactor"] = params.pop("factor")
                        vec_mode = 1
                    else:
                        vec_mode = 0
                params["vector_factor_mode"] = vec_mode

            # if we captured nonuniformfactor explicitly, ensure mode flag is 1
            if "nonuniformfactor" in params:
                params["vector_factor_mode"] = 1

            # ensure params saved after possible modifications
            node_info["params"] = params

            # Override inputs list to match GSL MixModule signature
            if data_type == 2:
                node_info["inputs"] = ["Factor", "A_Color", "B_Color"]
            elif data_type == 1:
                if vec_mode == 0:
                    node_info["inputs"] = ["Factor", "A_Vector", "B_Vector"]
                else:
                    node_info["inputs"] = ["NonUniformFactor", "A_Vector", "B_Vector"]
            else:
                node_info["inputs"] = ["Factor", "A_Float", "B_Float"]

        elif n.bl_idname == "ShaderNodeTexNoise":
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

        if params:
            node_info["params"] = params

        if n.bl_idname == "ShaderNodeMapping":
            node_info["mode"] = getattr(n, "vector_type", "")

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

        # Для ShaderNodeMix порядок входных сокетов в Blender отличается от
        # порядка «логических» входов, который мы экспортируем (Factor, A, B).
        # Сокет «Clamp Factor» (bool) присутствует в списке .inputs, но не
        # отображается как порт в Godot, поэтому нужно сместить индекс.
        if l.to_node.bl_idname == "ShaderNodeMix":
            try:
                # Сформировать список *видимых* входов (enabled=True).
                visible_inputs = [s for s in l.to_node.inputs if getattr(s, "enabled", True)]
                # Пересчитать индекс как позицию целевого сокета среди видимых.
                in_idx = visible_inputs.index(l.to_socket)
            except ValueError:
                in_idx = max(0, in_idx - 1)  # запасной вариант: убираем скрытый Clamp

        # формат: "from_id,out_idx -> to_id,in_idx"
        links.append(f"{from_id},{out_idx},{to_id},{in_idx}")

    data = {
        "material": mat.name,
        "nodes": nodes,
        "links": links,
    }

    # debug output
    print(f"[GSL Exporter] material '{mat.name}': nodes={len(nodes)}, links={len(links)}")

    return data

def _start_server():
    global _server
    try:
        _server = HTTPServer((HOST, PORT), GSLRequestHandler)
        _server.serve_forever()
    except Exception as e:
        print(f"[GSL Exporter] HTTP-server stopped: {e}")