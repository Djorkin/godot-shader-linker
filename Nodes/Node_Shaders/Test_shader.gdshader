//https://github.com/blender/blender/blob/main/source/blender/gpu/shaders/material/gpu_shader_material_principled.glsl
shader_type spatial;
render_mode
depth_draw_always,
blend_mix,
cull_back;

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
group_uniforms;

// Specular параметры
group_uniforms BSDF.Specular;
uniform float u_specular_ior_level : hint_range(0,1) = 0.5;
uniform vec4 u_specular_tint : source_color = vec4(1.0);
group_uniforms;

group_uniforms BSDF.Transmission;
uniform float u_transmission : hint_range(0,1) = 0.0;
group_uniforms;

// Параметры покрытия (coat)
group_uniforms BSDF.Coat;
uniform float u_coat_weight : hint_range(0,1) = 0.0;
uniform float u_coat_roughness : hint_range(0,1) = 0.0;
uniform float u_coat_ior : hint_range(1.0, 5.0) = 1.5;
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
uniform float u_ssr_scale : hint_range(0,0.5) = 0.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;
group_uniforms;

varying vec3 spec;

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
	Material mat = Material(vec3(0.0),0.0,0.0,0.0,0.0,0.0,vec3(0.0),vec3(0.0));

	base_color = max(base_color, vec4(0.0));
	vec4 clamped_base_color = min(base_color, vec4(1.0));


	N = normalize(N);
	CN = normalize(CN);
	float NV = dot(N, V);


	// Альфа компонент
	mat.alpha = alpha;


	//// Sheen компонент
	//vec3 sheen_data_color = vec3(0.0);
	//if (sheen_weight > 0.0) {
	//vec3 sheen_color = sheen_weight * sheen_tint.rgb * principled_sheen(NV, sheen_roughness);
	//sheen_data_color = weight * sheen_color;
//
	//weight *= max((1.0 - reduce_max(sheen_color)), 0.0);
	//}


	//// Coat  компонент
	//if (coat_weight > 0.0) {
		//float coat_NV = dot(CN, V);
		//float reflectance = bsdf(coat_NV, coat_roughness, coat_ior, false);
//
		//ClosureReflection coat_data;
		//coat_data.N = CN;
		//coat_data.roughness = coat_roughness;
		//coat_data.color = vec3(1.0);
		//coat_data.weight = weight * coat_weight * reflectance;
		//closure_eval(coat_data, mat);
//
		//weight *= max((1.0 - reflectance * coat_weight), 0.0);
//
		//if (!all(equal(coat_tint.rgb, vec3(1.0)))) {
			//float coat_neta = 1.0 / coat_ior;
			//float NT = sqrt_fast(1.0 - coat_neta * coat_neta * (1.0 - NV * NV));
			//coat_tint.rgb = mix(vec3(1.0), pow(coat_tint.rgb, vec3(1.0 / NT)), saturate(coat_weight));
			//}
		//}
		//else {
		//coat_tint.rgb = vec3(1.0);
	//}


	// emission компонент
	mat.emission = coat_tint.rgb * emission.rgb * emission_strength;


  /* Metallic component */
	vec3 F0_d = vec3(F0_from_ior(ior));
	vec3 F = mix(F0_d, specular_tint.rgb, metallic);
	vec3 reflection_color = weight * metallic * F;

	weight *= max((1.0 - metallic), 0.0);


  ///* Transmission component */
	//vec3 transmission = vec3(0.0);
	//if (transmission_weight > 0.0) {
		//vec3 refr_dir = refract(-V, N, 1.0 / ior);
		//vec2 refr_uv = screen_uv + refr_dir.xy * u_ssr_scale;
		//vec3 screen_color = textureLod(SCREEN_TEXTURE, refr_uv, roughness * 8.0).rgb;
//
		//vec3 baseF0 = vec3(F0_from_ior(u_ior));
		//vec3 F = FresnelSchlick(NV, baseF0);
//
		//transmission = screen_color * (1.0 - F) * transmission_weight;
//
		//weight *= max((1.0 - transmission_weight), 0.0);
	//}


	/* Specular component */
	float eta = ior;
	float f0 = F0_from_ior(eta);
	if (specular_ior_level != 0.5) {
	    f0 *= 2.0 * specular_ior_level;
	    eta = ior_from_F0(f0);
	    if (ior < 1.0) {
	    eta = 1.0 / eta;
	    }
	}

	vec3 F0 = vec3(f0) * base_color.rgb;
	F0 = clamp(F0, vec3(0.0), vec3(1.0));


	mat.albedo = coat_tint.rgb;
	mat.metallic = metallic;
	mat.roughness = roughness;
	mat.ior = ior;
	mat.specular = reflection_color;
	mat.specular_level = specular_ior_level;


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



	ALBEDO = result.albedo;
	ROUGHNESS = result.roughness;
	METALLIC = result.metallic;
	ALPHA = result.alpha;
	SPECULAR = result.specular_level;
	EMISSION = result.emission;
	spec = result.specular;
}

void light(){
	DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI;
	SPECULAR_LIGHT += SPECULAR_LIGHT * (spec - vec3(1.0) * (1.0 - u_roughness)) * u_specular_ior_level;
}
