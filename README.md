# Godot Shader Linker (GSL)

**GSL** is a shader graph assembler for Godot 4.2+. It accepts node-graph descriptions from external DCC tools and assembles an equivalent Godot shader. The GSL core ports nodes (their semantics and formulas); the current technical implementation targets Blender's material graph (EEVEE).

## Key Features

- One‑click import. The **Link Shader / Material** buttons create `.gdshader` and `.tres`.
- Parses the node graph and generates a Godot shader on the fly.
- Procedural textures — computed on the Godot GPU side.
- Full integration with the Godot ecosystem (Inspector, WorldEnvironment, post‑processing).
- Parameter animation via GDScript or `AnimationPlayer`.

<p align="center">
  <img src="https://github.com/Djorkin/godot-shader-linker/releases/download/v0.2.0/1.gif" alt="GSL demo 1" width="720"><br>
  <em>Linking a Blender material → Godot shader (GSL v0.2.0)</em>
</p>

<p align="center">
  <img src="https://github.com/Djorkin/godot-shader-linker/releases/download/v0.2.0/2.gif" alt="GSL demo 2" width="720">
</p>

<p align="center">
  <img src="https://github.com/Djorkin/godot-shader-linker/releases/download/v0.2.0/3.gif" alt="GSL demo 3" width="720">
</p>

## Installation
1. Copy the `addons/godot_shader_linker_(gsl)` directory into your Godot project.  
2. In **Project → Plugins** enable “Godot Shader Linker (GSL)”.  
3. The GSL UI will appear in the 3D viewport (`Ctrl + G` — hide/show).

### Setting up the Blender add‑on
1. **Edit → Preferences → File Paths → Scripts Directories → Add** — specify the path `.../addons/godot_shader_linker_(gsl)/Blender`, `Name: gls_blender_exp`.  
2. Restart Blender and enable **GSL Exporter** (`Add-ons`).  
3. In the add‑on settings set the path to your **Godot** project (needed to import textures).  
4. Switch to Godot — `Blender server started` will appear in **Output**.

## Quick Start
1. In Blender select a material in the **Shader Editor**.  
2. Press **Link Shader** or **Link Material**.  
3. The generated `.gdshader` / `.tres` will appear in Godot.  
4. Assign the material to a `MeshInstance` and check the result.

## Supported Nodes

- Coordinates
  - Texture Coordinate
  - Mapping

- Textures
  - Image Texture (projections: Flat, Box, Sphere, Tube; interpolations: Linear, Closest; extension: Repeat, Extend)
  - Noise Texture
  - Fractal Noise

- Color
  - Color Ramp

- Conversions
  - Combine Color
  - Separate Color
  - Combine XYZ
  - Separate XYZ

- Math
  - Math (subset of modes: Add, Subtract, Multiply, Divide, Power, Modulo, Floor, Ceil, Truncate, PingPong, Atan2, Compare, etc.)
  - Vector Math (subset: Add, Subtract, Multiply, Divide, Dot Product, Cross Product, Normalize, Length, Distance, Scale, Project, Reflect, Refract, Wrap, Snap)

- Normals and microrelief
  - Normal Map (Tangent Space)
  - Bump

- Shading
  - Principled BSDF (base set, simplified coat)

- Output
  - Material Output

## Known Issues
- TAA may flicker on animated/procedural materials. Use FXAA or reduce parameter dynamics.  
- SDFGI works incorrectly with transparent materials.
- For materials with `Transmission > 0`, set `transparency > 0`, otherwise the object will appear black.
- Before overwriting a material/shader, close it in Shader Editor — otherwise a previous version may remain in the project.
- In v0.2, after the first material import, a visual stretching may occur. Press the CPU DATA button to refresh data and fix the display.
- In certain node combinations the final signal may remain unfiltered, leading to noticeable aliasing.

## Visual Match Recommendations (with Blender)
- Match the camera perspective in Godot and Blender.  
- Add a `WorldEnvironment`, load the same HDRI (`Sky`) and rotate it by 90°.  
- In the **Tonemap** tab choose **AgX**.  

## License
The project is distributed under the **GPL-3.0-or-later** license.

## Attributions
Portions of the implementation are adapted from Blender sources to achieve behavior parity (Blender is distributed under GPL‑2.0‑or‑later):

- GPU Vector Math and utilities:
  - source/blender/gpu/shaders/common/gpu_shader_math_vector_lib.glsl
  - source/blender/gpu/shaders/common/gpu_shader_math_base_lib.glsl
  - source/blender/gpu/shaders/material/gpu_shader_material_vector_math.glsl
- Color Ramp:
  - source/blender/gpu/shaders/common/gpu_shader_common_color_ramp.glsl
- Principled BSDF and related utilities:
  - source/blender/gpu/shaders/material/gpu_shader_material_principled.glsl
- Bump:
  - source/blender/gpu/shaders/material/gpu_shader_material_bump.glsl
- Image Texture / projections and sampling:
  - source/blender/gpu/shaders/material/gpu_shader_material_tex_image.glsl
- Noise / Fractal Noise:
  - source/blender/gpu/shaders/material/gpu_shader_material_noise.glsl
- Hash/noise helpers:
  - source/blender/gpu/shaders/common/gpu_shader_common_hash.glsl
- Color conversions (Cycles):
  - intern/cycles/kernel/svm/node_color.h (partial utilities port)

Links to specific references and formulas are also duplicated in the headers of corresponding `.gdshaderinc` files (comment “Portions adapted from Blender…”).

## Links

- Documentation: `docs/` (WIP)
- Blender add‑on: `/Blender/` (WIP)

