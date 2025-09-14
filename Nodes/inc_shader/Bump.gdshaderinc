/* SPDX-FileCopyrightText: 2025 D.Jorkin
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Portions adapted from Blender’s bump node:
 *  - source/blender/gpu/shaders/material/gpu_shader_material_bump.glsl
 *    https://raw.githubusercontent.com/blender/blender/refs/heads/main/source/blender/gpu/shaders/material/gpu_shader_material_bump.glsl
 * Copyright (c) Blender Authors, licensed under GPL-2.0-or-later.
 */


#ifdef INCLUDE_WRAPPER


// N и P должны быть в одном пространстве
// Аппроксимация Blender derivative_scale_get: нормализует вклад производных позиции,
// чтобы стабилизировать оценку градиента на экране и уменьшить alias.
float derivative_scale_get(vec3 P) {
    float sx = length(dFdx(P));
    float sy = length(dFdy(P));
    float s = sx + sy;
    return 1.0 / max(s, 1e-6);
}

vec3 node_bump(
    float strength,
    float dist,
    float filter_width,
    float height,
    vec3 N,
    vec2 height_xy,
    float invert,
    bool front_facing,
    vec3 P
) {
    N = normalize(N);
    dist *= front_facing ? invert : -invert;

    float dscale = derivative_scale_get(P);
    vec3 dPdx = dFdx(P) * dscale;
    vec3 dPdy = dFdy(P) * dscale;

    vec3 Rx = cross(dPdy, N);
    vec3 Ry = cross(N, dPdx);

    float det = dot(dPdx, Rx);

    vec2 dHd = height_xy - vec2(height);
    float strength_clamped = max(strength, 0.0);
    vec3 surfgrad = dHd.x * Rx + dHd.y * Ry;

    vec3 result = normalize(filter_width * abs(det) * N - dist * sign(det) * surfgrad);
    return normalize(mix(N, result, strength_clamped));
}


#endif
