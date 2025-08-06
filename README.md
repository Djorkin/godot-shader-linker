# Godot Shader Linker (GSL)

**GSL** is a plugin for Godot 4.4+ that transfers materials from Blender (EEVEE render) to Godot, automatically building a compatible shader and hooking up textures. The goal is to preserve as closely as possible the visual result familiar to artists while keeping their usual workflow, while the material remains *native* to the engine: all parameters are available via the Inspector, WorldEnvironment/IBL lighting and post-processing work.

## Key Features

* One-click import. The **Link Shader / Material** buttons create `.gdshader` and `.tres`.
* Parses the node graph and generates a Godot shader “on-the-fly”.
* Procedural textures — computed on the Godot GPU side.
* Full integration with the Godot ecosystem (Inspector, WorldEnvironment/IBL, post-processing).
* Parameter animation via GDScript or the `AnimationPlayer`.


## Installation
1. Copy the `addons/godot_shader_linker_(gsl)` directory into your Godot project.  
2. In **Project → Plugins** enable “Godot Shader Linker (GSL)”.  
3. A GSL UI will appear in the 3D viewport (`Ctrl + G` — hide/show).

### Setting up the Blender add-on
1. **Edit → Preferences → File Paths → Scripts Directories → Add** — specify the path `.../addons/godot_shader_linker_(gsl)/Blender`, `Name: gls_blender_exp`.  
2. Restart Blender and enable **GSL Exporter** (`Add-ons`).  
3. In the add-on settings set the path to your **Godot** project (needed to import textures).  
4. Switch to Godot — `Blender server started` will appear in **Output**.

## Quick Start
1. In Blender select a material in the **Shader Editor**.  
2. Press **Link Shader** or **Link Material**.  
3. The generated `.gdshader` / `.tres` will appear in Godot.  
4. Assign the material to a `MeshInstance` and check the result.


## Visual Match Recommendations
* Match the camera perspective in Godot and Blender.  
* Add a `WorldEnvironment`, load the same HDRI (`Sky`) and rotate it by 90°.  
* In the **Tonemap** tab choose **AgX**.  
* For materials with `Transmission > 0` set `transparency > 0`, otherwise the object will appear black.

## Known Issues
* **TAA** may flicker on animated/procedural materials. Use **FXAA** or reduce parameter dynamics.  
* **SDFGI** works incorrectly with transparent materials.

## License

The project is distributed under the **GPL-3.0-or-later** license. See the `LICENSE` file for details.

## Links

* Documentation: `docs/` *(WIP)*
* Blender add-on: `/Blender/` *(WIP)*
* Feedback / bug reports: *link will be added later*  
