/* SPDX-FileCopyrightText: 2025 D.Jorkin
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */


Material material_from_color(vec4 c) {
    Material m;
    m.albedo = c.rgb;
    #ifdef ALPHA_TRANSFER
        m.alpha  = c.a;
    #endif
    m.metallic        = 0.0;
    m.roughness       = 0.5;
    m.specular_level  = 0.0;
	m.normal          = vec3(0.0);
    m.emission        = vec3(0.0);
    m.coat_weight     = 0.0;
    m.coat_roughness  = 0.0;
    return m;
}


Material material_from_color(vec3 c) {
    return material_from_color(vec4(c, 1.0));
}

Material material_from_color(vec2 c) {
    return material_from_color(vec4(c, 0.0, 1.0));
}

Material material_from_color(float c) {
    return material_from_color(vec4(c, c, c, 1.0));
}