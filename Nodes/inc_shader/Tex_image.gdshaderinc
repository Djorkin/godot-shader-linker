/* SPDX-FileCopyrightText: 2019-2023 Blender Authors
 * SPDX-FileCopyrightText: 2025 D.Jorkin
 *
 * Adapted from Blender's gpu_shader_material_tex_image.glsl
 * https://raw.githubusercontent.com/blender/blender/main/source/blender/gpu/shaders/material/gpu_shader_material_tex_image.glsl
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

// В будущем этот файл будет рефакторен для избавления от ветвления в шейдере.

#ifdef INCLUDE_WRAPPER
	vec3 remap_square(vec3 p) {
	    return  p * 2.0 - 1.0;
	}

	// Algorithm from Blender: point_map_to_sphere
	vec2 sphere_map(vec3 p) {
	    float len = length(p);
	    float u, v;
	    if (len > 0.0) {
	        if (p.x == 0.0 && p.y == 0.0) {
	            u = 0.0;
	        } else {
	            u = (1.0 - atan(p.x, p.y) / PI) / 2.0; 
	        }
	        v = 1.0 - acos(p.z / len) / PI;
	    } else {
	        v = u = 0.0;
	    }
	    return vec2(u, -v);
	}

	// Algorithm from Blender: point_map_to_tube
	vec2 tube_map(vec3 p) {
	    float v = (p.z + 1.0) * 0.5;
	    float len = length(p.xy);
	    float u;
	    if (len > 0.0) {
	        u = (1.0 - atan(p.x / len, p.y / len) / PI) / 2.0;
	    } else {
	        u = 0.0;
	    }
	    return vec2(u, -v);
	}

/* 	float cubic_weight(float x) {
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
	} */

	vec2 wrap_uv(vec2 uv, int extension) {
	    if (extension == 1) {
	        // Extend
	        uv = clamp(uv, vec2(0.0), vec2(1.0));
	    } else {
	        // Repeat (default)
	        uv = fract(uv);
	    }
	    return uv;
	}

	vec4 sample_texture(vec2 uv, sampler2D tex, Tex_img_params p)
	{
	    vec2 uvw = wrap_uv(uv, p.extension);

	    if (p.interpolation == 1) { // Closest
	        vec2 size = vec2(textureSize(tex, 0));
	        vec2 uv_px = (floor(uvw * size) + 0.5) / size;
	        vec4 outc = texture(tex, uv_px);
	        outc.rgb = mix(outc.rgb, color_srgb_to_scene_linear(outc.rgb), 1.0 - step(0.5, float(p.color_space))); // Временное решение.
	        return outc;
	    }
/* 	    else if (p.interpolation == 2) { // Cubic (Catmull-Rom)
	        vec2 texSize = vec2(textureSize(tex, 0));
	        vec2 pxPos   = uvw * texSize - 0.5;
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
	                acc += w * texture(tex, offset);
	                total += w;
	            }
	        }
	        vec4 outc = acc / total;
	        if (p.color_space == 0) {
	            outc.rgb = pow(outc.rgb, vec3(2.2));
	        }
	        return outc;
	    } */
	    else { // Linear (default)
	        vec2 dudx = dFdx(uv);
	        vec2 dudy = dFdy(uv);
	        if (p.extension != 1) {
	            dudx.x = fract(dudx.x + 0.5) - 0.5;
	            dudy.x = fract(dudy.x + 0.5) - 0.5;
	        }
	        vec4 outc = textureGrad(tex, uvw, dudx, dudy);
	        outc.rgb = mix(outc.rgb, color_srgb_to_scene_linear(outc.rgb), 1.0 - step(0.5, float(p.color_space))); // Временное решение. TODO: Заранее генерировать в GSL нужную функцию с выбранными параметрами.
	        return outc;
	    }
	}

/* 	void point_texco_clamp(vec3 v, sampler2D ima, out vec3 vout)
	{
	    vec2 half_texel = 0.5 / vec2(textureSize(ima, 0));
	    vout = clamp(v, half_texel.xyy, 1.0 - half_texel.xyy);
		vout = v;
	} */

	vec4 _sample_image( vec3 coord, vec3 N, sampler2D tex, Tex_img_params params){
	    if (params.projection == 1) {
			
	        vec4 col_x;
	        vec4 col_y;
	        vec4 col_z;
	        vec2 uv;

	        // X-projection (YZ plane)
	        uv = 1.0 - coord.yz;
	        if (N.x > 0.0) { uv.x = 1.0 - uv.x; }
	        col_x = sample_texture(uv, tex, params);

	        // Y-projection (XZ plane)
	        uv = 1.0 - coord.xz;
	        if (N.y < 0.0) { uv.x = 1.0 - uv.x; }
	        col_y = sample_texture(uv, tex, params);

	        // Z-projection (YX plane)
	        uv = 1.0 - coord.yx;
	        if (N.z < 0.0) { uv.x = 1.0 - uv.x; }
	        col_z = sample_texture(uv, tex, params);


	        vec3 abs_n = abs(N);
	        abs_n /= dot(abs_n, vec3(1.0));

	        float limit = 0.5 + 0.5 * params.box_blend;

	        vec3 weight = abs_n / (abs_n.xyx + abs_n.yzz);
	        weight = clamp((weight - 0.5 * (1.0 - params.box_blend)) / max(params.box_blend, 1e-8), 0.0, 1.0);

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
	            weight = ((2.0 - limit) * abs_n + (limit - 1.0)) / max(params.box_blend, 1e-8);
	        }

	        vec4 color = weight.x * col_x + weight.y * col_y + weight.z * col_z;
	        return color;
	    }
	    else if (params.projection == 2) { // Sphere
	        vec3 p = remap_square(coord);
	        vec2 uv = sphere_map(p);
	        return sample_texture(uv, tex, params);
	    }
	    else if (params.projection == 3) { // Tube
	        vec3 p = remap_square(coord);
	        vec2 uv = tube_map(p);
	        return sample_texture(uv, tex, params);
	    }
	    else { // Flat
	        return sample_texture(flip_uv(coord.xy), tex, params);
	    }
	}
#endif
