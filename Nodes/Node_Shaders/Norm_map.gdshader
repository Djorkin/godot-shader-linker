shader_type spatial;
render_mode depth_draw_always, blend_mix, world_vertex_coords;

//#define DEBUG_ALBEDO


//#include "res://addons/godot_shader_linker_(gsl)/Nodes/inc_shader/formulas/blender_coords.gdshaderinc"

uniform sampler2D test_tex_norm : hint_normal;
uniform float strength : hint_range(0.0, 10.0) = 1.0;

vec3 get_normal_map(vec3 color, float s, vec3 normal, vec3 tangent) {
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

void fragment() {
	vec3 color = texture(test_tex_norm, UV).rgb;
	vec3 out_n = get_normal_map(vec3(0.5,0.5,1.0), strength, NORMAL, TANGENT);
	NORMAL = out_n;
	ALBEDO = out_n;
}
