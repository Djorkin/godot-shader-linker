/* SPDX-FileCopyrightText: 2025 D.Jorkin
 *
 * Custom implementation of Texture Coordinate helpers for Godot Shader Language.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

// Node: Texture Coordinate (UV)
#ifndef APPLY_GENERATED_DEFINED
#define APPLY_GENERATED_DEFINED
	const vec3 bbox_min = vec3(-1.0, 1.0, -1.0);
	const vec3 bbox_max = vec3( 1.0, -1.0,  1.0);

	vec3 apply_generated(vec3 vertex_pos) {
		vec3 gen = (vertex_pos - bbox_min) / (bbox_max - bbox_min);
		return clamp(gen, vec3(0.0), vec3(1.0));
	}
#endif 


vec3 get_generated(vec3 vertex) {
	#ifdef SHARED_DEFINE
		vec3 tex_coord = apply_generated(blender_to_godot(vertex));
		return tex_coord;
	#endif
	return vec3(0.0);
}

vec3 apply_normal(vec3 local_normal) {
	#ifdef SHARED_DEFINE
		return blender_to_godot_normal(local_normal * vec3(1.0,1.0,-1.0));
	#endif
	return vec3(0.0);
}

vec3 get_normal(vec3 normal) {
	return apply_normal(normal);
}

vec3 get_uv(vec2 uv) {
	#ifdef SHARED_DEFINE
		return vec3(flip_uv(uv),0);
	#endif
	return vec3(0.0);
}

vec3 get_object(vec3 vertex, mat4 matrix) {
	#ifdef SHARED_DEFINE
		vec3 godot_pos = blender_to_godot(vertex);
		godot_pos.y = -godot_pos.y;
		return godot_pos;
	#endif
	return vec3(0.0);
}

vec3 get_camera(vec3 vertex, mat4 matrix, mat4 matrix_camera) {
	#ifdef SHARED_DEFINE
        vec4 blender_world_pos = matrix * vec4(vertex, 1.0);
        vec4 cam_space_pos = matrix_camera * blender_world_pos;
        vec4 rotated_pos = ROT_90 * vec4(cam_space_pos.xyz, 1.0);
        return (inverse(BLENDER_TO_GODOT) * rotated_pos).xyz;
	#endif

	return vec3(0.0);
}

vec3 get_window(vec2 screen) {
	#ifdef SHARED_DEFINE
		return vec3(screen, 0.0);
	#endif
	return vec3(0.0);
}

vec3 get_world_pos(mat4 view_mat,mat4 model_mat, vec3 vertex) {
	vec3 v_world_pos = vec3(0.0);
	#ifdef SHARED_DEFINE
	    vec4 world_pos = inverse(view_mat) * model_mat * vec4(vertex.xzy, 1.0);
		return world_pos.xzy;
	#endif
	return v_world_pos;
}

vec3 get_world_normal(mat4 view_mat,mat4 model_mat, vec3 normal){
	vec3 v_world_normal = vec3(0.0);
	#ifdef SHARED_DEFINE
		vec3 world_normal = (inverse(view_mat) * model_mat * vec4(normal, 0.0)).xyz;
		return world_normal;
	#endif
	return v_world_normal;
}

vec3 get_reflection(mat4 view_matrix, vec3 v_world_pos, vec3 v_world_normal) {
	#ifdef SHARED_DEFINE
		vec3 camera_world_pos = (inverse(view_matrix) * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		vec3 I = normalize(v_world_pos - camera_world_pos);
		vec3 R = reflect(-I, normalize(v_world_normal)).xzy * MIRROR_XZ;
		return R;
	#endif
	return vec3(0.0);
}