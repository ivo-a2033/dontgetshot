extends Node

# Set to false if you want faster, simplified convex hulls instead of highly precise trimeshes
@export var use_precise_trimesh: bool = true

func _ready() -> void:
	# Start recursive generation from this node downward
	generate_collisions_recursively(self)


## Recursively crawls the node tree looking for MeshInstance3D nodes.
func generate_collisions_recursively(current_node: Node) -> void:
	if current_node is MeshInstance3D:
		_create_collision_for_mesh(current_node)
	
	# Keep traversing down the hierarchy
	for child in current_node.get_children():
		generate_collisions_recursively(child)


## Creates the physics body and collision shape using the MeshInstance3D's geometry.
func _create_collision_for_mesh(mesh_instance: MeshInstance3D) -> void:
	# Safety check: Ensure the mesh instance actually has a valid mesh assigned
	if not mesh_instance.mesh:
		return
		
	# 1. Clean up any existing generated static bodies to avoid duplicate collisions
	for child in mesh_instance.get_children():
		if child.name == "AutoStaticBody":
			child.queue_free()
			mesh_instance.remove_child(child)

	# 2. Generate the appropriate CollisionShape3D resource from the mesh data
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "AutoCollisionShape"
	
	if use_precise_trimesh:
		# Best for static terrain/environments (Concave shape)
		collision_shape.shape = mesh_instance.mesh.create_trimesh_shape()
	else:
		# Best for dynamic/rigid bodies or simple props (Convex shape)
		collision_shape.shape = mesh_instance.mesh.create_convex_shape()

	# 3. Build a StaticBody3D parent to house our new shape
	var static_body := StaticBody3D.new()
	static_body.name = "AutoStaticBody"
	
	# 4. Assemble the tree structure: Mesh -> StaticBody3D -> CollisionShape3D
	mesh_instance.add_child(static_body)
	static_body.add_child(collision_shape)
	
	# Ensure the static body's local transform is reset so it aligns perfectly with the mesh
	static_body.transform = Transform3D.IDENTITY
