# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name Parser

const SERVER_URL := "http://127.0.0.1:5050/link"

signal builder_ready(builder)


func data_transfer(data: Dictionary) -> void:
	var Importer_inst := Importer.new()
	var Builder_inst : ShaderBuilder = Importer_inst.build_chain(data)
	if Builder_inst:
		builder_ready.emit(Builder_inst)
	save_json(data) # debug only


func send_request() -> void:
	var http := HTTPRequest.new()
	var tree := Engine.get_main_loop()

	if tree and tree is SceneTree:
		tree.root.add_child(http)
	else:
		push_error("SceneTree not found – Parser.send_request should be called from game/editor")
		return

	http.request_completed.connect(self._on_request_completed.bind(http))

	var err := http.request(SERVER_URL)
	if err != OK:
		push_error("Failed to send request (%s)" % err)


func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	if is_instance_valid(http):
		http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("[color=red]Blender server is not available (result %d)[/color]" % result)
		print_rich("[color=red]Blender server is not available[/color]")
		return

	if response_code != 200:
		push_error("[color=red]Blender server returned code %d[/color]" % response_code)
		print_rich("[color=red]Blender server returned code %d[/color]" % response_code)
		return

	if body.is_empty():
		push_error("[color=red]Empty response from Blender server[/color]")
		print_rich("[color=red]Empty response from Blender server[/color]")
		return

	var text := body.get_string_from_utf8()
	var data = JSON.parse_string(text)

	if typeof(data) != TYPE_DICTIONARY:
		push_error("[color=red]Invalid JSON or response format[/color]")
		print_rich("[color=red]Invalid JSON or response format[/color]")
		return

	# Краткий вывод: только количество нод и связей
	if data.has("nodes") and data.has("links"):
		var nodes = data["nodes"].size()
		var links = data["links"].size()
		print_rich("[color=green]Blender server[/color] → nodes=" + str(nodes) + ", links=" + str(links))
	else:
		print_rich("[color=green]Blender server[/color] → " + str(data))
	
	data_transfer(data)


func save_json(data: Dictionary) -> void:
	var dir_path := "user://gsl_logs"
	var material_name := "material"
	if data.has("material") and typeof(data["material"]) == TYPE_STRING:
		material_name = data["material"]
	# Приводим к безопасному имени файла
	var file_name := material_name.to_lower().replace(" ", "_") + ".json"
	var full_path := dir_path + "/" + file_name

	# Убеждаемся, что директория существует (создаём при необходимости)
	var abs_dir := ProjectSettings.globalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(abs_dir):
		var err := DirAccess.make_dir_recursive_absolute(abs_dir)
		if err != OK:
			push_error("Failed to create json_exp folder (code %d)" % err)
			return

	if FileAccess.file_exists(full_path):
		var rem_err := DirAccess.remove_absolute(full_path)
		if rem_err != OK:
			push_warning("Failed to remove old JSON: %s" % full_path)

	var json_text: String
	if data.has("material") and data.has("nodes") and data.has("links"):
		var nodes_str := JSON.stringify(data["nodes"], "\t")
		var links_str := JSON.stringify(data["links"], "\t")
		json_text = "{\n\t\"material\": \"%s\",\n\t\"nodes\": %s,\n\t\"links\": %s\n}" % [data["material"], nodes_str, links_str]
	else:
		json_text = JSON.stringify(data, "\t")

	var file := FileAccess.open(full_path, FileAccess.WRITE)
	if file:
		file.store_string(json_text)
		file.close()
		print_rich("[color=green]JSON saved:[/color] " + full_path)
	else:
		push_error("Failed to open file for writing: %s" % full_path)
