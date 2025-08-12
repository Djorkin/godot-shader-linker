/* SPDX-FileCopyrightText: 2025 D.Jorkin
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */


const mat4 BLENDER_TO_GODOT = mat4(
    vec4(1.0, 0.0, 0.0, 0.0),
    vec4(0.0, 0.0, 1.0, 0.0),
    vec4(0.0, 1.0, 0.0, 0.0),
    vec4(0.0, 0.0, 0.0, 1.0)
);

const mat4 ROT_90 = mat4(
    vec4(1.0, 0.0,  0.0, 0.0),
    vec4(0.0, 0.0, 1.0, 0.0),
    vec4(0.0, -1.0,  0.0, 0.0),
    vec4(0.0, 0.0,  0.0, 1.0)
);

const mat3 ROT_MATRIX_Y_TO_Z = mat3(
    vec3(1.0,  0.0, 0.0),
    vec3(0.0,  0.0, -1.0),
    vec3(0.0, 1.0, 0.0)
);

const mat3 ROT_MATRIX_Z_TO_Y = mat3(
    vec3(1.0,  0.0, 0.0),   
    vec3(0.0,  0.0, 1.0),  
    vec3(0.0, -1.0, 0.0)  
);


const mat3 MIRROR_XZ = mat3(
    vec3(-1.0, 0.0, 0.0),
    vec3(0.0, 1.0, 0.0),
    vec3(0.0, 0.0, -1.0)
);





vec3 blender_to_godot(vec3 blender_pos) {
    return (BLENDER_TO_GODOT * vec4(blender_pos, 1.0)).xyz;
}

vec3 blender_to_godot_normal(vec3 blender_normal) {
    return normalize((BLENDER_TO_GODOT * vec4(blender_normal, 0.0)).xyz) ;
}

vec2 flip_uv(vec2 uv) { return vec2(uv.x, 1.0 - uv.y);}



#ifdef SHARED_DEFINE

// Позиции
vec3 obj_to_world_pos(vec3 p, mat4 model_matrix) { return (model_matrix * vec4(p, 1.0)).xyz; }
vec3 world_to_view_pos(vec3 p, mat4 view_matrix) { return (view_matrix * vec4(p, 1.0)).xyz; }
vec3 obj_to_view_pos(vec3 p, mat4 model_matrix, mat4 view_matrix) { return world_to_view_pos(obj_to_world_pos(p, model_matrix), view_matrix); }
vec3 view_to_world_pos(vec3 p, mat4 view_matrix) { return (inverse(view_matrix) * vec4(p, 1.0)).xyz; }

// Направления (включая тангенс/битангенс)
vec3 obj_to_world_dir(vec3 d, mat4 model_matrix) { return (model_matrix * vec4(d, 0.0)).xyz; }
vec3 world_to_view_dir(vec3 d, mat4 view_matrix) { return (view_matrix * vec4(d, 0.0)).xyz; }
vec3 obj_to_view_dir(vec3 d, mat4 model_matrix, mat4 view_matrix) { return world_to_view_dir(obj_to_world_dir(d, model_matrix), view_matrix); }
vec3 view_to_world_dir(vec3 d, mat4 view_matrix) { return (inverse(view_matrix) * vec4(d, 0.0)).xyz; }

// Нормали
vec3 obj_to_world_normal(vec3 n, mat4 model_matrix) { return normalize(model_matrix * vec4(n, 0.0)).xyz; }
vec3 world_to_view_normal(vec3 n, mat4 view_matrix) { return normalize((view_matrix * vec4(n, 0.0)).xyz); }
vec3 obj_to_view_normal(vec3 n, mat4 model_matrix, mat4 view_matrix) { return world_to_view_normal(obj_to_world_normal(n, model_matrix), view_matrix); }
vec3 view_to_world_normal(vec3 n, mat4 view_matrix) { return normalize((inverse(view_matrix) * vec4(n, 0.0)).xyz); }

// Камера
vec3 camera_world_pos(mat4 view_matrix) { return (inverse(view_matrix) * vec4(0.0, 0.0, 0.0, 1.0)).xyz; }

#endif