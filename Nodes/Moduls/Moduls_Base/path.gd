# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

const INC_DIR := "res://addons/godot_shader_linker_(gsl)/Nodes/inc_shader/"
const INC = {
	"BLENDER_COORDS": INC_DIR + "formulas/coords.gdshaderinc", 
	"COORDS": INC_DIR + "formulas/coords.gdshaderinc",
	"PHYSICAL": INC_DIR + "formulas/physical.gdshaderinc",
	"MATH": INC_DIR + "formulas/math.gdshaderinc",
	"MATERIAL": INC_DIR + "formulas/struct_Material.gdshaderinc",
	"TEX_COORD": INC_DIR + "Tex_Cord.gdshaderinc",
	"MAPPING": INC_DIR + "Mapping.gdshaderinc",
	"MATERIAL_OUT": INC_DIR + "Material_Output.gdshaderinc",
	"BSDF_PRINCIPLED": INC_DIR + "BSDF_principled.gdshaderinc",
	"TEX_IMAGE": INC_DIR + "Tex_image.gdshaderinc",
	"STRUCT_TEX_IMG": INC_DIR + "formulas/struct_Tex_img.gdshaderinc",
	"BUMP": INC_DIR + "Bump.gdshaderinc",
	"NORMAL_MAP": INC_DIR + "Normal_map.gdshaderinc",
	"STRUCT_NOISE_PARAMS": INC_DIR + "formulas/struct_noise_params.gdshaderinc",
	"BLENDER_HASH": INC_DIR + "blender_hash.gdshaderinc",
	"NOISE_BASE": INC_DIR + "noise_base.gdshaderinc",
	"FRACTAL_NOISE": INC_DIR + "fractal_noise.gdshaderinc",
	"NOISE_TEXTURE": INC_DIR + "noise_texture.gdshaderinc",
    "COLOR_CONVERSIONS": INC_DIR + "color_conversions.gdshaderinc",
    "MIX_MODES": INC_DIR + "mix_modes.gdshaderinc",
	"MIX_FUNCTIONS": INC_DIR + "mix_functions.gdshaderinc",
}
