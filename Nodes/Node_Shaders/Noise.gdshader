shader_type spatial;

#define SHARED_DEFINE
#define NOISE_NONE_CONNECTED
#define NOISE_DIMENSIONS 3
#define FRACTAL_TYPE 4


#include "res://addons/godot_shader_linker_(gsl)/Nodes/inc_shader/formulas/blender_coords.gdshaderinc"
#include "res://addons/godot_shader_linker_(gsl)/Nodes/inc_shader/formulas/struct_noise_params.gdshaderinc"
#include "res://addons/godot_shader_linker_(gsl)/Nodes/inc_shader/blender_hash.gdshaderinc"
#include "res://addons/godot_shader_linker_(gsl)/Nodes/inc_shader/noise_base.gdshaderinc"
#include "res://addons/godot_shader_linker_(gsl)/Nodes/inc_shader/fractal_noise.gdshaderinc"
#include "res://addons/godot_shader_linker_(gsl)/Nodes/inc_shader/noise_texture.gdshaderinc"


varying vec3 gen_vec;


uniform int Dimensions : hint_enum("1D", "2D", "3D", "4D") = 2;
uniform int FractalType : hint_enum("MULTIFRACTAL", "RIDGED MULTIFRACTAL", "HYBRID MULTIFRACTAL", "FBM", "HETERO TERRAIN") = 3;



#if FRACTAL_TYPE == 3
    uniform bool Normalize = true;
#endif

#if NOISE_DIMENSIONS == 0 || NOISE_DIMENSIONS == 3
    uniform float W : hint_range(-1000.0, 1000.0) = 0.0;
#endif

uniform float Scale : hint_range(-1000.0, 1000.0) = 5.0;
uniform float Detail : hint_range(0.0, 15.0) = 2.0;
uniform float Roughness : hint_range(0.0, 1.0) = 0.5;
uniform float Lacunarity : hint_range(0.0, 1000.0) = 2.0;

#if FRACTAL_TYPE == 1 || FRACTAL_TYPE == 2 || FRACTAL_TYPE == 4
    uniform float Offset : hint_range(-1000.0, 1000.0) = 0.0;
#endif

#if FRACTAL_TYPE == 1 || FRACTAL_TYPE == 2
    uniform float Gain : hint_range(-1000.0, 1000.0) = 0.5;
#endif

uniform float Distortion : hint_range(-1000.0, 1000.0) = 0.0;

void vertex() {
    gen_vec = apply_generated(blender_to_godot(VERTEX));
}

void fragment() {
    // Подготовка структуры параметров
    NoiseParams params;

    #if NOISE_DIMENSIONS == 0 || NOISE_DIMENSIONS == 3
        params.w = W;
    #endif

    params.scale = Scale;
    params.detail = Detail;
    params.roughness = Roughness;
    params.lacunarity = Lacunarity;
    #if FRACTAL_TYPE == 1 || FRACTAL_TYPE == 2 || FRACTAL_TYPE == 4
        params.offset = Offset;
    #endif

    params.distortion = Distortion;
    #if FRACTAL_TYPE == 1 || FRACTAL_TYPE == 2
        params.gain = Gain;
    #endif
    #if FRACTAL_TYPE == 3
        params.normalize = Normalize;
    #endif

    // Вычисление шума
    float value;
    vec4 color;
    noise_texture(gen_vec, params, value, color);
    
    // Визуализация результатов
    ALBEDO = vec3(value);        

}