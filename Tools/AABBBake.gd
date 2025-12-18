@tool
extends RefCounted
class_name AabbBake

const paramMinName := "bbox_min"
const paramMaxName := "bbox_max"

static func bake_instance(mi: MeshInstance3D) -> bool:
	if mi == null:
		return false
	if mi.mesh == null:
		return false
	var aabb: AABB = mi.mesh.get_aabb()
	var minV: Vector3 = aabb.position
	var maxV: Vector3 = aabb.position + aabb.size
	mi.set_instance_shader_parameter(paramMinName, minV)
	mi.set_instance_shader_parameter(paramMaxName, maxV)
	return true

static func bake_subtree(root: Node) -> int:
	if root == null:
		return 0
	var count := 0
	for mi in iter_mesh_instances(root):
		if bake_instance(mi):
			count += 1
	return count

static func iter_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var n := stack.pop_back()
		if n is MeshInstance3D:
			out.append(n)
		for c in n.get_children():
			if c is Node:
				stack.append(c)
	return out