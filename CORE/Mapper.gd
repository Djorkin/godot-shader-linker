# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name Mapper


var current_chain: Array[ShaderModule] = []
var original_modules: Dictionary = {}
var module_links: Dictionary = {}


func get_active_modules() -> Array[ShaderModule]:
	return current_chain.duplicate() as Array[ShaderModule]

func add_module(module: ShaderModule, params: Dictionary = {}) -> void:
	# Применяем переданные параметры к модулю ещё до добавления в цепочку
	for pname in params.keys():
		if _has_property(module, pname):
			module.set(pname, params[pname])
		elif module.has_method("set_%s" % pname):
			module.call("set_%s" % pname, params[pname])
		else:
			# Проверяем, не является ли это uniform-параметром модуля
			if pname in module.get_uniform_definitions():
				module.set_uniform_override(pname, params[pname])
			else:
				push_warning("Mapper: parameter '%s' not found in module %s" % [pname, module.module_name])

	var mark = module.get_mark()
	
	#if original_modules.has(mark):
		#var original: ShaderModule = original_modules[mark]
		#module_links[module.unique_id] = original.unique_id
		#_redirect_connections(module, original)
	#else:
	original_modules[mark] = module
	current_chain.append(module)

func _redirect_connections(duplicate: ShaderModule, original: ShaderModule) -> void:
	for mod in current_chain:
		for input_socket in mod.get_input_sockets():
			if input_socket.source and input_socket.source.parent_module == duplicate:
				var sockets = original.get_output_sockets()
				if input_socket.source.get_index() < sockets.size():
					input_socket.source = sockets[input_socket.source.get_index()]
					mod.dependencies.erase(duplicate)
					mod.dependencies.append(original)


func build_final_chain() -> Array[ShaderModule]:
	var final_chain: Array[ShaderModule] = []
	for module in current_chain:
		if not module_links.has(module.unique_id):
			final_chain.append(module)
	
	print("Final chain size: ", final_chain.size())
	return final_chain

func clear_chain() -> void:
	current_chain.clear()
	original_modules.clear()
	module_links.clear()
	Collector.registered_modules.clear()

func _has_property(obj: Object, name: String) -> bool:
	for prop in obj.get_property_list():
		if prop.name == name:
			return true
	return false


# Тестовая цепочка
func create_sample_chain() -> void:
	clear_chain()

	var tex_coord = TextureCoordModule.new()
	var mapping = MappingModule.new()
	var tex_image = TextureImageModule.new()
	var bump = BumpModule.new()
	var principled = PrincipledBSDFModule.new()
	var out = OutputModule.new()

	add_module(tex_coord)
	add_module(mapping, {
		"mapping_type": MappingModule.MappingType.VECTOR
	})
	add_module(principled)
	add_module(tex_image, {
		"interpolation": TextureImageModule.InterpolationType.CUBIC,
		"extension": TextureImageModule.ExtensionType.EXTEND
	})
	add_module(bump)
	add_module(out)

	var final_chain: Array[ShaderModule] = build_final_chain()


	Collector.registered_modules.clear()
	for module in final_chain:
		Collector.register_module(module)

	Linker.link_modules(tex_coord, 0, mapping, 0)
	Linker.link_modules(mapping, 0, tex_image, 0)
	Linker.link_modules(tex_image, 0, bump, 3)
	Linker.link_modules(tex_image, 0, principled, 0)
	Linker.link_modules(bump, 0, principled, 5)
	Linker.link_modules(principled, 0, out, 0)
