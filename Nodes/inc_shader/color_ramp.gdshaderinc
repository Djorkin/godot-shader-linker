// SPDX-FileCopyrightText: 2025 D.Jorkin
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Portions adapted from Blender GPU shaders to ensure behavior parity:
//  - source/blender/gpu/shaders/common/gpu_shader_common_color_ramp.glsl
// Copyright (c) Blender Authors, licensed under GPL-2.0-or-later.

// Color Ramp helpers (adapted from Blender gpu_shader_common_color_ramp.glsl)

void valtorgb_opti_constant(float fac, float edge, vec4 color1, vec4 color2, out vec4 outcol, out float outalpha)
{
    outcol = (fac > edge) ? color2 : color1;
    outalpha = outcol.a;
}

void valtorgb_opti_linear(float fac, vec2 mulbias, vec4 color1, vec4 color2, out vec4 outcol, out float outalpha)
{
    fac = clamp(fac * mulbias.x + mulbias.y, 0.0, 1.0);
    outcol = mix(color1, color2, fac);
    outalpha = outcol.a;
}

void valtorgb_opti_ease(float fac, vec2 mulbias, vec4 color1, vec4 color2, out vec4 outcol, out float outalpha)
{
    fac = clamp(fac * mulbias.x + mulbias.y, 0.0, 1.0);
    fac = fac * fac * (3.0 - 2.0 * fac);
    outcol = mix(color1, color2, fac);
    outalpha = outcol.a;
}

float compute_color_map_coordinate(float coordinate)
{
    const float sampler_resolution = 257.0;
    const float sampler_offset = 0.5 / sampler_resolution;
    const float sampler_scale = 1.0 - (1.0 / sampler_resolution);
    return coordinate * sampler_scale + sampler_offset;
}

void valtorgb_lut(float fac, sampler2D colormap, out vec4 outcol, out float outalpha)
{
    vec2 uv = vec2(compute_color_map_coordinate(fac), 0.5);
    outcol = texture(colormap, uv);
    outalpha = outcol.a;
}

void valtorgb_lut_nearest(float fac, sampler2D colormap, out vec4 outcol, out float outalpha)
{
    fac = clamp(fac, 0.0, 1.0);
    // Emulate nearest by snapping to center of the nearest texel in X.
    float w = float(textureSize(colormap, 0).x);
    float x = floor(fac * (w - 1.0)) + 0.5;
    vec2 uv = vec2(x / w, 0.5);
    outcol = texture(colormap, uv);
    outalpha = outcol.a;
}
