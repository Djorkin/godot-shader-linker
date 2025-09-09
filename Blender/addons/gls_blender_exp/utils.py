import re
import os

try:
    import bpy  # type: ignore
except Exception:
    bpy = None  # type: ignore

TEXTURE_DIR_NAME = "GSL_Texture"

def sanitize(text: str) -> str:
    text = text.replace(" ", "_").replace(".", "_")
    return re.sub(r"[^0-9A-Za-z_]+", "_", text)

def make_node_id(name: str, idx: int) -> str:
    return f"{sanitize(name)}_{idx:03d}"

def bl_to_gsl_class(bl_id: str) -> str:
    if bl_id.startswith("ShaderNode"):
        core = bl_id[len("ShaderNode"):]
    else:
        core = bl_id
    return f"{core}Module"

def get_export_base_dir() -> str:
    # 1) attempt to read value defined in net_server.EXPORT_BASE_DIR
    try:
        from . import net_server  # lazy import to avoid circular at module load
        if getattr(net_server, "EXPORT_BASE_DIR", ""):
            return net_server.EXPORT_BASE_DIR  # type: ignore[attr-defined]
    except Exception:
        pass

    # 2) addon preferences
    try:
        if bpy is None:
            return ""
        for ad_name, ad in bpy.context.preferences.addons.items():
            prefs = getattr(ad, "preferences", None)
            if prefs and hasattr(prefs, "godot_project_path"):
                return prefs.godot_project_path
    except Exception:
        pass

    # 3) fallback: disabled copying
    return ""
