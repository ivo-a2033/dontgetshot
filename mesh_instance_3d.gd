extends MeshInstance3D

func setup(start: Vector3, hit: Vector3):
	var dir = hit - start
	var length = dir.length()

	global_position = (start + hit) * 0.5

	mesh.height = length

	look_at(hit, Vector3.UP)
	rotate_object_local(Vector3.RIGHT, deg_to_rad(-90))

	await get_tree().create_timer(5).timeout
	queue_free()
