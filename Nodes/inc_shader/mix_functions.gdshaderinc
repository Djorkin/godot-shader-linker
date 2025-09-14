/* SPDX-FileCopyrightText: 2025 D.Jorkin
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Portions adapted from Blender Cycles mix helpers (OSL):
 *   node_mix_float.osl, node_mix_vector.osl, node_mix_vector_non_uniform.osl, node_mix_color.osl
 * Copyright (c) Blender Foundation/Authors, licensed under GPL-2.0-or-later.
 */

// VECTOR (uniform factor) 
vec3 mix_vector(bool use_clamp_factor, float Factor, vec3 A, vec3 B) 
{
    float t = use_clamp_factor ? clamp(Factor, 0.0, 1.0) : Factor;
    return mix(A, B, t);
}

// VECTOR (non-uniform factor per component) 
vec3 mix_vector_non_uniform(bool use_clamp_factor, vec3 Factor, vec3 A, vec3 B) {
    vec3 t = use_clamp_factor ? clamp(Factor, vec3(0.0), vec3(1.0)) : Factor;
    return mix(A, B, t);
}

// FLOAT 
float mix_float(bool use_clamp_factor, float Factor, float A, float B) {
    float t = use_clamp_factor ? clamp(Factor, 0.0, 1.0) : Factor;
    return mix(A, B, t);
}
