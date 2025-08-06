shader_type spatial;
render_mode
depth_draw_always,
blend_mix,
cull_back,
world_vertex_coords;
#define SHARED_DEFINE
#include "res://addons/godot_shader_linker_(gsl)/Nodes/inc_shader/formulas/blender_coords.gdshaderinc"

//uniform sampler2D test_tex_height;

uniform bool u_invert = false;
uniform float u_strength : hint_range(0.0, 1.0) = 0.0;
uniform float u_dist : hint_range(0.0, 1000.0) = 1.0;
uniform float u_filter_width : hint_range(0.0, 10.0) = 0.01;
uniform float u_height = 1.0;
uniform vec3 u_normal = vec3(0.0);



varying vec3 v_nrm_world;
varying vec3 v_vert;


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


void vertex() {
	v_nrm_world = NORMAL * ROT_MATRIX_Y_TO_Z;
	v_vert = VERTEX.xzy;
}

void fragment() {
	//float height_val = texture(test_tex_height,UV).r;
    float height_val = u_height;
	vec3 df = differentiate_texco(vec3(u_height));
	vec2 height_xy = df.xy;
	float pixel = max(1e-4, length(dFdx(SCREEN_UV)) + length(dFdy(SCREEN_UV)));
	float fw = u_filter_width / pixel / 10.0;
	vec3 bumped = node_bump(u_strength, u_dist, fw, height_val,
                            v_nrm_world, height_xy,
                            (u_invert ? -1.0 : 1.0),
                            FRONT_FACING, v_vert);


	ALBEDO = bumped;

}
