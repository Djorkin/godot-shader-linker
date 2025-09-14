# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

"""
GSL Exporter — точка входа аддона Blender.

Назначение:
- Регистрация классов настроек и панели UI.
- Запуск/остановка фонового HTTP/UDP‑сервера при включении/выключении аддона.
- Применение настроек логирования и обработка завершения Blender.

Экспортируемые сущности:
- Классы: GSLAddonPreferences, GSL_PT_settings.
- Функции: register(), unregister().
"""

bl_info = {
    "name": "GSL Exporter",
    "author": "D.Jorkin",
    "version": (0, 2, 0),
    "blender": (4, 0, 0),
    "location": "Preferences > Add-ons",
    "description": "",
    "category": "Import-Export",
}

import bpy
from bpy.types import AddonPreferences, Panel
from bpy.props import StringProperty, BoolProperty, IntProperty
import json, os
import bpy.app.handlers as _h
import atexit

def _on_logging_prefs_update(self, context):
    try:
        from .logger import get_logger as _get_logger
        _get_logger(reconfigure=True)
    except Exception:
        pass

class GSLAddonPreferences(AddonPreferences):
    bl_idname = __name__

    godot_project_path: StringProperty(
        name="Path to Godot project",
        subtype="DIR_PATH",
        description="Root directory of the Godot project where textures will be copied",
        default=""
    )

    # Logging preferences
    debug_logging: BoolProperty(
        name="Enable debug logging",
        description="When enabled, logger uses DEBUG level; otherwise ERROR",
        default=False,
        update=_on_logging_prefs_update,
    )
    log_to_console: BoolProperty(
        name="Log to Blender console",
        default=True,
        update=_on_logging_prefs_update,
    )
    log_to_godot: BoolProperty(
        name="Log to Godot (UDP)",
        default=True,
        update=_on_logging_prefs_update,
    )
    log_udp_port: IntProperty(
        name="Log UDP port",
        default=6021,
        min=1,
        max=65535,
        update=_on_logging_prefs_update,
    )

    def draw(self, context):
        layout = self.layout
        layout.prop(self, "godot_project_path")
        layout.separator()
        box = layout.box()
        box.label(text="Logging")
        col = box.column(align=True)
        col.prop(self, "debug_logging")
        col.prop(self, "log_to_console")
        col.prop(self, "log_to_godot")
        col.prop(self, "log_udp_port")

class GSL_PT_settings(Panel):
    """Панель настроек GSL в контексте материала"""

    bl_label = "GSL Settings"
    bl_space_type = "PROPERTIES"
    bl_region_type = "WINDOW"
    bl_context = "material"

    @classmethod
    def poll(cls, context):
        # Панель всегда доступна, даже если материала нет
        return True

    def draw(self, context):
        layout = self.layout
        prefs = context.preferences.addons[__name__].preferences
        layout.prop(prefs, "godot_project_path")

classes = (
    GSLAddonPreferences,
    GSL_PT_settings,
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
        try:
            from .logger import get_logger as _get_logger
            _get_logger().getChild("addon").error(f"Failed to start HTTP server: {e}")
        except Exception:
            pass

    # Configure logger with current preferences
    try:
        from .logger import get_logger as _get_logger
        _get_logger(reconfigure=True)
    except Exception:
        pass

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
