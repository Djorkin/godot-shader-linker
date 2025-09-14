/* SPDX-FileCopyrightText: 2025 D.Jorkin
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Portions adapted from Blender GPU shaders to ensure behavior parity:
 *  - source/blender/gpu/shaders/material/gpu_shader_material_principled.glsl
 *    https://github.com/blender/blender/blob/main/source/blender/gpu/shaders/material/gpu_shader_material_principled.glsl
 * Copyright (c) Blender Authors, licensed under GPL-2.0-or-later.
 */

#ifdef INCLUDE_WRAPPER

	group_uniforms Surface_Render_Settings;
	uniform bool u_do_multiscatter = true;
	#ifdef TRANSMISSION
		uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;
		uniform int render_surface_type : hint_enum("Slab","Sphere") = 0;
	#endif
	group_uniforms;


	Material bsdf_mini(vec4 base_color,
					float metallic,
					float roughness,
					float ior,
					float alpha,
					vec3 N,
					vec3 V,
					float weight,
					float specular_ior_level,
					vec4 specular_tint,
					float transmission_weight,
					float coat_weight,
					float coat_roughness,
					float coat_ior,
					vec4 coat_tint,
					vec3 CN,
					float sheen_weight,
					float sheen_roughness,
					vec4 sheen_tint,
					vec4 emission,
					float emission_strength,
					bool do_multiscatter,
					vec2 screen_uv){

		// init
		Material mat = Material(vec3(0.0),0.0,0.0,0.0,0.0,vec3(0.0),vec3(0.0),vec3(0.0),0.0,0.0);

		// Parameter clamping (matching Blender EEVEE)
		metallic           	= saturate(metallic);
		roughness          	= saturate(roughness);
		ior                	= max(ior, 1e-5);
		alpha              	= saturate(alpha);
		specular_ior_level 	= max(specular_ior_level, 0.0);
		specular_tint      	= max(specular_tint, vec4(0.0));
		transmission_weight	= saturate(transmission_weight);
		coat_weight        	= max(coat_weight, 0.0);
		coat_roughness     	= saturate(coat_roughness);
		coat_ior           	= max(coat_ior, 1.0);
		coat_tint          	= max(coat_tint, vec4(0.0));
		sheen_weight       	= max(sheen_weight, 0.0);
		sheen_roughness    	= saturate(sheen_roughness);
		sheen_tint         	= max(sheen_tint, vec4(0.0));

		base_color = max(base_color, vec4(0.0));
		vec4 clamped_base_color = min(base_color, vec4(1.0));


		N = normalize(N);
		CN = normalize(CN);
		float NV = dot(N, V);

		// Alpha component
		#ifdef ALPHA_TRANSFER
			mat.alpha = alpha;
		#endif


		// Sheen component
		vec3 sheen_data_color = vec3(0.0);
		if (sheen_weight > 0.0) {
			vec3 sheen_color = sheen_weight * sheen_tint.rgb * principled_sheen(NV, sheen_roughness);
			sheen_data_color = weight * sheen_color;

			weight *= max((1.0 - reduce_max(sheen_color)), 0.0);
		}


		// Coat component: reflection goes to built-in CLEARCOAT, need to rewrite the implementation.
		// We only keep the calculation of the colored lacquer (Tint).
		if (coat_weight > 0.0) {
			if (!all(equal(coat_tint.rgb, vec3(1.0)))) {
				float coat_eta = 1.0 / coat_ior;
				float NT = sqrt_fast(max(1.0 - coat_eta * coat_eta * (1.0 - NV * NV), 0.0));
				coat_tint.rgb = mix(vec3(1.0), pow(coat_tint.rgb, vec3(1.0 / NT)), saturate(coat_weight));
			}
		} else {
			coat_tint.rgb = vec3(1.0);
		}


		// emission component
		mat.emission = coat_tint.rgb * emission.rgb * emission_strength;

		// IOR adaptation
		float ior_power = clamp((ior - 1.0) / 99.0, 0.0, 1.0);
		float metallic_boost = ior_power * specular_ior_level * 2.0;
		float final_metallic = clamp(metallic + metallic_boost, 0.0, 1.0);

		// Transmission component
		vec3 transmission = vec3(0.0);
		float absorption_strength = 1.0;
		vec3 absorption_color = vec3(0.0);
		float tr_weight = transmission_weight * (1.0 - final_metallic);
		#ifdef TRANSMISSION
			if (tr_weight > 0.0) {
				vec3 refr_dir = refract(-V, N, 1.0 / ior);

				float thickness = 0.01; 
				vec2 refr_uv = screen_uv; 
			
				if (render_surface_type == 1) {
					float cos_theta = abs(dot(N, V));
					thickness = 0.1 / max(cos_theta, 0.1);
					refr_uv = screen_uv + refr_dir.xy * thickness;
				}

				float lod = clamp(pow(roughness, 2.0) * 16.0, 0.0, 8.0);
				vec2 uv = clamp(refr_uv, vec2(0.0), vec2(1.0));
				vec3 screen_color = textureLod(SCREEN_TEXTURE, uv, lod).rgb;

				screen_color *= clamped_base_color.rgb;

				// Absorption (Beer-Lambert)
				float attenuation = exp(-absorption_strength * thickness);
				vec3  absorption = mix(vec3(1.0), absorption_color, 1.0 - attenuation);
				screen_color *= absorption;

				vec3 baseF0 = vec3(F0_from_ior(ior));
				vec3 F = FresnelSchlick(NV, baseF0);

				float one_minus_F = max(1.0 - reduce_max(F), 0.001); 
				transmission = screen_color * one_minus_F * tr_weight;

				weight *= max((1.0 - tr_weight), 0.0);
			}
		#endif
		weight = saturate(weight); 

		//Specular component
		float f0 = F0_from_ior(ior);

		if (specular_ior_level != 0.5) {
			f0 *= 2.0 * specular_ior_level;
			float new_ior = ior_from_F0(f0);
			if (ior < 1.0) {
				new_ior = 1.0 / new_ior;
			}
			ior = new_ior;
		}

		mat.albedo = weight * base_color.rgb * coat_tint.rgb;
		mat.albedo += sheen_data_color;
		mat.emission += transmission;        
		mat.metallic = final_metallic;
		mat.normal = N;
		mat.roughness = roughness + 0.013; 
		mat.specular_level = saturate(ior_to_specular_level(ior) * specular_ior_level);
		mat.coat_weight = coat_weight;
		mat.coat_roughness = coat_roughness; 

		return mat;
	}

#endif
