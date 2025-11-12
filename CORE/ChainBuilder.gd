@tool
class_name ChainBuilder

var mapper_inst: Mapper = Mapper.new()
var linker_inst: Linker = Linker.new()
var collector_inst: Collector = Collector.new()
var builder_inst: ShaderBuilder = ShaderBuilder.new()

var nodes: Dictionary = {} # uid -> ShaderModule


func clear() -> void:
	mapper_inst.clear_chain(collector_inst)
	builder_inst = ShaderBuilder.new()
	nodes.clear()


# Регистрируем заранее созданный модуль и (опционально) применяем params
# Возвращаем его уникальный uid (module.unique_id)
func add_module(module: ShaderModule, params: Dictionary = {}) -> String:
	if module == null:
		push_error("add_module: module is null")
		return ""
	var uid := String(module.unique_id)
	mapper_inst.add_module(module, params)
	nodes[uid] = module
	return uid


func set_param(node_id: String, name, value) -> void:
	var m: ShaderModule = nodes.get(node_id, null)
	if m == null:
		push_error("set_param: node not found %s" % node_id)
		return
	var pname := ""
	match typeof(name):
		TYPE_INT:
			if m.has_method("param_name"):
				pname = String(m.param_name(int(name)))
			else:
				push_error("set_param: module %s doesn't support enum parameters" % node_id)
				return
		_:
			pname = String(name)
	# Сначала пытаемся как экспортное свойство
	if has_property(m, pname):
		m.set(pname, value)
		return
	# Затем как униформ (и его lower-case вариант)
	var udefs = m.get_uniform_definitions()
	if udefs.has(pname):
		m.set_uniform_override(pname, value)
		return
	var lname = pname.to_lower()
	if udefs.has(lname):
		m.set_uniform_override(lname, value)
		return
	push_warning("set_param: parameter '%s' not found on %s" % [pname, m.module_name])


# Линковка по enum сокетам (enum — это int)
func link(from_id: String, from_socket: int, to_id: String, to_socket: int) -> void:
	var a: ShaderModule = nodes.get(from_id, null)
	var b: ShaderModule = nodes.get(to_id, null)
	if a == null or b == null:
		push_error("link: node not found (%s -> %s)" % [from_id, to_id])
		return
	linker_inst.link_modules(a, from_socket, b, to_socket)


func build(shader_type: String = "spatial") -> ShaderBuilder:
	# Обнуляем билдер, чтобы исключить накопление кода между пересборками
	builder_inst = ShaderBuilder.new()
	collector_inst.registered_modules.clear()
	var chain: Array[ShaderModule] = mapper_inst.build_final_chain()
	for mod in chain:
		collector_inst.register_module(mod)
	collector_inst.configure(builder_inst, shader_type)
	return builder_inst


func get_module(id: String) -> ShaderModule:
	return nodes.get(id, null)


func get_active_modules() -> Array[ShaderModule]:
	return mapper_inst.get_active_modules()


# helpers
func has_property(obj: Object, name: String) -> bool:
	for p in obj.get_property_list():
		if p.name == name:
			return true
	return false
