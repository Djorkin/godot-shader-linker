/* SPDX-FileCopyrightText: 2025 D.Jorkin
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Portions adapted from Blender noise shader:
 *  - source/blender/gpu/shaders/material/gpu_shader_material_noise.glsl
 *    https://raw.githubusercontent.com/blender/blender/main/source/blender/gpu/shaders/material/gpu_shader_material_noise.glsl
 * Copyright (c) Blender Authors, licensed under GPL-2.0-or-later.
 */


#ifdef INCLUDE_WRAPPER


	const float _NOISE_WRAP_RANGE = 100000.0;
	const float _PRECISION_LIMIT  = 1000000.0;


	float _fade(float t) {
		return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
	}

	float _hash_vec2_float(vec2 p) {
		return hash_vec2_to_vec2(p).x;
	}
	float _hash_vec3_float(vec3 p) {
		return hash_vec3_to_vec3(p).x;
	}
	float _hash_vec4_float(vec4 p) {
		return hash_vec4_to_vec4(p).x;
	}

	uint _hash_int(int x) {
		return hash_int(x);
	}
	uint _hash_int2(int x, int y) {
		return hash_int2(x, y);
	}
	uint _hash_int3(int x, int y, int z) {
		return hash_int3(x, y, z);
	}
	uint _hash_int4(int x, int y, int z, int w) {
		return hash_int4(x, y, z, w);
	}

	float _negate_if(float value, uint condition) {
		return (condition != 0u) ? -value : value;
	}

	float _noise_grad(uint hash, float x) {
		uint h = hash & 15u;
		float g = 1.0 + float(h & 7u);
		return _negate_if(g, h & 8u) * x;
	}

	float _noise_grad(uint hash, float x, float y) {
		uint h = hash & 7u;
		float u = (h < 4u) ? x : y;
		float v = 2.0 * ((h < 4u) ? y : x);
		return _negate_if(u, h & 1u) + _negate_if(v, h & 2u);
	}

	float _noise_grad(uint hash, float x, float y, float z) {
		uint h = hash & 15u;
		float u = (h < 8u) ? x : y;
		float vt = ((h == 12u) || (h == 14u)) ? x : z;
		float v = (h < 4u) ? y : vt;
		return _negate_if(u, h & 1u) + _negate_if(v, h & 2u);
	}

	float _noise_grad(uint hash, float x, float y, float z, float w) {
		uint h = hash & 31u;
		float u = (h < 24u) ? x : y;
		float v = (h < 16u) ? y : z;
		float s = (h < 8u)  ? z : w;
		return _negate_if(u, h & 1u) + _negate_if(v, h & 2u) + _negate_if(s, h & 4u);
	}

	float _bi_mix(float v0, float v1, float v2, float v3, float x, float y) {
		float x1 = 1.0 - x;
		return (1.0 - y) * (v0 * x1 + v1 * x) + y * (v2 * x1 + v3 * x);
	}

	float _tri_mix(float v0, float v1, float v2, float v3, float v4, float v5, float v6, float v7, float x, float y, float z) {
		float x1 = 1.0 - x;
		float y1 = 1.0 - y;
		float z1 = 1.0 - z;
		return z1 * (y1 * (v0 * x1 + v1 * x) + y * (v2 * x1 + v3 * x)) +
		       z  * (y1 * (v4 * x1 + v5 * x) + y * (v6 * x1 + v7 * x));
	}

	float _quad_mix(float v0,float v1,float v2,float v3,float v4,float v5,float v6,float v7,float v8,float v9,float v10,float v11,float v12,float v13,float v14,float v15,float x,float y,float z,float w) {
		return mix(_tri_mix(v0,v1,v2,v3,v4,v5,v6,v7,x,y,z), _tri_mix(v8,v9,v10,v11,v12,v13,v14,v15,x,y,z), w);
	}


	float noise_perlin_1d(float x) {
		int X = int(floor(x));
		float fx = x - float(X);
		float u = _fade(fx);
		return mix(
			_noise_grad(_hash_int(X), fx),
			_noise_grad(_hash_int(X + 1), fx - 1.0),
			u);
	}

	float noise_perlin_2d(vec2 p) {
		ivec2 ip = ivec2(floor(p));
		vec2 fp = p - vec2(ip);
		float u = _fade(fp.x);
		float v = _fade(fp.y);

		float n00 = _noise_grad(_hash_int2(ip.x, ip.y), fp.x, fp.y);
		float n10 = _noise_grad(_hash_int2(ip.x + 1, ip.y), fp.x - 1.0, fp.y);
		float n01 = _noise_grad(_hash_int2(ip.x, ip.y + 1), fp.x, fp.y - 1.0);
		float n11 = _noise_grad(_hash_int2(ip.x + 1, ip.y + 1), fp.x - 1.0, fp.y - 1.0);

		return _bi_mix(n00, n10, n01, n11, u, v);
	}

	float noise_perlin_3d(vec3 p) {
		ivec3 ip = ivec3(floor(p));
		vec3 fp = p - vec3(ip);
		float u = _fade(fp.x);
		float v = _fade(fp.y);
		float w = _fade(fp.z);

		float n000 = _noise_grad(_hash_int3(ip.x, ip.y, ip.z), fp.x, fp.y, fp.z);
		float n100 = _noise_grad(_hash_int3(ip.x + 1, ip.y, ip.z), fp.x - 1.0, fp.y, fp.z);
		float n010 = _noise_grad(_hash_int3(ip.x, ip.y + 1, ip.z), fp.x, fp.y - 1.0, fp.z);
		float n110 = _noise_grad(_hash_int3(ip.x + 1, ip.y + 1, ip.z), fp.x - 1.0, fp.y - 1.0, fp.z);
		float n001 = _noise_grad(_hash_int3(ip.x, ip.y, ip.z + 1), fp.x, fp.y, fp.z - 1.0);
		float n101 = _noise_grad(_hash_int3(ip.x + 1, ip.y, ip.z + 1), fp.x - 1.0, fp.y, fp.z - 1.0);
		float n011 = _noise_grad(_hash_int3(ip.x, ip.y + 1, ip.z + 1), fp.x, fp.y - 1.0, fp.z - 1.0);
		float n111 = _noise_grad(_hash_int3(ip.x + 1, ip.y + 1, ip.z + 1), fp.x - 1.0, fp.y - 1.0, fp.z - 1.0);

		return _tri_mix(n000,n100,n010,n110,n001,n101,n011,n111,u,v,w);
	}

	float noise_perlin_4d(vec4 p) {
		ivec4 ip = ivec4(floor(p));
		vec4 fp = p - vec4(ip);
		float u = _fade(fp.x);
		float v = _fade(fp.y);
		float t = _fade(fp.z);
		float s = _fade(fp.w);

		float v0000 = _noise_grad(_hash_int4(ip.x, ip.y, ip.z, ip.w), fp.x, fp.y, fp.z, fp.w);
		float v1000 = _noise_grad(_hash_int4(ip.x + 1, ip.y, ip.z, ip.w), fp.x - 1.0, fp.y, fp.z, fp.w);
		float v0100 = _noise_grad(_hash_int4(ip.x, ip.y + 1, ip.z, ip.w), fp.x, fp.y - 1.0, fp.z, fp.w);
		float v1100 = _noise_grad(_hash_int4(ip.x + 1, ip.y + 1, ip.z, ip.w), fp.x - 1.0, fp.y - 1.0, fp.z, fp.w);
		float v0010 = _noise_grad(_hash_int4(ip.x, ip.y, ip.z + 1, ip.w), fp.x, fp.y, fp.z - 1.0, fp.w);
		float v1010 = _noise_grad(_hash_int4(ip.x + 1, ip.y, ip.z + 1, ip.w), fp.x - 1.0, fp.y, fp.z - 1.0, fp.w);
		float v0110 = _noise_grad(_hash_int4(ip.x, ip.y + 1, ip.z + 1, ip.w), fp.x, fp.y - 1.0, fp.z - 1.0, fp.w);
		float v1110 = _noise_grad(_hash_int4(ip.x + 1, ip.y + 1, ip.z + 1, ip.w), fp.x - 1.0, fp.y - 1.0, fp.z - 1.0, fp.w);

		float v0001 = _noise_grad(_hash_int4(ip.x, ip.y, ip.z, ip.w + 1), fp.x, fp.y, fp.z, fp.w - 1.0);
		float v1001 = _noise_grad(_hash_int4(ip.x + 1, ip.y, ip.z, ip.w + 1), fp.x - 1.0, fp.y, fp.z, fp.w - 1.0);
		float v0101 = _noise_grad(_hash_int4(ip.x, ip.y + 1, ip.z, ip.w + 1), fp.x, fp.y - 1.0, fp.z, fp.w - 1.0);
		float v1101 = _noise_grad(_hash_int4(ip.x + 1, ip.y + 1, ip.z, ip.w + 1), fp.x - 1.0, fp.y - 1.0, fp.z, fp.w - 1.0);
		float v0011 = _noise_grad(_hash_int4(ip.x, ip.y, ip.z + 1, ip.w + 1), fp.x, fp.y, fp.z - 1.0, fp.w - 1.0);
		float v1011 = _noise_grad(_hash_int4(ip.x + 1, ip.y, ip.z + 1, ip.w + 1), fp.x - 1.0, fp.y, fp.z - 1.0, fp.w - 1.0);
		float v0111 = _noise_grad(_hash_int4(ip.x, ip.y + 1, ip.z + 1, ip.w + 1), fp.x, fp.y - 1.0, fp.z - 1.0, fp.w - 1.0);
		float v1111 = _noise_grad(_hash_int4(ip.x + 1, ip.y + 1, ip.z + 1, ip.w + 1), fp.x - 1.0, fp.y - 1.0, fp.z - 1.0, fp.w - 1.0);

		return _quad_mix(
			v0000,v1000,v0100,v1100,
			v0010,v1010,v0110,v1110,
			v0001,v1001,v0101,v1101,
			v0011,v1011,v0111,v1111,
			u,v,t,s);
	}


	float _precision_corr(float v) {
		return 0.5 * step(_PRECISION_LIMIT, abs(v));
	}
	vec2 _precision_corr(vec2 v) {
		return 0.5 * vec2(step(_PRECISION_LIMIT, abs(v.x)), step(_PRECISION_LIMIT, abs(v.y)));
	}
	vec3 _precision_corr(vec3 v) {
		return 0.5 * vec3(step(_PRECISION_LIMIT, abs(v.x)), step(_PRECISION_LIMIT, abs(v.y)), step(_PRECISION_LIMIT, abs(v.z)));
	}
	vec4 _precision_corr(vec4 v) {
		return 0.5 * vec4(step(_PRECISION_LIMIT, abs(v.x)), step(_PRECISION_LIMIT, abs(v.y)), step(_PRECISION_LIMIT, abs(v.z)), step(_PRECISION_LIMIT, abs(v.w)));
	}


	float _wrap_coord(float v) {
		return (abs(v) < _NOISE_WRAP_RANGE) ? v : mod(v, _NOISE_WRAP_RANGE);
	}
	vec2 _wrap_coord(vec2 v) {
		return vec2(_wrap_coord(v.x), _wrap_coord(v.y));
	}
	vec3 _wrap_coord(vec3 v) {
		return vec3(_wrap_coord(v.x), _wrap_coord(v.y), _wrap_coord(v.z));
	}
	vec4 _wrap_coord(vec4 v) {
		return vec4(_wrap_coord(v.x), _wrap_coord(v.y), _wrap_coord(v.z), _wrap_coord(v.w));
	}

	float _noise_scale1(float r) { return 0.2500 * r; }
	float _noise_scale2(float r) { return 0.6616 * r; }
	float _noise_scale3(float r) { return 0.9820 * r; }
	float _noise_scale4(float r) { return 0.8344 * r; }

	float snoise(float p) {
		p = _wrap_coord(p) + _precision_corr(p);
		return _noise_scale1(noise_perlin_1d(p));
	}

	float snoise(vec2 p) {
		p = _wrap_coord(p) + _precision_corr(p);
		return _noise_scale2(noise_perlin_2d(p));
	}

	float snoise(vec3 p) {
		p = _wrap_coord(p) + _precision_corr(p);
		return _noise_scale3(noise_perlin_3d(p));
	}

	float snoise(vec4 p) {
		p = _wrap_coord(p) + _precision_corr(p);
		return _noise_scale4(noise_perlin_4d(p));
	}

	float noise(float p) {
		return 0.5 * snoise(p) + 0.5;
	}
	float noise(vec2 p) {
		return 0.5 * snoise(p) + 0.5;
	}
	float noise(vec3 p) {
		return 0.5 * snoise(p) + 0.5;
	}
	float noise(vec4 p) {
		return 0.5 * snoise(p) + 0.5;
	}

#endif 