shader_type spatial;
render_mode depth_draw_always, blend_mix, depth_prepass_alpha, unshaded;

#define SHARED_DEFINE
#define MIX_TYPE 0




#include "res://addons/godot_shader_linker_(gsl)/Nodes/inc_shader/color_conversions.gdshaderinc"
#include "res://addons/godot_shader_linker_(gsl)/Nodes/inc_shader/mix_modes.gdshaderinc"
#include "res://addons/godot_shader_linker_(gsl)/Nodes/inc_shader/mix_functions.gdshaderinc"


uniform int mix_data_type : hint_enum("Float", "Vector", "Color") = 2;

#if MIX_TYPE == 2
    uniform int mix_blend_type : hint_enum(
        "Mix",          // 0
        "Darken",       // 1
        "Multiply",     // 2
        "Color Burn",   // 3
        "Lighten",      // 4
        "Screen",       // 5
        "Color Dodge",  // 6
        "Add",          // 7
        "Overlay",      // 8
        "Soft Light",   // 9
        "Linear Light", // 10
        "Difference",   // 11
        "Exclusion",    // 12
        "Subtract",     // 13
        "Divide",       // 14
        "Hue",          // 15
        "Saturation",   // 16
        "Color",        // 17
        "Value"         // 18
    ) = 0;

    uniform bool mix_clamp_result = false;
    uniform bool mix_clamp_factor = false;
    uniform float mix_factor : hint_range(0,1) = 0.5;
    uniform vec4 a_data : source_color = vec4(0.5, 0.5, 0.5, 1.0);
    uniform vec4 b_data : source_color = vec4(0.5, 0.5, 0.5, 1.0);
#endif

#if MIX_TYPE == 1 
    uniform int mix_vector_factor_mode : hint_enum("Uniform", "Non-Uniform") = 0;
    uniform bool mix_clamp_factor = false;
    #if MIX_VECTOR_TYPE == 0
        uniform float mix_factor : hint_range(0,1) = 0.5;
    #else
        uniform vec3 mix_factor = vec3(0.5);
    #endif
    uniform vec3 a_data_vec = vec3(0.5, 0.5, 0.5);
    uniform vec3 b_data_vec = vec3(0.5, 0.5, 0.5);
#endif


#if MIX_TYPE == 0
    uniform bool mix_clamp_factor = false;
    uniform float mix_factor : hint_range(0,1) = 0.5;
    uniform float a_data_f = 0.0;
    uniform float b_data_f = 0.0;
#endif





void vertex() {}

void fragment() {

    float result = mix_float(mix_clamp_factor, mix_factor, a_data_f, b_data_f);
    ALBEDO = vec3(result);


}