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

