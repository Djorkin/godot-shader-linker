# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name Importer 

var Collector_inst : Collector = Collector.new()
var Linker_inst : Linker = Linker.new()
var Mapper_inst : Mapper = Mapper.new()
var Builder_inst : ShaderBuilder = ShaderBuilder.new()

var NODE_CLASSES : Dictionary = {
		"TexCoordModule": TextureCoordModule,
		"MappingModule": MappingModule,
		"TexImageModule": TextureImageModule,
		"BumpModule": BumpModule,
		"BsdfPrincipledModule": PrincipledBSDFModule,
		"OutputMaterialModule": OutputModule,
		"NormalMapModule": NormalMapModule,
		"TexNoiseModule": NoiseTextureModule,
		"MixModule": MixModule,
		"MathModule": MathModule,
		"VectorMathModule": VectorMathModule,
		"MapRangeModule": MapRangeModule,
		"TexWhiteNoiseModule": TexWhiteNoiseModule,
		"CombineColorModule": CombineColorModule,
		"SeparateColorModule": SeparateColorModule,
		"CombineXYZModule": CombineXYZModule,
		"SeparateXYZModule": SeparateXYZModule,
		"ColorRampModule": ColorRampModule,
}

func instantiate_modules(data: Dictionary) -> Dictionary:
	var node_table := {}
	for node_dict in data["nodes"]:
		if typeof(node_dict) != TYPE_DICTIONARY:
			continue
		var node_type: String = node_dict.get("type", node_dict.get("class", ""))
		var cls: Variant = NODE_CLASSES.get(node_type, null)
		if cls == null:
			push_warning("Blender node '%s' not supported" % node_type)
			continue
		var module: ShaderModule = cls.new()
		node_table[node_dict.get("id")] = module
	return node_table

func add_modules_to_mapper(node_table: Dictionary, data: Dictionary) -> void:
	for node_dict in data["nodes"]:
		var id = node_dict.get("id")
		if not node_table.has(id):
			continue
		var module: ShaderModule = node_table[id]
		# Pass parameters
		if node_dict.has("params") and typeof(node_dict["params"]) == TYPE_DICTIONARY:
			for p in node_dict["params"]:
				var v = node_dict["params"][p]
				module.set_uniform_override(p, sanitize_param_value(v))
			# Special handling of texture paths for TextureImageModule
			if module is TextureImageModule and node_dict.has("params"):
				var params: Dictionary = node_dict["params"]
				if params.has("image_path") and typeof(params["image_path"]) == TYPE_STRING:
					var uniform_name = module.get_prefixed_name("image_texture")
					Builder_inst.uniform_resources[uniform_name] = params["image_path"]
			# Special handling for ColorRampModule: register GradientTexture2D
			if module is ColorRampModule:
				var crm: ColorRampModule = module
				crm.register_gradient_resource(Builder_inst)
		Mapper_inst.add_module(module)

func register_in_collector() -> void:
	var final_chain: Array[ShaderModule] = Mapper_inst.build_final_chain()
	Collector_inst.registered_modules.clear()
	for mod in final_chain:
		Collector_inst.register_module(mod) 

func link_modules(data: Dictionary, node_table: Dictionary) -> void:
	for link_item in data["links"]:
		var from_id: String
		var to_id: String
		var from_socket := 0
		var to_socket := 0

		if typeof(link_item) == TYPE_DICTIONARY:
			from_id = str(link_item.get("from_node"))
			to_id = str(link_item.get("to_node"))
			from_socket = int(link_item.get("from_socket", 0))
			to_socket = int(link_item.get("to_socket", 0))
		elif typeof(link_item) == TYPE_STRING:
			var parts = link_item.split(",")
			if parts.size() < 4:
				continue
			from_id = parts[0]
			from_socket = int(parts[1])
			to_id = parts[2]
			to_socket = int(parts[3])
		else:
			continue
		var from_mod: ShaderModule = node_table.get(from_id, null)
		var to_mod: ShaderModule = node_table.get(to_id, null)
		if from_mod == null or to_mod == null:
			continue
		Linker_inst.link_modules(from_mod, from_socket, to_mod, to_socket)

func build_chain(data: Dictionary) -> ShaderBuilder:
	if not (data.has("nodes") and data.has("links")):
		push_error("No nodes/links fields")
		return
	
	Mapper_inst.clear_chain(Collector_inst)
	
	var node_table: Dictionary = instantiate_modules(data)
	add_modules_to_mapper(node_table, data)
	link_modules(data, node_table)
	register_in_collector()
	
	Collector_inst.configure(Builder_inst)
	return Builder_inst

func sanitize_param_value(val):
	match typeof(val):
		TYPE_ARRAY:
			if val.size() == 3 and array_is_numeric(val):
				return Vector3(val[0], val[1], val[2])
			elif val.size() == 4 and array_is_numeric(val):
				return Vector4(val[0], val[1], val[2], val[3])
			return val
		TYPE_FLOAT:
			if int(val) == val:
				return int(val)
			return val
		_:
			return val

func array_is_numeric(arr: Array) -> bool:
	for e in arr:
		if typeof(e) not in [TYPE_FLOAT, TYPE_INT]:
			return false
	return true 
