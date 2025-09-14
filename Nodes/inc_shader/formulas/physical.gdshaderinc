/* SPDX-FileCopyrightText: 2025 D.Jorkin
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Portions adapted from Blender’s Principled BSDF utilities:
 *  - source/blender/gpu/shaders/material/gpu_shader_material_principled.glsl
 *    https://github.com/blender/blender/blob/main/source/blender/gpu/shaders/material/gpu_shader_material_principled.glsl
 * Copyright (c) Blender Authors, licensed under GPL-2.0-or-later.
 */


vec3 tint_from_color(vec3 color)
{
    float lum = dot(color, vec3(0.3, 0.6, 0.1));
    return (lum > 0.0) ? color / lum : vec3(1.0);
}

float principled_sheen(float NV, float rough) {
    float den = 35.6694 * rough * rough - 24.4269 * rough * NV - 0.1405 * NV * NV +
                6.1211 * rough + 0.28105 * NV - 0.1405;
    float num = 58.5299 * rough * rough - 85.0941 * rough * NV + 9.8955 * NV * NV +
                1.9250 * rough + 74.2268 * NV - 0.2246;
    return clamp(den / num, 0.0, 1.0);
}

float ior_from_F0(float F0)
{
    float f = sqrt(clamp(F0, 0.0, 0.99));
    return (-f - 1.0) / (f - 1.0);
}

float F0_from_ior(float ior) {
    return pow((ior - 1.0) / (ior + 1.0), 2.0);
}

// Convert Blender IOR to Godot Specular Level
float ior_to_specular_level(float ior) {
    float f0 = F0_from_ior(ior);
    // For high IOR like Blender (up to 100), allow high specular values
    return clamp(f0 / 0.08, 0.0, 8.0);
}

vec3 FresnelSchlick(float cosTheta, vec3 F0) {
	return F0 + (vec3(1.0) - F0) * pow(1.0 - cosTheta, 5.0);
}

vec3 multiscatter_compensation(vec3 F, float roughness) {
    float fac = (1.0 - roughness) * 0.25;
    return 1.0 + F * fac / (1.0 - F * fac);
}

vec3 multiscatter_GGX(vec3 F, float roughness) {
    return F * multiscatter_compensation(F, roughness);
}

float orenNayarBRDF(vec3 N, vec3 L, vec3 V, float roughness) {
    float sigma = roughness;
    float sigma2 = sigma * sigma;
    float A = 1.0 - sigma2 / (2.0 * (sigma2 + 0.33));
    float B = 0.45 * sigma2 / (sigma2 + 0.09);

    float theta_i = acos(clamp(dot(N, L), 0.0, 1.0));
    float theta_r = acos(clamp(dot(N, V), 0.0, 1.0));
    float alpha = max(theta_i, theta_r);
    float beta = min(theta_i, theta_r);

    vec3 L_perp = normalize(L - N * dot(N, L));
    vec3 V_perp = normalize(V - N * dot(N, V));
    float cos_phi = max(dot(L_perp, V_perp), 0.0);

    return A + B * cos_phi * sin(alpha) * tan(beta);
}

float DistributionGGX(vec3 N, vec3 H, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.001);
    float NdotH2 = NdotH * NdotH;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    return a2 / (PI * denom * denom);
}

float GeometrySchlickGGX(float NdotX, float roughness) {
    float r = roughness + 1.0;
    float k = (r * r) / 8.0;
    return NdotX / (NdotX * (1.0 - k) + k);
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.001);
    float NdotL = max(dot(N, L), 0.001);
    float ggx1 = GeometrySchlickGGX(NdotV, roughness);
    float ggx2 = GeometrySchlickGGX(NdotL, roughness);
    return ggx1 * ggx2;
}

void bsdf(
    vec3 F0,
    vec3 F90,
    vec3 sqrt_base,
    float NV,
    float roughness,
    float ior,
    bool do_multiscatter,
    out vec3 reflectance,
    out vec3 transmittance
) {
    vec3 F = F0 + (F90 - F0) * pow(1.0 - NV, 5.0);

    if (do_multiscatter) {
        vec3 Ft = 1.0 - F;
        vec3 Favg = mix(F0, F90, 0.04);
        vec3 Fms = Favg * (1.0 - exp(-roughness * 5.0));
        F += Fms * Ft;
    }

    reflectance = F;
    transmittance = (vec3(1.0) - F) * sqrt_base;
}

float bsdf(
    float NV,
    float roughness,
    float ior,
    bool do_multiscatter
) {
    vec3 F0 = vec3(F0_from_ior(ior));
    vec3 F90 = vec3(1.0);
    vec3 sqrt_base = vec3(1.0);

    vec3 reflectance, transmittance;

    bsdf(F0, F90, sqrt_base, NV, roughness, ior, do_multiscatter, reflectance, transmittance);

    return dot(reflectance, vec3(0.3333));
}
