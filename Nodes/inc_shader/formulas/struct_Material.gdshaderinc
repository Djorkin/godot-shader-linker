/* SPDX-FileCopyrightText: 2025 D.Jorkin
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */


struct Material {
	vec3 albedo;
	float metallic;
	float roughness;
	float alpha;
	float specular_level;
	vec3 normal;
	vec3 specular;
	vec3 emission;
	float coat_weight;
	float coat_roughness;
};

