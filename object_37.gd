extends MeshInstance3D

func _ready() -> void:
	# 1. Ensure this mesh actually has valid mesh data loaded
	if not mesh:
		push_warning("No mesh data found on this MeshInstance3D!")
		return
		
	# 2. Have the engine decompose the awful geometry into a simplified convex shape
	# clean=true and simplify=true ignores internal overlapping faces and stitches the shell together
	var convex_shape := mesh.create_convex_shape(true, true)
	
	# 3. Create the physics body and collision shape nodes programmatically
	var static_body := StaticBody3D.new()
	var collision_node := CollisionShape3D.new()
	
	# 4. Assign the generated convex shape to the collision node
	collision_node.shape = convex_shape
	
	# 5. Build the node hierarchy: MeshInstance3D -> StaticBody3D -> CollisionShape3D
	add_child(static_body)
	static_body.add_child(collision_node)
	
	print("Successfully generated a clean convex hull collision for: ", name)
