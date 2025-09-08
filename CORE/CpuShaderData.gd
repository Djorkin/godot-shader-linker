# SPDX-FileCopyrightText: 2025 D.Jorkin
# SPDX-License-Identifier: GPL-3.0-or-later

@tool
class_name CpuShaderData

# Service to push CPU-side data (e.g., AABB) into shaders as per-instance parameters.


static func update_instance(inst: GeometryInstance3D, only_if_needed: bool = true) -> void:
	if inst == null:
		return
	if not (inst is MeshInstance3D):
		return
	var mi: MeshInstance3D = inst
	if mi.mesh == null:
		return
	if only_if_needed and not instance_materials_require_bbox(mi):
		return
	var aabb: AABB = mi.mesh.get_aabb()
	var min_v: Vector3 = aabb.position
	var max_v: Vector3 = aabb.position + aabb.size
	mi.set_instance_shader_parameter("bbox_min", min_v)
	mi.set_instance_shader_parameter("bbox_max", max_v)
	if Engine.is_editor_hint():
		print("CpuShaderData:", " ", mi.get_path(), " bbox_min=", min_v, " bbox_max=", max_v)

static func update_subtree(root: Node, only_if_needed: bool = true) -> void:
	if root == null:
		return
	for node in iter_geometry_instances(root):
		update_instance(node, only_if_needed)

# helpers
static func iter_geometry_instances(root: Node) -> Array:
	var out: Array[GeometryInstance3D] = []
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is GeometryInstance3D:
			out.append(n)
		for c in n.get_children():
			if c is Node:
				stack.append(c)
	return out

static func instance_materials_require_bbox(mi: MeshInstance3D) -> bool:
	var mesh: Mesh = mi.mesh
	if mesh == null:
		return false
	var sc: int = mesh.get_surface_count()
	for i in range(sc):
		var mat: Material = mi.get_surface_override_material(i)
		if mat == null:
			mat = mesh.surface_get_material(i)
		if material_declares_bbox(mat):
			return true
	if mi.material_override and material_declares_bbox(mi.material_override):
		return true
	return false

static func material_declares_bbox(mat: Material) -> bool:
	if mat == null:
		return false
	if not (mat is ShaderMaterial):
		return false
	var sm: ShaderMaterial = mat
	if sm.shader == null:
		return false
	var code := String(sm.shader.code)
	return code.find("bbox_min") != -1 and code.find("bbox_max") != -1
