/* SPDX-FileCopyrightText: 2019-2022 Blender Authors
 * SPDX-FileCopyrightText: 2025 D.Jorkin
 *
 * Adapted from Blender:
 *  - gpu_shader_material_tex_noise.glsl
 *    https://raw.githubusercontent.com/blender/blender/main/source/blender/gpu/shaders/material/gpu_shader_material_tex_noise.glsl
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */


#ifdef INCLUDE_WRAPPER

	float _rand_float_offset(float seed){
		return 100.0 + hash_float_to_float(seed) * 100.0;
	}
	vec2 _rand_vec2_offset(float seed){
		return vec2(100.0 + hash_vec2_to_float(vec2(seed,0.0)) * 100.0,
					100.0 + hash_vec2_to_float(vec2(seed,1.0)) * 100.0);
	}
	vec3 _rand_vec3_offset(float seed){
		return vec3(100.0 + hash_vec2_to_float(vec2(seed,0.0)) * 100.0,
					100.0 + hash_vec2_to_float(vec2(seed,1.0)) * 100.0,
					100.0 + hash_vec2_to_float(vec2(seed,2.0)) * 100.0);
	}
	vec4 _rand_vec4_offset(float seed){
		return vec4(100.0 + hash_vec2_to_float(vec2(seed,0.0)) * 100.0,
					100.0 + hash_vec2_to_float(vec2(seed,1.0)) * 100.0,
					100.0 + hash_vec2_to_float(vec2(seed,2.0)) * 100.0,
					100.0 + hash_vec2_to_float(vec2(seed,3.0)) * 100.0);
	}



#endif
