/* SPDX-FileCopyrightText: 2011-2022 Blender Foundation
 * SPDX-FileCopyrightText: 2025 D.Jorkin
 *
 * Inspired by Blender Cycles mix-nodes (OSL implementation):
 *   node_mix_float.osl, node_mix_vector*.osl, node_mix_color.osl
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

/* vec3 mix_apply(int blend_type, float t, vec3 col1, vec3 col2) {
    if (blend_type == 0)  return node_mix_blend   (t, col1, col2); 
    if (blend_type == 1)  return node_mix_dark    (t, col1, col2);
    if (blend_type == 2)  return node_mix_mul     (t, col1, col2);
    if (blend_type == 3)  return node_mix_burn    (t, col1, col2);
    if (blend_type == 4)  return node_mix_light   (t, col1, col2);
    if (blend_type == 5)  return node_mix_screen  (t, col1, col2);
    if (blend_type == 6)  return node_mix_dodge   (t, col1, col2);
    if (blend_type == 7)  return node_mix_add     (t, col1, col2);
    if (blend_type == 8)  return node_mix_overlay (t, col1, col2);
    if (blend_type == 9)  return node_mix_soft    (t, col1, col2);
    if (blend_type == 10) return node_mix_linear  (t, col1, col2);
    if (blend_type == 11) return node_mix_diff    (t, col1, col2);
    if (blend_type == 12) return node_mix_exclusion(t, col1, col2);
    if (blend_type == 13) return node_mix_sub     (t, col1, col2);
    if (blend_type == 14) return node_mix_div     (t, col1, col2);
    if (blend_type == 15) return node_mix_hue     (t, col1, col2);
    if (blend_type == 16) return node_mix_sat     (t, col1, col2);
    if (blend_type == 17) return node_mix_color   (t, col1, col2);
    if (blend_type == 18) return node_mix_val     (t, col1, col2);
    return node_mix_blend(t, col1, col2);
}

// COLOR
vec3 mix_color(int blend_type, 
                    bool use_clamp_factor, 
                    bool use_clamp_result,
                    float Factor, 
                    vec3 A, 
                    vec3 B) 
{
    float t = use_clamp_factor ? clamp(Factor, 0.0, 1.0) : Factor;
    vec3 res = mix_apply(blend_type, t, A, B);
    if (use_clamp_result) {
        res = node_mix_clamp(res);
    }
    return res;
} */

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
