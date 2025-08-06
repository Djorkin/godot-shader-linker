//https://github.com/blender/blender/blob/main/source/blender/gpu/shaders/material/gpu_shader_material_principled.glsl

shader_type spatial;
render_mode
depth_draw_always,
blend_mix,
cull_back,
specular_schlick_ggx;

#include "res://addons/godot_shader_linker_(gsl)/Nodes/inc_shader/formulas/physical.gdshaderinc"
#include "res://addons/godot_shader_linker_(gsl)/Nodes/inc_shader/formulas/math.gdshaderinc"
#include "res://addons/godot_shader_linker_(gsl)/Nodes/inc_shader/formulas/closure.gdshaderinc"


group_uniforms BSDF;
uniform vec4 u_base_color : source_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform float u_metallic : hint_range(0,1) = 0.0;
uniform float u_roughness : hint_range(0,1) = 0.5;
uniform float u_ior : hint_range(1.0, 100.0) = 1.45;
uniform float u_alpha : hint_range(0,1) = 1.0;
uniform sampler2D u_normal : hint_normal;
group_uniforms;

group_uniforms BSDF.Diffuse;
group_uniforms;

group_uniforms BSDF.SSS;
uniform float u_sss_weight : hint_range(0,1) = 0.0;
uniform float u_sss_radius : hint_range(0,1) = 0.0;
uniform vec4 u_sss_tint : source_color = vec4(1.0);
uniform float u_sss_scale : hint_range(0,1) = 0.05;
group_uniforms;

// Specular параметры
group_uniforms BSDF.Specular;
uniform float u_specular_ior_level : hint_range(0,1) = 0.5;
uniform vec4 u_specular_tint : source_color = vec4(1.0);
group_uniforms;

group_uniforms BSDF.Transmission;
uniform float u_transmission : hint_range(0,1) = 0.0;
//uniform float u_absorption_strength : hint_range(0,20) = 0.0;
//uniform vec4 u_absorption_color : source_color = vec4(1.0);
group_uniforms;

// Параметры покрытия (coat)
group_uniforms BSDF.Coat;
uniform float u_coat_weight : hint_range(0,1) = 0.0;
uniform float u_coat_roughness : hint_range(0,1) = 0.0;
uniform float u_coat_ior : hint_range(1.0, 4.0) = 1.5;
uniform vec4 u_coat_tint : source_color = vec4(1.0);
group_uniforms;

// Sheen параметры
group_uniforms BSDF.Sheen;
uniform float u_sheen_weight : hint_range(0,1) = 0.0;
uniform float u_sheen_roughness : hint_range(0,1) = 0.0;
uniform vec4 u_sheen_tint : source_color = vec4(1.0);
group_uniforms;

// emission параметры
group_uniforms BSDF.Emission;
uniform vec4 u_emission : source_color = vec4(1.0);
uniform float u_emission_strength : hint_range(0,100) = 0.0;
group_uniforms;

group_uniforms BSDF.Thin_Film;
group_uniforms;

group_uniforms Surface_Render_Settings;
uniform bool u_do_multiscatter = true;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;
uniform int render_surface_type : hint_enum("Slab","Sphere") = 0;
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
	Material mat = Material(vec3(0.0),0.0,0.0,0.0,0.0,vec3(0.0),vec3(0.0),0.0,0.0);
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

	// Альфа компонент
	mat.alpha = alpha;


	// Sheen компонент
	vec3 sheen_data_color = vec3(0.0);
	if (sheen_weight > 0.0) {
		vec3 sheen_color = sheen_weight * sheen_tint.rgb * principled_sheen(NV, sheen_roughness);
		sheen_data_color = weight * sheen_color;

		weight *= max((1.0 - reduce_max(sheen_color)), 0.0);
	}


	/* Coat компонент: отражение отдаём встроенному CLEARCOAT, нужно переписывать реализацию.
	   Оставляем только вычисление цветного лака (Tint). */
	if (coat_weight > 0.0) {
		if (!all(equal(coat_tint.rgb, vec3(1.0)))) {
			float coat_eta = 1.0 / coat_ior;
			float NT = sqrt_fast(max(1.0 - coat_eta * coat_eta * (1.0 - NV * NV), 0.0));
			coat_tint.rgb = mix(vec3(1.0), pow(coat_tint.rgb, vec3(1.0 / NT)), saturate(coat_weight));
		}
	} else {
		coat_tint.rgb = vec3(1.0);
	}


	// emission компонент
	mat.emission = coat_tint.rgb * emission.rgb * emission_strength;

	// IOR адаптация
	float ior_power = clamp((ior - 1.0) / 99.0, 0.0, 1.0);
	float metallic_boost = ior_power * specular_ior_level * 2.0;
	float final_metallic = clamp(metallic + metallic_boost, 0.0, 1.0);

    	// Transmission component
	vec3 transmission = vec3(0.0);
	float absorption_strength = 1.0;
	vec3 absorption_color = vec3(0.0);
	float tr_weight = transmission_weight * (1.0 - final_metallic);
	if (tr_weight > 0.0) {
		vec3 refr_dir = refract(-V, N, 1.0 / ior);

		// Автоматический расчёт толщины как в Blender EEVEE
		float thickness = 0.1; // базовая толщина
		vec2 refr_uv = screen_uv; // по умолчанию без искажений (Slab)

		if (render_surface_type == 1) { // Sphere
			// Для сферы: толщина зависит от угла обзора + искажения
			float cos_theta = abs(dot(N, V));
			thickness = 0.1 / max(cos_theta, 0.1);
			refr_uv = screen_uv + refr_dir.xy * thickness;
		}

		// Семплирование без смещений, но с защитой выхода за пределы
		float lod = roughness * 8.0;
		vec2 uv = clamp(refr_uv, vec2(0.0), vec2(1.0));
		vec3 screen_color = textureLod(SCREEN_TEXTURE, uv, lod).rgb;

		// Добавляем окрашивание преломлённого цвета базовым цветом (эффект цветного стекла)
		screen_color *= clamped_base_color.rgb;

		// Абсорбция (Beer-Lambert)
		float attenuation = exp(-absorption_strength * thickness);
		vec3  absorption = mix(vec3(1.0), absorption_color, 1.0 - attenuation);
		screen_color *= absorption;

		vec3 baseF0 = vec3(F0_from_ior(ior));
		vec3 F = FresnelSchlick(NV, baseF0);

		float one_minus_F = max(1.0 - reduce_max(F), 0.001);   // не даём упасть до нуля
		transmission = screen_color * one_minus_F * tr_weight;

		weight *= max((1.0 - tr_weight), 0.0);
	}

	// Гарантируем, что вес не уходит за пределы после всех модификаций
	weight = saturate(weight);

	/* Blender-accurate Specular component */
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
	mat.emission += transmission;        // не участвует в BRDF, только как готовый цвет
	mat.metallic = final_metallic;
	mat.roughness = roughness + 0.013;
	float spec_level = saturate(ior_to_specular_level(ior) * specular_ior_level);
	mat.specular_level = spec_level;
	return mat;
}

void fragment() {
	Material result = bsdf_mini(u_base_color,
	            u_metallic,
	            u_roughness,
	            u_ior,
	            u_alpha,
	            NORMAL,
	            normalize(VIEW),
	            1.0,
	            u_specular_ior_level,
	            u_specular_tint,
	            u_transmission,
	            u_coat_weight,
	            u_coat_roughness,
	            u_coat_ior,
	            u_coat_tint,
	            NORMAL,
	            u_sheen_weight,
	            u_sheen_roughness,
	            u_sheen_tint,
	            u_emission,
	            u_emission_strength,
	            u_do_multiscatter,
				SCREEN_UV);

	// Базовые параметры
	ALBEDO = result.albedo;
	ROUGHNESS = result.roughness;
	METALLIC = result.metallic;
	ALPHA = result.alpha;
	SPECULAR = result.specular_level;
	EMISSION = result.emission;
	CLEARCOAT = u_coat_weight;
	CLEARCOAT_ROUGHNESS = u_coat_roughness;
	//SSS_STRENGTH = u_sss_weight;
	//SSS_TRANSMITTANCE_BOOST = u_sss_radius;
	//SSS_TRANSMITTANCE_COLOR = u_sss_tint;
	//SSS_TRANSMITTANCE_DEPTH = u_sss_scale;
}
