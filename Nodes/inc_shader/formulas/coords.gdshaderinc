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

#ifdef INCLUDE_WRAPPER

// Структуры контекстов
struct TransformCtx {
    mat4 model;
    mat3 model_normal;
    mat4 view;
    mat4 inv_view;
    mat4 projection;
    mat4 inv_projection;
    mat4 viewproj;
    mat4 inv_viewproj;
};

struct TangentFrame {
    vec3 normal;          // базовая нормаль (в obj/world — см. комментарии к функциям)
    vec3 tangent;         // базовый тангенс в том же пространстве
    float bitangent_sign; // +1 / -1
};

TransformCtx make_ctx(mat4 model_matrix, mat3 model_normal_matrix, mat4 view_matrix, mat4 inv_view_matrix, mat4 projection_matrix, mat4 inv_projection_matrix) {
    TransformCtx c;
    c.model = model_matrix;
    c.model_normal = model_normal_matrix;
    c.view = view_matrix;
    c.inv_view = inv_view_matrix;
    c.projection = projection_matrix;
    c.inv_projection = inv_projection_matrix;
    c.viewproj = projection_matrix * view_matrix;
    c.inv_viewproj = inv_view_matrix * inv_projection_matrix; // (VP)^{-1} = V^{-1} * P^{-1}
    return c;
}

// Позиции
vec3 obj_to_world_pos(vec3 p, mat4 model_matrix) { return (model_matrix * vec4(p, 1.0)).xyz; }
vec3 world_to_view_pos(vec3 p, mat4 view_matrix) { return (view_matrix * vec4(p, 1.0)).xyz; }
vec3 obj_to_view_pos(vec3 p, mat4 model_matrix, mat4 view_matrix) { return world_to_view_pos(obj_to_world_pos(p, model_matrix), view_matrix); }
vec3 view_to_world_pos(vec3 p, mat4 view_matrix) { return (inverse(view_matrix) * vec4(p, 1.0)).xyz; }

// Позиции (через контекст)
vec3 obj_to_world_pos_ctx(vec3 p, TransformCtx ctx) { return (ctx.model * vec4(p, 1.0)).xyz; }
vec3 world_to_view_pos_ctx(vec3 p, TransformCtx ctx) { return (ctx.view * vec4(p, 1.0)).xyz; }
vec3 obj_to_view_pos_ctx(vec3 p, TransformCtx ctx) { return world_to_view_pos_ctx(obj_to_world_pos_ctx(p, ctx), ctx); }
vec3 view_to_world_pos_ctx(vec3 p, TransformCtx ctx) { return (ctx.inv_view * vec4(p, 1.0)).xyz; }

// Направления (включая тангенс/битангенс)
vec3 obj_to_world_dir(vec3 d, mat4 model_matrix) { return (model_matrix * vec4(d, 0.0)).xyz; }
vec3 world_to_view_dir(vec3 d, mat4 view_matrix) { return (view_matrix * vec4(d, 0.0)).xyz; }
vec3 obj_to_view_dir(vec3 d, mat4 model_matrix, mat4 view_matrix) { return world_to_view_dir(obj_to_world_dir(d, model_matrix), view_matrix); }
vec3 view_to_world_dir(vec3 d, mat4 view_matrix) { return (inverse(view_matrix) * vec4(d, 0.0)).xyz; }

// Направления (через контекст)
vec3 obj_to_world_dir_ctx(vec3 d, TransformCtx ctx) { return (ctx.model * vec4(d, 0.0)).xyz; }
vec3 world_to_view_dir_ctx(vec3 d, TransformCtx ctx) { return (ctx.view * vec4(d, 0.0)).xyz; }
vec3 obj_to_view_dir_ctx(vec3 d, TransformCtx ctx) { return world_to_view_dir_ctx(obj_to_world_dir_ctx(d, ctx), ctx); }
vec3 view_to_world_dir_ctx(vec3 d, TransformCtx ctx) { return (ctx.inv_view * vec4(d, 0.0)).xyz; }

// Нормали
vec3 obj_to_world_normal(vec3 n, mat4 model_matrix) { return normalize(model_matrix * vec4(n, 0.0)).xyz; }
vec3 world_to_view_normal(vec3 n, mat4 view_matrix) { return normalize((view_matrix * vec4(n, 0.0)).xyz); }
vec3 obj_to_view_normal(vec3 n, mat4 model_matrix, mat4 view_matrix) { return world_to_view_normal(obj_to_world_normal(n, model_matrix), view_matrix); }
vec3 view_to_world_normal(vec3 n, mat4 view_matrix) { return normalize((inverse(view_matrix) * vec4(n, 0.0)).xyz); }

// Точное преобразование нормали через normal-matrix (если доступна)
vec3 obj_to_world_normal_mn(vec3 n, mat3 model_normal_matrix) { return normalize(model_normal_matrix * n); }
vec3 obj_to_view_normal_mn(vec3 n, mat3 model_normal_matrix, mat4 view_matrix) {
    return world_to_view_normal(obj_to_world_normal_mn(n, model_normal_matrix), view_matrix);
}

// Нормали (через контекст)
vec3 obj_to_world_normal_ctx(vec3 n, TransformCtx ctx) { return normalize(ctx.model_normal * n); }
vec3 world_to_view_normal_ctx(vec3 n, TransformCtx ctx) { return normalize((ctx.view * vec4(n, 0.0)).xyz); }
vec3 obj_to_view_normal_ctx(vec3 n, TransformCtx ctx) { return world_to_view_normal_ctx(obj_to_world_normal_ctx(n, ctx), ctx); }
vec3 view_to_world_normal_ctx(vec3 n, TransformCtx ctx) { return normalize((ctx.inv_view * vec4(n, 0.0)).xyz); }

// Камера
vec3 camera_world_pos(mat4 view_matrix) { return (inverse(view_matrix) * vec4(0.0, 0.0, 0.0, 1.0)).xyz; }
vec3 camera_world_pos_ctx(TransformCtx ctx) { return (ctx.inv_view * vec4(0.0, 0.0, 0.0, 1.0)).xyz; }


// Строит ортонормированный базис из нормали и тангента. bitangent_sign = +1/-1.
mat3 build_tbn(vec3 normal, vec3 tangent, float bitangent_sign) {
    vec3 N = normalize(normal);
    vec3 T = tangent - N * dot(tangent, N);
    T = normalize(T);
    vec3 B = normalize(cross(N, T)) * bitangent_sign;
    return mat3(T, B, N);
}

// Переводит вектор из tangent space в то пространство, где заданы normal/tangent.
vec3 tangent_to_dir(vec3 v_ts, vec3 normal, vec3 tangent, float bitangent_sign) {
    mat3 TBN = build_tbn(normal, tangent, bitangent_sign);
    return normalize(TBN * v_ts);
}

// Из object space (normal/tangent) в world/view space для нормали из normal map
vec3 tangent_to_world_normal_from_obj(vec3 n_ts, vec3 obj_n, vec3 obj_t, float bitangent_sign, mat3 model_normal_matrix, mat4 model_matrix) {
    vec3 Nw = obj_to_world_normal_mn(obj_n, model_normal_matrix);
    vec3 Tw = normalize((model_matrix * vec4(obj_t, 0.0)).xyz);
    return tangent_to_dir(n_ts, Nw, Tw, bitangent_sign);
}

vec3 tangent_to_view_normal_from_obj(vec3 n_ts, vec3 obj_n, vec3 obj_t, float bitangent_sign, mat3 model_normal_matrix, mat4 model_matrix, mat4 view_matrix) {
    vec3 n_world = tangent_to_world_normal_from_obj(n_ts, obj_n, obj_t, bitangent_sign, model_normal_matrix, model_matrix);
    return world_to_view_normal(n_world, view_matrix);
}

// TBN через контекст
vec3 tangent_to_world_normal_from_obj_ctx(vec3 n_ts, TangentFrame tf, TransformCtx ctx) {
    vec3 Nw = obj_to_world_normal_ctx(tf.normal, ctx);
    vec3 Tw = normalize((ctx.model * vec4(tf.tangent, 0.0)).xyz);
    return tangent_to_dir(n_ts, Nw, Tw, tf.bitangent_sign);
}

vec3 tangent_to_view_normal_from_obj_ctx(vec3 n_ts, TangentFrame tf, TransformCtx ctx) {
    vec3 n_world = tangent_to_world_normal_from_obj_ctx(n_ts, tf, ctx);
    return world_to_view_normal_ctx(n_world, ctx);
}

vec2 world_to_screen_uv(vec3 world_pos, mat4 view_matrix, mat4 projection_matrix) {
    vec4 clip = projection_matrix * view_matrix * vec4(world_pos, 1.0);
    float w = max(abs(clip.w), 1e-6);
    vec2 ndc = clip.xy / w;           // [-1, 1]
    vec2 uv = ndc * 0.5 + 0.5;        // [0, 1],
    uv.y = 1.0 - uv.y;                // как SCREEN_UV (верх = 0)
    return uv;
}

vec2 world_to_screen_uv_ctx(vec3 world_pos, TransformCtx ctx) {
    vec4 clip = ctx.viewproj * vec4(world_pos, 1.0);
    float w = max(abs(clip.w), 1e-6);
    vec2 ndc = clip.xy / w;
    vec2 uv = ndc * 0.5 + 0.5;
    uv.y = 1.0 - uv.y;
    return uv;
}

#endif