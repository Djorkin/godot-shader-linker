/* SPDX-FileCopyrightText: 2025 D.Jorkin
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
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