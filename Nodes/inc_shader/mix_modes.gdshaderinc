/* SPDX-FileCopyrightText: 2011-2022 Blender Foundation
 * SPDX-FileCopyrightText: 2025 D.Jorkin
 *
 * Adapted from Blender Cycles color-blend helpers:
 *   node_color_blend.h
 *   node_mix_color.osl
 *   node_mix_float.osl
 *   node_mix_vector.osl
 *   node_mix_vector_non_uniform.osl
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

// mix
vec3 node_mix_blend(float t, vec3 col1, vec3 col2) {
    return mix(col1, col2, t);
}

// Add
vec3 node_mix_add(float t, vec3 col1, vec3 col2) {
    return mix(col1, col1 + col2, t);
}

// Multiply
vec3 node_mix_mul(float t, vec3 col1, vec3 col2) {
    return mix(col1, col1 * col2, t);
}

// Screen
vec3 node_mix_screen(float t, vec3 col1, vec3 col2) {
    float tm = 1.0 - t;
    return vec3(1.0) - (vec3(tm) + t * (vec3(1.0) - col2)) * (vec3(1.0) - col1);
}

// Overlay (unrolled, без динамической индексации)
vec3 node_mix_overlay(float t, vec3 col1, vec3 col2) {
    float tm = 1.0 - t;

    float r = (col1.r < 0.5)
        ? col1.r * (tm + 2.0 * t * col2.r)
        : 1.0 - (tm + 2.0 * t * (1.0 - col2.r)) * (1.0 - col1.r);

    float g = (col1.g < 0.5)
        ? col1.g * (tm + 2.0 * t * col2.g)
        : 1.0 - (tm + 2.0 * t * (1.0 - col2.g)) * (1.0 - col1.g);

    float b = (col1.b < 0.5)
        ? col1.b * (tm + 2.0 * t * col2.b)
        : 1.0 - (tm + 2.0 * t * (1.0 - col2.b)) * (1.0 - col1.b);

    return vec3(r, g, b);
}

// Subtract
vec3 node_mix_sub(float t, vec3 col1, vec3 col2) {
    return mix(col1, col1 - col2, t);
}

// Divide (unrolled, без динамической индексации)
vec3 node_mix_div(float t, vec3 col1, vec3 col2) {
    float tm = 1.0 - t;

    float r = (col2.r != 0.0) ? tm * col1.r + t * col1.r / col2.r : col1.r;
    float g = (col2.g != 0.0) ? tm * col1.g + t * col1.g / col2.g : col1.g;
    float b = (col2.b != 0.0) ? tm * col1.b + t * col1.b / col2.b : col1.b;

    return vec3(r, g, b);
}

// Difference
vec3 node_mix_diff(float t, vec3 col1, vec3 col2) {
    return mix(col1, abs(col1 - col2), t);
}

// Exclusion
vec3 node_mix_exclusion(float t, vec3 col1, vec3 col2) {
    return max(mix(col1, col1 + col2 - 2.0 * col1 * col2, t), vec3(0.0));
}

// Dark
vec3 node_mix_dark(float t, vec3 col1, vec3 col2) {
    return mix(col1, min(col1, col2), t);
}

// Light
vec3 node_mix_light(float t, vec3 col1, vec3 col2) {
    return mix(col1, max(col1, col2), t);
}

// Dodge (unrolled, без динамической индексации)
vec3 node_mix_dodge(float t, vec3 col1, vec3 col2) {
    float tmp_r = 1.0 - t * col2.r;
    float tmp_g = 1.0 - t * col2.g;
    float tmp_b = 1.0 - t * col2.b;

    float r = (col1.r == 0.0) ? 0.0 : ((tmp_r <= 0.0) ? 1.0 : clamp(col1.r / tmp_r, 0.0, 1.0));
    float g = (col1.g == 0.0) ? 0.0 : ((tmp_g <= 0.0) ? 1.0 : clamp(col1.g / tmp_g, 0.0, 1.0));
    float b = (col1.b == 0.0) ? 0.0 : ((tmp_b <= 0.0) ? 1.0 : clamp(col1.b / tmp_b, 0.0, 1.0));

    return vec3(r, g, b);
}

// Burn (unrolled, без динамической индексации)
vec3 node_mix_burn(float t, vec3 col1, vec3 col2) {
    float tm = 1.0 - t;

    float tmp_r = tm + t * col2.r;
    float tmp_g = tm + t * col2.g;
    float tmp_b = tm + t * col2.b;

    float r = (tmp_r <= 0.0) ? 0.0 : clamp(1.0 - (1.0 - col1.r) / tmp_r, 0.0, 1.0);
    float g = (tmp_g <= 0.0) ? 0.0 : clamp(1.0 - (1.0 - col1.g) / tmp_g, 0.0, 1.0);
    float b = (tmp_b <= 0.0) ? 0.0 : clamp(1.0 - (1.0 - col1.b) / tmp_b, 0.0, 1.0);

    return vec3(r, g, b);
}

// Hue
vec3 node_mix_hue(float t, vec3 col1, vec3 col2) {
    vec3 outcol = col1;
    vec3 hsv2 = rgb_to_hsv(col2);
    if (hsv2.y != 0.0) {
        vec3 hsv = rgb_to_hsv(outcol);
        hsv.x = hsv2.x;
        outcol = mix(outcol, hsv_to_rgb(hsv), t);
    }
    return outcol;
}

// Saturation
vec3 node_mix_sat(float t, vec3 col1, vec3 col2) {
    float tm = 1.0 - t;
    vec3 outcol = col1;
    vec3 hsv = rgb_to_hsv(outcol);
    if (hsv.y != 0.0) {
        vec3 hsv2 = rgb_to_hsv(col2);
        hsv.y = tm * hsv.y + t * hsv2.y;
        outcol = hsv_to_rgb(hsv);
    }
    return outcol;
}

// Value
vec3 node_mix_val(float t, vec3 col1, vec3 col2) {
    float tm = 1.0 - t;
    vec3 hsv = rgb_to_hsv(col1);
    vec3 hsv2 = rgb_to_hsv(col2);
    hsv.z = tm * hsv.z + t * hsv2.z;
    return hsv_to_rgb(hsv);
}

// Color
vec3 node_mix_color(float t, vec3 col1, vec3 col2) {
    vec3 outcol = col1;
    vec3 hsv2 = rgb_to_hsv(col2);
    if (hsv2.y != 0.0) {
        vec3 hsv = rgb_to_hsv(outcol);
        hsv.x = hsv2.x;
        hsv.y = hsv2.y;
        outcol = mix(outcol, hsv_to_rgb(hsv), t);
    }
    return outcol;
}

// Soft
vec3 node_mix_soft(float t, vec3 col1, vec3 col2) {
    float tm = 1.0 - t;
    vec3 one = vec3(1.0);
    vec3 scr = one - (one - col2) * (one - col1);
    return tm * col1 + t * ((one - col1) * col2 * col1 + col1 * scr);
}

// Linear Light (unrolled, без динамической индексации)
vec3 node_mix_linear(float t, vec3 col1, vec3 col2) {
    float r = (col2.r > 0.5)
        ? col1.r + t * (2.0 * (col2.r - 0.5))
        : col1.r + t * (2.0 * col2.r - 1.0);

    float g = (col2.g > 0.5)
        ? col1.g + t * (2.0 * (col2.g - 0.5))
        : col1.g + t * (2.0 * col2.g - 1.0);

    float b = (col2.b > 0.5)
        ? col1.b + t * (2.0 * (col2.b - 0.5))
        : col1.b + t * (2.0 * col2.b - 1.0);

    return vec3(r, g, b);
}

// Clamp
vec3 node_mix_clamp(vec3 col) {
    return clamp(col, 0.0, 1.0);
}
