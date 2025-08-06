/* SPDX-FileCopyrightText: 2025 D.Jorkin
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */


struct NoiseParams {
	float w;
	float scale;
	float detail;
	float roughness;
	float lacunarity;
	float offset; 
	float distortion;
	float gain;     
	bool  normalize; 
};



#ifdef NOISE_NONE_CONNECTED
#ifndef APPLY_GENERATED_DEFINED
#define APPLY_GENERATED_DEFINED
	const vec3 bbox_min = vec3(-1.0, 1.0, -1.0);
	const vec3 bbox_max = vec3( 1.0, -1.0,  1.0);

	vec3 apply_generated(vec3 vertex_pos) {
		vec3 gen = (vertex_pos - bbox_min) / (bbox_max - bbox_min);
		return clamp(gen, vec3(0.0), vec3(1.0));
	}
#endif 
#endif 