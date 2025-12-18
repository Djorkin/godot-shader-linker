# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later



bl_info = {
    "name": "GSL Exporter",
    "author": "D.Jorkin",
    "version": (0, 3, 0),
    "blender": (4, 0, 0),
    "location": "Preferences > Add-ons",
    "description": "",
    "category": "Import-Export",
}

import bpy
from bpy.types import AddonPreferences
import json, os
import bpy.app.handlers as _h
import atexit


class GSLAddonPreferences(AddonPreferences):
    bl_idname = __name__

    def draw(self, context):
        pass

classes = (
    GSLAddonPreferences,
)

def _on_blender_quit(dummy):
    try:
        from . import net_server
        net_server.stop_server()
    except Exception:
        pass

def register():
    for cls in classes:
        bpy.utils.register_class(cls)
    try:
        from . import net_server  
        net_server.launch_server()
    except Exception as e:
        print(f"[GSL Exporter] Failed to start HTTP server: {e}")

    # Регистрируем обработчик выхода Blender (разные версии API)
    if hasattr(_h, "quit_pre"):
        if _on_blender_quit not in _h.quit_pre:
            _h.quit_pre.append(_on_blender_quit)
    else:
        # Fallback: atexit, сработает при закрытии процесса
        atexit.register(_on_blender_quit, None)

def unregister():
    try:
        from . import net_server
        net_server.stop_server()
    except Exception:
        pass

    if hasattr(_h, "quit_pre") and _on_blender_quit in _h.quit_pre:
        _h.quit_pre.remove(_on_blender_quit)

    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)
