/* SPDX-FileCopyrightText: 2019-2023 Blender Authors
 * SPDX-FileCopyrightText: 2025 D.Jorkin
 *
 * Adapted from Blender’s bump node:
 * https://raw.githubusercontent.com/blender/blender/refs/heads/main/source/blender/gpu/shaders/material/gpu_shader_material_bump.glsl
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */


#ifdef INCLUDE_WRAPPER

// Упрощённый node_bump: принимает dHd (dFdx, dFdy от height), pos и N в одном пространстве
vec3 node_bump(
    float strength,
    float dist,
    float filter_width,
    vec3 N,
    vec2 dHd,       
    float invert,
    bool front_facing,
    vec3 pos        
) {
    N = normalize(N);
    dist *= front_facing ? invert : -invert;

    float sx = length(dFdx(pos));
    float sy = length(dFdy(pos));
    float dscale = 1.0 / max(sx + sy, 1e-6);

    vec3 dPdx = dFdx(pos) * dscale;
    vec3 dPdy = dFdy(pos) * dscale;

    vec3 Rx = cross(dPdy, N);
    vec3 Ry = cross(N, dPdx);

    float det = dot(dPdx, Rx);
    vec3 surfgrad = dHd.x * Rx + dHd.y * Ry;

    vec3 bumped = normalize(filter_width * abs(det) * N - dist * sign(det) * surfgrad);
    return normalize(mix(N, bumped, clamp(strength, 0.0, 1.0)));
}


#endif
