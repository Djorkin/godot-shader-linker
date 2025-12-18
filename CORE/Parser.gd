# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name Parser



signal builder_ready(builder)
var json_dir_path := "user://gsl_logs"

var logger: GslLogger = GslLogger.get_logger()
var json_debug_enabled: bool = false

func data_transfer(data: Dictionary) -> void:
	var Importer_inst := Importer.new()
	var Builder_inst : ShaderBuilder = Importer_inst.build_chain(data)
	if Builder_inst:
		builder_ready.emit(Builder_inst)
	if json_debug_enabled:
		save_json(data, json_dir_path)


#region JSON debug

func set_json_dir_path(path: String) -> void:
	var cleaned := path.strip_edges()
	if cleaned.is_empty():
		logger.log_debug("JSON debug path is empty. Keeping previous: " + json_dir_path)
		return
	if not (cleaned.begins_with("user://") or cleaned.begins_with("res://")):
		logger.log_warning("JSON debug path must start with user:// or res:// (got: %s)" % cleaned)
		return
	if cleaned.ends_with("/"):
		cleaned = cleaned.left(cleaned.length() - 1)
	json_dir_path = cleaned
	logger.log_success("JSON debug path set to: " + json_dir_path)

func save_json(data: Dictionary, dir_path: String) -> void:
	var material_name := "material"
	if data.has("material") and typeof(data["material"]) == TYPE_STRING:
		material_name = data["material"]
	# Sanitize file name
	var file_name := material_name.to_lower().replace(" ", "_") + ".json"
	var full_path := dir_path + "/" + file_name

	# Ensure directory exists (create if needed)
	var abs_dir := ProjectSettings.globalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(abs_dir):
		var err := DirAccess.make_dir_recursive_absolute(abs_dir)
		if err != OK:
			logger.log_error("Failed to create json_exp folder (code %d)" % err)
			return

	if FileAccess.file_exists(full_path):
		var rem_err := DirAccess.remove_absolute(full_path)
		if rem_err != OK:
			logger.log_warning("Failed to remove old JSON: %s" % full_path)

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
		logger.log_success("JSON saved: " + full_path)
	else:
		logger.log_error("Failed to open file for writing: %s" % full_path)

#endregion JSON debug