extends Path3D


func build_tunnels():
	var tunnels: Array[CSGPolygon3D] = []

	for child in get_children():
		if child is CSGPolygon3D:
			tunnels.append(child)

	await get_tree().process_frame

	for original in tunnels:
		var build_root := original.duplicate()
		build_root.operation = CSGShape3D.OPERATION_UNION
		add_child(build_root)
		build_root.global_transform = original.global_transform

		for other in tunnels:
			if other == original:
				continue

			var cutter := other.duplicate()
			cutter.operation = CSGShape3D.OPERATION_SUBTRACTION
			build_root.add_child(cutter)
			cutter.global_transform = other.global_transform

		await get_tree().process_frame

		var mesh := MeshInstance3D.new()
		mesh.mesh = build_root.bake_static_mesh()
		mesh.global_transform = original.global_transform

		var body := original.get_parent().get_node("StaticBody3D")

		var col := CollisionShape3D.new()
		col.shape = build_root.bake_collision_shape()
		col.global_transform = original.global_transform

		body.add_child(mesh)
		body.add_child(col)

		build_root.queue_free()

	for t in tunnels:
		t.queue_free()
		
func _ready():
	build_tunnels()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
