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
from .utils import sanitize as _sanitize, make_node_id as _make_node_id, bl_to_gsl_class
from .registry import get_node_handler
from .link_adapters import get_link_adapter


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
            "inputs": [s.name for s in n.inputs],
            "outputs": [s.name for s in n.outputs],
        }

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

        adapter = get_link_adapter(l.to_node.bl_idname)
        if adapter:
            new_idx = adapter(l.to_node, l.to_socket, in_idx)
            if new_idx is None:
                # skip link to inactive socket (e.g., third input when op is not 3-input)
                continue
            in_idx = new_idx

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