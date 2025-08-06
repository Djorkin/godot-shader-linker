/* SPDX-FileCopyrightText: 2019-2023 Blender Authors
 * SPDX-FileCopyrightText: 2025 D.Jorkin
 *
 * Adapted from Blender’s bump node:
 * https://github.com/blender/blender/blob/main/source/blender/gpu/shaders/material/gpu_shader_material_bump.glsl
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */


#ifdef SHARED_DEFINE

	vec3 dF_impl(vec3 v) {
		return dFdx(v) + dFdy(v);
	}

	vec3 differentiate_texco(vec3 v)
	{
	return v + dF_impl(v);
	}

	vec3 differentiate_texco(vec4 v)
	{
	return v.xyz + dF_impl(v.xyz);
	}

	vec3 node_bump(float strength,
				float dist,
				float filter_width,
				float height,
				vec3 N,
				vec2 height_xy,
				float invert,
				bool FF,
				vec3 pos)
	{
		N = normalize(N);
		dist *= FF ? invert : -invert;

		vec3 dPdx = dFdx(pos);
		vec3 dPdy = dFdy(pos);

		/* Get surface tangents from normal. */
		vec3 Rx = cross(dPdy, N);
		vec3 Ry = cross(N, dPdx);

		/* Compute surface gradient and determinant. */
		float det = dot(dPdx, Rx);

		vec2 dHd = height_xy - vec2(height);
		vec3 surfgrad = dHd.x * Rx + dHd.y * Ry;

		strength = max(strength, 0.0f);

		vec3 result = normalize(filter_width * abs(det) * N - dist * sign(det) * surfgrad);
		result = normalize(mix(N, result, strength));
		return result;
	}

#endif
