const mat4 BLENDER_TO_GODOT = mat4(
    vec4(1.0, 0.0, 0.0, 0.0),
    vec4(0.0, 0.0, 1.0, 0.0),
    vec4(0.0, 1.0, 0.0, 0.0),
    vec4(0.0, 0.0, 0.0, 1.0)
);

const vec3 BLENDER_UP = vec3(0.0, 0.0, 1.0);

vec3 blender_to_godot(vec3 blender_pos) {
    return (BLENDER_TO_GODOT * vec4(blender_pos, 1.0)).xyz;
}

vec3 blender_to_godot_normal(vec3 blender_normal) {
    return normalize((BLENDER_TO_GODOT * vec4(blender_normal, 0.0)).xyz);
}
