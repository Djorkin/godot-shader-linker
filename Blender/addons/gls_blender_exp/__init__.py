bl_info = {
    "name": "GSL Exporter",
    "author": "D.Jorkin",
    "version": (1, 0, 0),
    "blender": (3, 0, 0),
    "location": "Preferences > Add-ons",
    "description": "",
    "category": "Import-Export",
}

import bpy
from bpy.types import AddonPreferences, Panel
from bpy.props import StringProperty
import json, os
import bpy.app.handlers as _h
import atexit

class GSLAddonPreferences(AddonPreferences):
    bl_idname = __name__


    godot_project_path: StringProperty(
        name="Path to Godot project",
        subtype="DIR_PATH",
        description="Root directory of the Godot project where textures will be copied",
        default=""
    )

    def draw(self, context):
        layout = self.layout
        layout.prop(self, "godot_project_path")

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

