# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name NoiseTextureModule
extends ShaderModule


enum DimensionType { D1, D2, D3, D4 }
@export_enum("1D", "2D", "3D", "4D") var dimensions: int = DimensionType.D3

enum FractalType {
    MULTIFRACTAL,
    RIDGED_MULTIFRACTAL,
    HYBRID_MULTIFRACTAL,
    FBM,
    HETERO_TERRAIN
}
@export_enum("Multifractal", "Ridged Multifractal", "Hybrid Multifractal", "fBm", "Hetero Terrain") var fractal_type: int = FractalType.FBM

@export var normalize: bool = true
@export_range(-1000, 1000, 0.1) var w_param: float = 0.0
@export_range(-1000, 1000, 0.1) var scale: float = 5.0
@export_range(0, 15, 0.1) var detail: float = 2.0
@export_range(0, 1, 0.01) var roughness: float = 0.5
@export_range(0, 1000, 0.1) var lacunarity: float = 2.0
@export_range(-1000, 1000, 0.1) var offset: float = 0.0
@export_range(0, 1000, 0.1) var gain: float = 0.5
@export_range(-1000, 1000, 0.1) var distortion: float = 0.0


func _init() -> void:
    super._init()
    module_name = "Noise Texture"

    input_sockets = [
        InputSocket.new("Vector", InputSocket.SocketType.VEC3, Vector3.ZERO),
        InputSocket.new("W", InputSocket.SocketType.FLOAT, 0.0),
        InputSocket.new("Scale", InputSocket.SocketType.FLOAT, 5.0),
        InputSocket.new("Detail", InputSocket.SocketType.FLOAT, 2.0),
        InputSocket.new("Roughness", InputSocket.SocketType.FLOAT, 0.5),
        InputSocket.new("Lacunarity", InputSocket.SocketType.FLOAT, 2.0),
        InputSocket.new("Offset", InputSocket.SocketType.FLOAT, 0.0),
        InputSocket.new("Gain", InputSocket.SocketType.FLOAT, 0.5),
        InputSocket.new("Distortion", InputSocket.SocketType.FLOAT, 0.0)
    ]

    output_sockets = [
        OutputSocket.new("Value", OutputSocket.SocketType.FLOAT),
        OutputSocket.new("Color", OutputSocket.SocketType.VEC4)
    ]

    for socket in output_sockets:
        socket.set_parent_module(self)


func get_include_files() -> Array[String]:
    return [
        PATHS.INC["BLENDER_COORDS"],
        PATHS.INC["STRUCT_NOISE_PARAMS"],
        PATHS.INC["BLENDER_HASH"],
        PATHS.INC["NOISE_BASE"],
        PATHS.INC["FRACTAL_NOISE"],
        PATHS.INC["NOISE_TEXTURE"],
    ]


func get_uniform_definitions() -> Dictionary:
    var u: Dictionary = {}

    u["dimensions"] = [ShaderSpec.ShaderType.INT, dimensions, ShaderSpec.UniformHint.ENUM, ["1D", "2D", "3D", "4D"]]
    u["fractal_type"] = [ShaderSpec.ShaderType.INT, fractal_type, ShaderSpec.UniformHint.ENUM, ["Multifractal", "Ridged Multifractal", "Hybrid Multifractal", "fBm", "Hetero Terrain"]]
    u["normalize"] = [ShaderSpec.ShaderType.BOOL, normalize]

    for s in get_input_sockets():
        if s.source:
            continue
        var uniform_def = s.to_uniform()
        if s.name == "Vector":
            pass
        u[s.name.to_lower()] = uniform_def

    return u

func get_code_blocks() -> Dictionary:
    var active := get_active_output_sockets()
    if active.is_empty():
        return {}

    var outputs := get_output_vars()
    var inputs := get_input_args()

    var blocks: Dictionary = {}

    var vector_expr: String
    var need_varying := false

    if dimensions == DimensionType.D1:
        vector_expr = "vec3(0.0)"
    else:
        var idx_vec := 0
        if input_sockets[idx_vec].source == null:
            # No connection use generated coords through varying
            need_varying = true
            var varying_name := "gen_vec_%s" % unique_id
            var global_decl := "varying vec3 %s;" % varying_name
            var vertex_code := """\n // {module}: {uid} (VERTEX)\n{varying} = apply_generated(blender_to_godot(VERTEX));\n""".format({
                "module": module_name,
                "uid": unique_id,
                "varying": varying_name,
            }).strip_edges()
            blocks["global_genvec_%s" % unique_id] = {"stage": "global", "code": global_decl}
            blocks["vertex_%s" % unique_id] = {"stage": "vertex", "code": vertex_code}
            vector_expr = varying_name
        else:
            vector_expr = inputs[idx_vec]


    # Macro override & unique function include
    var dims_define = get_uniform_override("dimensions")
    if dims_define == null:
        dims_define = dimensions
    dims_define = int(dims_define)

    var fract_define = get_uniform_override("fractal_type")
    if fract_define == null:
        fract_define = fractal_type
    fract_define = int(fract_define)

    var uid = unique_id
    var noise_path := PATHS.INC["NOISE_TEXTURE"]
    var args := {
        "uid": uid,
        "module": module_name,
        "vec_in": vector_expr,
        "value_out": outputs.get("Value", "value_%s" % uid),
        "color_out": outputs.get("Color", "color_%s" % uid),
        "w": inputs[1],
        "scale": inputs[2],
        "detail": inputs[3],
        "roughness": inputs[4],
        "lacunarity": inputs[5],
        "offset": inputs[6],
        "distortion": inputs[8],
        "gain": inputs[7],
        "normalize": get_prefixed_name("normalize"),
        "noise_path": noise_path,
        "dim_define": dims_define,
        "fract_define": fract_define
    }

    var base_funcs_np := [
        "noise_multi_fractal_np",
        "noise_ridged_multi_fractal_np",
        "noise_hybrid_multi_fractal_np",
        "noise_fbm_np",
        "noise_hetero_terrain_np"
    ]
    var base_funcs_4 := [
        "noise_multi_fractal4_np",
        "noise_ridged_multi_fractal4_np",
        "noise_hybrid_multi_fractal4_np",
        "noise_fbm4_np",
        "noise_hetero_terrain4_np"
    ]
    var base_func: String
    if dims_define == 3:
        base_func = base_funcs_4[fract_define]
    else:
        base_func = base_funcs_np[fract_define]

    var body := ""
    match dims_define:
        0:
            body = """
    float pw = params.w * params.scale;
    if (params.distortion != 0.0) {
        float pd = pw + _rand_float_offset(0.0);
        pw += snoise(pd) * params.distortion;
    }

    value = {base_func}(pw, params);

    float q1 = pw + _rand_float_offset(1.0);
    float q2 = pw + _rand_float_offset(2.0);
    vec3 c = vec3(
        {base_func}(q1, params),
        {base_func}(q2, params),
        0.0);
    color = vec4(value, c.r, c.g, 1.0);
    """
        1:
            body = """
    vec2 p2 = coord.xy * params.scale;
    if (params.distortion != 0.0) {
        p2 += vec2(
            snoise(p2 + _rand_vec2_offset(0.0)),
            snoise(p2 + _rand_vec2_offset(1.0))
        ) * params.distortion;
    }

    value = {base_func}(p2, params);

    vec2 q1 = p2 + _rand_vec2_offset(2.0);
    vec2 q2 = p2 + _rand_vec2_offset(3.0);
    vec3 c = vec3(
        {base_func}(q1, params),
        {base_func}(q2, params),
        0.0);
    color = vec4(value, c.r, c.g, 1.0);
    """
        2:
            body = """
    vec3 p = coord * params.scale;
    if (params.distortion != 0.0) {
        p += vec3(
            snoise(p + _rand_vec3_offset(0.0)),
            snoise(p + _rand_vec3_offset(1.0)),
            snoise(p + _rand_vec3_offset(2.0))
        ) * params.distortion;
    }

    value = {base_func}(p, params);

    vec3 p1 = p + _rand_vec3_offset(3.0);
    vec3 p2b = p + _rand_vec3_offset(4.0);
    vec3 c = vec3(
        {base_func}(p1, params),
        {base_func}(p2b, params),
        0.0);
    color = vec4(value, c.r, c.g, 1.0);
    """
        _:
            body = """
    vec4 p4 = vec4(coord, params.w) * params.scale;
    if (params.distortion != 0.0) {
        p4 += vec4(
            snoise(p4 + _rand_vec4_offset(0.0)),
            snoise(p4 + _rand_vec4_offset(1.0)),
            snoise(p4 + _rand_vec4_offset(2.0)),
            snoise(p4 + _rand_vec4_offset(3.0))
        ) * params.distortion;
    }

    value = {base_func}(p4, params);

    vec4 p1 = p4 + _rand_vec4_offset(4.0);
    vec4 p2b = p4 + _rand_vec4_offset(5.0);
    vec3 c = vec3(
        {base_func}(p1, params),
        {base_func}(p2b, params),
        0.0);
    color = vec4(value, c.r, c.g, 1.0);
    """

    body = body.format({"base_func": base_func})

    var func_code := """
// {module}: {uid} (GEN)
void noise_texture_{uid}(vec3 coord, NoiseParams params, out float value, out vec4 color) {{
{body}
}}
""".format({
        "module": module_name,
        "uid": uid,
        "body": body.indent("    ")
    })

    blocks["global_noise_%s" % uid] = {"stage": "global", "code": func_code}

    var param_lines := []
    if dims_define == 0 or dims_define == 3:
        param_lines.append("params_{uid}.w = {w};")
    param_lines.append("params_{uid}.scale = {scale};")
    param_lines.append("params_{uid}.detail = {detail};")
    param_lines.append("params_{uid}.roughness = {roughness};")
    param_lines.append("params_{uid}.lacunarity = {lacunarity};")
    if fract_define in [1,2,4]:
        param_lines.append("params_{uid}.offset = {offset};")
    param_lines.append("params_{uid}.distortion = {distortion};")
    if fract_define in [1,2]:
        param_lines.append("params_{uid}.gain = {gain};")
    if fract_define == 3:
        param_lines.append("params_{uid}.normalize = {normalize};")
    var params_code := "\n    ".join(param_lines).format(args)
    args["params_code"] = params_code

    var frag_template := """
// {module}: {uid} (FRAG)
NoiseParams params_{uid};
{params_code}
float value_{uid};
vec4 color_{uid};
noise_texture_{uid}({vec_in}, params_{uid}, value_{uid}, color_{uid});
vec4 {color_out} = color_{uid};
float {value_out} = value_{uid};
""".strip_edges()

    var frag_code := frag_template.format(args)

    blocks["fragment_%s" % uid] = {"stage": "fragment", "code": frag_code}

    return blocks

func get_compile_defines() -> Array[String]:
    var defs: Array[String] = []
    # If the "Vector" input is not connected, add an auxiliary constant
    if input_sockets.size() > 0 and input_sockets[0].source == null:
        defs.append("NOISE_NONE_CONNECTED")
    return defs
