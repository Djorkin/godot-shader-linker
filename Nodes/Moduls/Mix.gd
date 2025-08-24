# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name MixModule
extends ShaderModule

enum DataType { FLOAT_TYPE, VECTOR_TYPE, COLOR_TYPE }
enum BlendType {
    MIX,
    DARKEN,
    MULTIPLY,
    COLOR_BURN,
    LIGHTEN,
    SCREEN,
    COLOR_DODGE,
    ADD,
    OVERLAY,
    SOFT_LIGHT,
    LINEAR_LIGHT,
    DIFFERENCE,
    EXCLUSION,
    SUBTRACT,
    DIVIDE,
    HUE,
    SATURATION,
    COLOR,
    VALUE
}
enum VectorFactorMode { UNIFORM, NON_UNIFORM }


@export_enum("Float","Vector","Color") var mix_data_type : int = DataType.COLOR_TYPE
@export_enum("Mix","Darken","Multiply","Color Burn","Lighten","Screen","Color Dodge","Add","Overlay","Soft Light","Linear Light","Difference","Exclusion","Subtract","Divide","Hue","Saturation","Color","Value")
var mix_blend_type : int = BlendType.MIX
@export var clamp_result: bool = false
@export var clamp_factor: bool = false
@export_enum("Uniform","Non-Uniform") var vector_factor_mode : int = VectorFactorMode.UNIFORM


func _init() -> void:
    super._init()
    module_name = "Mix"
    _configure_input_sockets()

# configure input sockets depending on data type
func _configure_input_sockets() -> void:
    match mix_data_type:
        DataType.COLOR_TYPE:
            input_sockets = [
                InputSocket.new("Factor", InputSocket.SocketType.FLOAT, 0.5),
                InputSocket.new("A_Color", InputSocket.SocketType.VEC4, Vector4(0.5,0.5,0.5,1.0)),
                InputSocket.new("B_Color", InputSocket.SocketType.VEC4, Vector4(0.5,0.5,0.5,1.0)),
            ]
        DataType.VECTOR_TYPE:
            if vector_factor_mode == VectorFactorMode.UNIFORM:
                input_sockets = [
                    InputSocket.new("Factor", InputSocket.SocketType.FLOAT, 0.5),
                    InputSocket.new("A_Vector", InputSocket.SocketType.VEC3, Vector3(0.5,0.5,0.5)),
                    InputSocket.new("B_Vector", InputSocket.SocketType.VEC3, Vector3(0.5,0.5,0.5)),
                ]
            else:
                input_sockets = [
                    InputSocket.new("NonUniformFactor", InputSocket.SocketType.VEC3, Vector3(0.5,0.5,0.5)),
                    InputSocket.new("A_Vector", InputSocket.SocketType.VEC3, Vector3(0.5,0.5,0.5)),
                    InputSocket.new("B_Vector", InputSocket.SocketType.VEC3, Vector3(0.5,0.5,0.5)),
                ]
        _:
            input_sockets = [
                InputSocket.new("Factor", InputSocket.SocketType.FLOAT, 0.5),
                InputSocket.new("A_Float", InputSocket.SocketType.FLOAT, 0.0),
                InputSocket.new("B_Float", InputSocket.SocketType.FLOAT, 0.0)
            ]

    output_sockets = [
        OutputSocket.new("Color", OutputSocket.SocketType.VEC4),
        OutputSocket.new("Vector", OutputSocket.SocketType.VEC3),
        OutputSocket.new("Value", OutputSocket.SocketType.FLOAT),
    ]
    for s in output_sockets:
        s.set_parent_module(self)


func get_include_files() -> Array[String]:
    if mix_data_type == DataType.COLOR_TYPE:
        return [PATHS.INC["COLOR_CONVERSIONS"],PATHS.INC["MIX_MODES"]]
    else:
        return [PATHS.INC["MIX_FUNCTIONS"]]


func get_uniform_definitions() -> Dictionary:
    var u := {}
    # Тип данных модуля
    u["mix_data_type"] = [ShaderSpec.ShaderType.INT, mix_data_type, ShaderSpec.UniformHint.ENUM, ["Float","Vector","Color"]]

    match mix_data_type:
        DataType.COLOR_TYPE:
            # Основные параметры смешивания цвета
            u["mix_blend_type"] = [ShaderSpec.ShaderType.INT, mix_blend_type, ShaderSpec.UniformHint.ENUM, ["Mix","Darken","Multiply","Color Burn","Lighten","Screen","Color Dodge","Add","Overlay","Soft Light","Linear Light","Difference","Exclusion","Subtract","Divide","Hue","Saturation","Color","Value"]]
            u["clamp_result"] = [ShaderSpec.ShaderType.BOOL, clamp_result]
            u["clamp_factor"] = [ShaderSpec.ShaderType.BOOL, clamp_factor]

        
        DataType.VECTOR_TYPE:
            # Параметры смешивания векторных значений
            u["vector_factor_mode"] = [ShaderSpec.ShaderType.INT, vector_factor_mode, ShaderSpec.UniformHint.ENUM, ["Uniform","Non-Uniform"]]
            u["clamp_factor"] = [ShaderSpec.ShaderType.BOOL, clamp_factor]

        _:
            # FLOAT_TYPE по умолчанию
            u["clamp_factor"] = [ShaderSpec.ShaderType.BOOL, clamp_factor]

    # Добавляем uniform'ы для не подключённых входных сокетов
    for s in get_input_sockets():
        if s.source:
            continue
        var def = s.to_uniform()
        match s.name:
            "Factor", "mix_factor":
                def["hint"] = ShaderSpec.UniformHint.RANGE
                def["hint_params"] = {"min":0, "max":1}
            "A_Color", "B_Color":
                def["hint"] = ShaderSpec.UniformHint.SOURCE_COLOR
            _:
                pass
        u[s.name.to_lower()] = def

    return u

func get_code_blocks() -> Dictionary:
    var active := get_active_output_sockets()
    if active.is_empty():
        return {}

    var outputs := get_output_vars()
    var inputs := get_input_args()

    var blocks: Dictionary = {}
    var uid := unique_id

    match mix_data_type:
        DataType.COLOR_TYPE:
            # Определяем функцию смешивания цвета без runtime-switch по blend_type
            var blend_val = 0
            var tmp_val = get_uniform_override("mix_blend_type")
            if tmp_val == null:
                blend_val = mix_blend_type
            else:
                blend_val = int(tmp_val)

            var blend_map := [
                "blend", "dark", "mul", "burn", "light", "screen", "dodge", "add", "overlay",
                "soft", "linear", "diff", "exclusion", "sub", "div", "hue", "sat", "color", "val"
            ]
            var blend_func := "node_mix_%s" % blend_map[blend_val]

            var func_code := """
// {module}: {uid} (GEN)
vec3 mix_color_{uid}(bool use_cf, bool use_cr, float Factor, vec3 A, vec3 B) {{
    float t = use_cf ? clamp(Factor, 0.0, 1.0) : Factor;
    vec3 res = {blend}(t, A, B);
    if (use_cr) {{ res = node_mix_clamp(res); }}
    return res;
}}
""".format({
                "module": module_name,
                "uid": uid,
                "blend": blend_func,
            })
            blocks["global_mix_%s" % uid] = {"stage": "global", "code": func_code}

            var args_col := {
                "uid": uid,
                "cf": get_prefixed_name("clamp_factor"),
                "cr": get_prefixed_name("clamp_result"),
                "factor": inputs[0],
                "a": inputs[1] + ".rgb",
                "b": inputs[2] + ".rgb",
                "out": outputs.get("Color", "color_%s" % uid),
            }

            var frag_code := """
// {module}: {uid} (FRAG)
vec3 res_col_{uid} = mix_color_{uid}({cf}, {cr}, {factor}, {a}, {b});
vec4 {out} = vec4(res_col_{uid}, 1.0);
""".format(args_col)
            blocks["fragment_mix_%s" % uid] = {"stage": "fragment", "code": frag_code}

        DataType.VECTOR_TYPE:
            var func_name := "mix_vector"
            if vector_factor_mode != VectorFactorMode.UNIFORM:
                func_name = "mix_vector_non_uniform"
            var vec_var := outputs.get("Vector", "vector_%s" % uid)
            var color_var := outputs.get("Color", "color_%s" % uid)
            var frag_code_v := """
// {module}: {uid} (FRAG)
vec3 {vec_out} = {func}({cf}, {factor}, {a}, {b});
vec4 {col_out} = vec4({vec_out}, 1.0);
""".format({
                "module": module_name,
                "uid": uid,
                "vec_out": vec_var,
                "col_out": color_var,
                "func": func_name,
                "cf": get_prefixed_name("clamp_factor"),
                "factor": inputs[0],
                "a": inputs[1],
                "b": inputs[2],
            })
            blocks["fragment_mix_%s" % uid] = {"stage": "fragment", "code": frag_code_v}

        _:
            # FLOAT_TYPE
            var val_var := outputs.get("Value", "value_%s" % uid)
            var color_var_f := outputs.get("Color", "color_%s" % uid)
            var vec_var_f := outputs.get("Vector", "vector_%s" % uid)
            var frag_code_f := """
// {module}: {uid} (FRAG)
float {val_out} = mix_float({cf}, {factor}, {a}, {b});
vec3 {vec_out} = vec3({val_out});
vec4 {col_out} = vec4({val_out}, {val_out}, {val_out}, 1.0);
""".format({
                "module": module_name,
                "uid": uid,
                "val_out": val_var,
                "vec_out": vec_var_f,
                "col_out": color_var_f,
                "cf": get_prefixed_name("clamp_factor"),
                "factor": inputs[0],
                "a": inputs[1],
                "b": inputs[2],
            })
            blocks["fragment_mix_%s" % uid] = {"stage": "fragment", "code": frag_code_f}

    return blocks


func set_uniform_override(name: String, value) -> void:
    match name:
        "data_type":
            name = "mix_data_type"
        "blend_type":
            name = "mix_blend_type"
        "vector_factor_mode":
            name = "vector_factor_mode"
        "a":
            if mix_data_type == DataType.COLOR_TYPE:
                name = "a_color"
            elif mix_data_type == DataType.VECTOR_TYPE:
                name = "a_vector"
            else:
                name = "a_float"
        "b":
            if mix_data_type == DataType.COLOR_TYPE:
                name = "b_color"
            elif mix_data_type == DataType.VECTOR_TYPE:
                name = "b_vector"
            else:
                name = "b_float"
    
    # Исправляем несоответствие размеров цвета (Vector3 → Vector4)
    if name in ["a_color", "b_color"]:
        if typeof(value) == TYPE_VECTOR3:
            value = Vector4(value.x, value.y, value.z, 1.0)
        elif typeof(value) == TYPE_ARRAY and value.size() == 3:
            value = Vector4(value[0], value[1], value[2], 1.0)
    
    # если переопределяем тип данных — обновляем конфигурацию сокетов
    if name == "mix_data_type":
        var new_type := int(value)
        if new_type != mix_data_type:
            mix_data_type = new_type
            _configure_input_sockets()
    elif name == "vector_factor_mode":
        var new_vec_mode := int(value)
        if new_vec_mode != vector_factor_mode:
            vector_factor_mode = new_vec_mode
            _configure_input_sockets()

    super.set_uniform_override(name, value)



