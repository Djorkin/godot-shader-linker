/* SPDX-FileCopyrightText: 2025 D.Jorkin
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */




#ifdef NEED_AABB 
vec3 normalize_to_aabb(vec3 vertex_pos) {
	vec3 size = bbox_max - bbox_min;
	// fallback в юнит-куб
	if (size.x <= 0.0 || size.y <= 0.0 || size.z <= 0.0) {
		vec3 pseudo = vertex_pos * 0.5 + vec3(0.5);
		return clamp(pseudo, vec3(0.0), vec3(1.0));
	}
	vec3 gen = (vertex_pos - bbox_min) / size;
	return clamp(gen, vec3(0.0), vec3(1.0));
}
#endif

vec3 get_generated(vec3 vertex) {
	#ifdef NEED_AABB
		vec3 tex_coord = normalize_to_aabb((vertex) * ROT_X(-90.0));
		return tex_coord;
	#endif
	return vec3(0.0);
}


vec3 get_uv(vec2 uv) {
	#ifdef INCLUDE_WRAPPER
		return vec3(flip_uv(uv),0.0);
	#endif
	return vec3(0.0);
}

vec3 get_object(vec3 vertex) {
	#ifdef INCLUDE_WRAPPER 
		return (vertex) * ROT_X(-90.0);
	#endif
	return vec3(0.0);
}

vec3 get_window(vec2 screen) {
	#ifdef INCLUDE_WRAPPER
		return vec3(flip_uv(screen), 0.0);
	#endif
	return vec3(0.0);
}

vec3 get_reflection(mat4 view_matrix, vec3 v_world_pos, vec3 v_world_normal) {
	#ifdef INCLUDE_WRAPPER
		vec3 camera_world_pos = (inverse(view_matrix) * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		vec3 I = normalize(v_world_pos - camera_world_pos);
		vec3 R = reflect(-I, normalize(v_world_normal)).xzy * MIRROR_XZ;
		return R;
	#endif
	return vec3(0.0);
}

