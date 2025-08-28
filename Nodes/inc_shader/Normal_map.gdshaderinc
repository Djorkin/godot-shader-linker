/* SPDX-FileCopyrightText: 2025 D.Jorkin
 * Inspired by Blender normal-map node:
 * https://github.com/blender/blender/blob/main/source/blender/gpu/shaders/material/gpu_shader_material_normal_map.glsl
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#ifdef INCLUDE_WRAPPER

	vec3 get_normal_map(vec3 color, float s, vec3 normal, vec3 tangent) 
	{
		vec3 tex_color = color * 2.0 - 1.0;

		tex_color.xy *= s;
		tex_color.z = mix(1.0, tex_color.z, clamp(s, 0.0, 1.0));

		vec3 N = normal;                 
		vec3 T = normalize(tangent);     
		vec3 B = normalize(cross(N, T)); 

		vec3 out_n = tex_color.x * T + tex_color.y * B + tex_color.z * N;
		out_n = normalize(out_n);
		return out_n;
	}

#endif
