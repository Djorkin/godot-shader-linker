/* SPDX-FileCopyrightText: 2025 D.Jorkin
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Portions adapted from Blender Cycles utility:
 *   node_color.h
 * Copyright (c) Blender Foundation/Authors, licensed under GPL-2.0-or-later.
 */

float color_srgb_to_scene_linear(float c) {
    if (c < 0.04045) {
        return (c < 0.0) ? 0.0 : c * (1.0 / 12.92);
    } else {
        return pow((c + 0.055) * (1.0 / 1.055), 2.4);
    }
}


float color_scene_linear_to_srgb(float c) {
    if (c < 0.0031308) {
        return (c < 0.0) ? 0.0 : c * 12.92;
    } else {
        return 1.055 * pow(c, 1.0 / 2.4) - 0.055;
    }
}


vec3 color_srgb_to_scene_linear(vec3 c) {
    return vec3(
        color_srgb_to_scene_linear(c.r),
        color_srgb_to_scene_linear(c.g),
        color_srgb_to_scene_linear(c.b)
    );
}

vec3 color_scene_linear_to_srgb(vec3 c) {
    return vec3(
        color_scene_linear_to_srgb(c.r),
        color_scene_linear_to_srgb(c.g),
        color_scene_linear_to_srgb(c.b)
    );
}


vec3 color_unpremultiply(vec3 c, float alpha) {
    if (alpha != 1.0 && alpha != 0.0) {
        return c / alpha;
    }
    return c;
}


vec3 xyY_to_xyz(float x, float y, float Y) {
    float X = (y != 0.0) ? (x / y) * Y : 0.0;
    float Z = (y != 0.0 && Y != 0.0) ? ((1.0 - x - y) / y) * Y : 0.0;
    return vec3(X, Y, Z);
}


vec3 xyz_to_rgb(float x, float y, float z) {
    return vec3(
        3.240479 * x + -1.537150 * y + -0.498535 * z,
        -0.969256 * x + 1.875991 * y + 0.041556 * z,
        0.055648 * x + -0.204043 * y + 1.057311 * z
    );
}


vec3 rgb_to_hsv(vec3 rgb) {
    float cmax = max(max(rgb.r, rgb.g), rgb.b);
    float cmin = min(min(rgb.r, rgb.g), rgb.b);
    float delta = cmax - cmin;
    float h = 0.0;
    float s = (cmax != 0.0) ? delta / cmax : 0.0;
    float v = cmax;

    if (s != 0.0) {
        if (rgb.r == cmax) {
            h = (rgb.g - rgb.b) / delta;
        } else if (rgb.g == cmax) {
            h = 2.0 + (rgb.b - rgb.r) / delta;
        } else {
            h = 4.0 + (rgb.r - rgb.g) / delta;
        }
        h = fract((h / 6.0) + 1.0);
    }
    return vec3(h, s, v);
}


vec3 hsv_to_rgb(vec3 hsv) {
    float h = hsv.x;
    float s = hsv.y;
    float v = hsv.z;
    if (s == 0.0) {
        return vec3(v);
    }
    h = fract(h) * 6.0;
    float i = floor(h);
    float f = h - i;
    float p = v * (1.0 - s);
    float q = v * (1.0 - s * f);
    float t = v * (1.0 - s * (1.0 - f));
    if (i == 0.0) return vec3(v, t, p);
    if (i == 1.0) return vec3(q, v, p);
    if (i == 2.0) return vec3(p, v, t);
    if (i == 3.0) return vec3(p, q, v);
    if (i == 4.0) return vec3(t, p, v);
    return vec3(v, p, q);
}


vec3 rgb_to_hsl(vec3 rgb) {
    float cmax = max(max(rgb.r, rgb.g), rgb.b);
    float cmin = min(min(rgb.r, rgb.g), rgb.b);
    float l = min(1.0, (cmax + cmin) * 0.5);
    float h = 0.0;
    float s = 0.0;

    if (cmax != cmin) {
        float delta = cmax - cmin;
        s = (l > 0.5) ? delta / (2.0 - cmax - cmin) : delta / (cmax + cmin);
        if (cmax == rgb.r) {
            h = (rgb.g - rgb.b) / delta + (rgb.g < rgb.b ? 6.0 : 0.0);
        } else if (cmax == rgb.g) {
            h = (rgb.b - rgb.r) / delta + 2.0;
        } else {
            h = (rgb.r - rgb.g) / delta + 4.0;
        }
        h = fract(h / 6.0);
    }
    return vec3(h, s, l);
}


vec3 hsl_to_rgb(vec3 hsl) {
    float h = hsl.x;
    float s = hsl.y;
    float l = hsl.z;

    float nr = abs(h * 6.0 - 3.0) - 1.0;
    float ng = 2.0 - abs(h * 6.0 - 2.0);
    float nb = 2.0 - abs(h * 6.0 - 4.0);

    nr = clamp(nr, 0.0, 1.0);
    ng = clamp(ng, 0.0, 1.0);
    nb = clamp(nb, 0.0, 1.0);

    float chroma = (1.0 - abs(2.0 * l - 1.0)) * s;

    return vec3(
        (nr - 0.5) * chroma + l,
        (ng - 0.5) * chroma + l,
        (nb - 0.5) * chroma + l
    );
}
