/* SPDX-FileCopyrightText: 2025 D.Jorkin
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

/*
 Portions adapted from Blender GPU shaders to ensure behavior parity:
  - source/blender/gpu/shaders/common/gpu_shader_math_vector_lib.glsl
  - source/blender/gpu/shaders/material/gpu_shader_material_vector_math.glsl
 Copyright (c) Blender Authors, licensed under GPL-2.0-or-later.
 Adapted functions/behavior include: compatible_pow, safe_divide, safe_normalize,
 compatible_mod, wrap, and related vector math helpers.
*/

float reduce_max(vec3 color) {
    return max(max(color.r, color.g), color.b);
}

float sqrt_fast(float v)
{
    return intBitsToFloat(0x1fbd1df5 + (floatBitsToInt(v) >> 1));
}
vec2 sqrt_fast(vec2 v)
{
    return intBitsToFloat(0x1fbd1df5 + (floatBitsToInt(v) >> 1));
}

float saturate(float x) {
    return clamp(x, 0.0, 1.0);
}

vec2 saturate(vec2 x) {
    return clamp(x, 0.0, 1.0);
}

vec3 saturate(vec3 x) {
    return clamp(x, 0.0, 1.0);
}

vec4 saturate(vec4 x) {
    return clamp(x, 0.0, 1.0);
}

float _fract_abs(float x) { return fract(abs(x)); }

bool _is_almost_integer(float x) {
    float f = _fract_abs(x);
    return (f < 1e-5) || (abs(1.0 - f) < 1e-5);
}

float compatible_pow(float a, float b)
{
    if (a == 0.0) {
        if (b == 0.0) return 1.0;
        if (b < 0.0) return 0.0;
        return 0.0;
    }
    if (a < 0.0) {
        if (_is_almost_integer(b)) {
            float ib = floor(b + 0.5);
            float r = pow(-a, ib);
            return (mod(ib, 2.0) == 0.0) ? r : -r;
        }
        return 0.0;
    }
    return pow(a, b);
}

vec2 compatible_pow(vec2 a, vec2 b)
{
    return vec2(compatible_pow(a.x, b.x), compatible_pow(a.y, b.y));
}

vec3 compatible_pow(vec3 a, vec3 b)
{
    return vec3(compatible_pow(a.x, b.x), compatible_pow(a.y, b.y), compatible_pow(a.z, b.z));
}

vec4 compatible_pow(vec4 a, vec4 b)
{
    return vec4(compatible_pow(a.x, b.x), compatible_pow(a.y, b.y), compatible_pow(a.z, b.z), compatible_pow(a.w, b.w));
}

vec2 safe_divide(vec2 a, vec2 b)
{
    vec2 mask = step(vec2(1e-8), abs(b));
    vec2 divv = a / b;
    return mix(vec2(0.0), divv, mask);
}

vec3 safe_divide(vec3 a, vec3 b)
{
    vec3 mask = step(vec3(1e-8), abs(b));
    vec3 divv = a / b;
    return mix(vec3(0.0), divv, mask);
}

vec4 safe_divide(vec4 a, vec4 b)
{
    vec4 mask = step(vec4(1e-8), abs(b));
    vec4 divv = a / b;
    return mix(vec4(0.0), divv, mask);
}

float safe_divide(float a, float b)
{
    return (abs(b) < 1e-8) ? 0.0 : a / b;
}

vec3 safe_normalize(vec3 v)
{
    float len2 = dot(v, v);
    if (len2 > 1e-35) {
        return v * inversesqrt(len2);
    }
    return vec3(0.0);
}

float compatible_mod(float a, float b)
{
    return (abs(b) < 1e-8) ? 0.0 : mod(a, b);
}

vec2 compatible_mod(vec2 a, vec2 b)
{
    return vec2(compatible_mod(a.x, b.x), compatible_mod(a.y, b.y));
}

vec3 compatible_mod(vec3 a, vec3 b)
{
    return vec3(compatible_mod(a.x, b.x), compatible_mod(a.y, b.y), compatible_mod(a.z, b.z));
}

vec4 compatible_mod(vec4 a, vec4 b)
{
    return vec4(compatible_mod(a.x, b.x), compatible_mod(a.y, b.y), compatible_mod(a.z, b.z), compatible_mod(a.w, b.w));
}

float wrap(float a, float b, float c)
{
    float range = c - b;
    if (abs(range) < 1e-8) {
        return a;
    }
    return compatible_mod(a - b, range) + b;
}

vec2 wrap(vec2 a, vec2 b, vec2 c)
{
    return vec2(wrap(a.x, b.x, c.x), wrap(a.y, b.y, c.y));
}

vec3 wrap(vec3 a, vec3 b, vec3 c)
{
    return vec3(wrap(a.x, b.x, c.x), wrap(a.y, b.y, c.y), wrap(a.z, b.z, c.z));
}

vec4 wrap(vec4 a, vec4 b, vec4 c)
{
    return vec4(wrap(a.x, b.x, c.x), wrap(a.y, b.y, c.y), wrap(a.z, b.z, c.z), wrap(a.w, b.w, c.w));
}