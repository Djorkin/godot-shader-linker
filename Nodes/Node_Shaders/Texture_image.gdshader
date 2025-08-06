shader_type spatial;
render_mode
depth_draw_always,
blend_mix,
cull_back;


#include "res://addons/godot_shader_linker_(gsl)/Nodes/inc_shader/formulas/blender_coords.gdshaderinc"

group_uniforms ImageTexture;

uniform sampler2D u_image_texture;
uniform int u_interpolation : hint_enum("Linear","Closest","Cubic") = 0;
uniform int u_projection : hint_enum("Flat","Box","Sphere","Tube") = 0;
uniform float u_box_blend : hint_range(0,1,0.01) = 0.0;
uniform int u_extension : hint_enum("Repeat","Extend","Clip","Mirror") = 0;
uniform int u_color_space : hint_enum("sRGB","Non-Color") = 0;
uniform int u_alpha_mode : hint_enum("Straight","Premultiplied","ChannelPacked","None") = 0;

group_uniforms;

varying vec3 normal_vertex;

vec3 remap_square(vec3 p) {
	return p * 2.0 - 1.0;
}

// Алгоритм Blender: point_map_to_sphere
vec2 sphere_map(vec3 p) {
	float len = length(p);
	float u, v;
	if (len > 0.0) {
		if (p.x == 0.0 && p.y == 0.0) {
			u = 0.0;
		} else {
			u = (1.0 - atan(p.x, -p.y) / 3.14159265) * 0.5;
		}
		v = 1.0 - acos(clamp(p.z / len, -1.0, 1.0)) / -3.14159265;
	} else {
		u = v = 0.0;
	}
	return vec2(u, v);
}

// Алгоритм Blender: point_map_to_tube
vec2 tube_map(vec3 p) {
	float v = (p.z + 1.0) * 0.5;
	float len = length(p.xy);
	float u;
	if (len > 0.0) {
		u = (1.0 - atan(p.x / len, -p.y / len) / 3.14159265) * 0.5;
	} else {
		u = 0.0;
	}
	return vec2(u, v);
}

vec2 wrap_uv(vec2 uv) {
	if (u_extension == 1) {
		// Extend
		uv = clamp(uv, vec2(0.0), vec2(1.0));
	} else {
		// Repeat (по умолчанию)
		uv = fract(uv);
	}
	return uv;
}

float cubic_weight(float x) {
	x = abs(x);
	float w;
	if (x <= 1.0) {
		w = 1.0 - 2.0 * x * x + x * x * x;
	} else if (x < 2.0) {
		w = 4.0 - 8.0 * x + 5.0 * x * x - x * x * x;
	} else {
		w = 0.0;
	}
	return w;
}

vec4 sample_texture(vec2 uv) {
	uv = wrap_uv(uv);

	if (u_interpolation == 1) { // Closest
		vec2 size = vec2(textureSize(u_image_texture, 0));
		vec2 uv_px = (floor(uv * size) + 0.5) / size;
		vec4 tex = texture(u_image_texture, uv_px);
		if (u_color_space == 0) {
			tex.rgb = pow(tex.rgb, vec3(2.2));
		}
		return tex;
	}
	else if (u_interpolation == 2) { // Cubic (Catmull-Rom)
		vec2 texSize = vec2(textureSize(u_image_texture, 0));
		vec2 pxPos   = uv * texSize - 0.5;
		vec2 base    = floor(pxPos);
		vec2 f       = pxPos - base;

		vec4 acc = vec4(0.0);
		float total = 0.0;
		for (int j = -1; j <= 2; ++j) {
			float wy = cubic_weight(float(j) - f.y);
			for (int i = -1; i <= 2; ++i) {
				float wx = cubic_weight(float(i) - f.x);
				float w  = wx * wy;
				vec2 offset = (base + vec2(float(i), float(j)) + 0.5) / texSize;
				acc += w * texture(u_image_texture, offset);
				total += w;
			}
		}
		vec4 tex = acc / total;
		if (u_color_space == 0) {
			tex.rgb = pow(tex.rgb, vec3(2.2));
		}
		return tex;
	}
	else { // Linear (default)
		vec4 tex = texture(u_image_texture, uv);
		if (u_color_space == 0) {
			tex.rgb = pow(tex.rgb, vec3(2.2));
		}
		return tex;
	}
}

vec4 sample_image(vec3 coord, vec3 N) {
	if (u_projection == 1) {

		vec4 col_x;
		vec4 col_y;
		vec4 col_z;
		vec2 uv;

		// X-проекция (плоскость YZ)
		uv = coord.yz;
		if (N.x < 0.0) { uv.x = 1.0 - uv.x; }
		col_x = sample_texture(uv);

		// Y-проекция (плоскость XZ)
		uv = coord.xz;
		if (N.y > 0.0) { uv.x = 1.0 - uv.x; }
		col_y = sample_texture(uv);

		// Z-проекция (плоскость XY) — в Blender uv = yx
		uv = -coord.yx;
		if (N.z > 0.0) { uv.x = 1.0 - uv.x; }
		col_z = sample_texture(uv);


		vec3 abs_n = abs(N);
		abs_n /= dot(abs_n, vec3(1.0));

		float limit = 0.5 + 0.5 * u_box_blend;

		vec3 weight = abs_n / (abs_n.xyx + abs_n.yzz);
		weight = clamp((weight - 0.5 * (1.0 - u_box_blend)) / max(u_box_blend, 1e-8), 0.0, 1.0);

		if (abs_n.z < (1.0 - limit) * (abs_n.y + abs_n.x)) {
			weight.z = 0.0;
			weight.y = 1.0 - weight.x;
		} else if (abs_n.x < (1.0 - limit) * (abs_n.y + abs_n.z)) {
			weight.x = 0.0;
			weight.z = 1.0 - weight.y;
		} else if (abs_n.y < (1.0 - limit) * (abs_n.x + abs_n.z)) {
			weight.y = 0.0;
			weight.x = 1.0 - weight.z;
		} else {
			weight = ((2.0 - limit) * abs_n + (limit - 1.0)) / max(u_box_blend, 1e-8);
		}

		vec4 color = weight.x * col_x + weight.y * col_y + weight.z * col_z;
		return color;
	}
	else if (u_projection == 2) { // Sphere
		vec3 p = remap_square(coord);
		vec2 uv = sphere_map(p);
		return sample_texture(uv);
	}
	else if (u_projection == 3) { // Tube
		vec3 p = remap_square(coord);
		vec2 uv = tube_map(p);
		return sample_texture(uv);
	}
	else { // Flat
		return sample_texture(coord.xy);
	}
}

void vertex() {
	normal_vertex = blender_to_godot_normal(NORMAL);
}

void fragment() {
	vec4 tex = sample_image(vec3(UV, 0.0), normal_vertex);
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
}
