extends MeshInstance3D

func _orient_along(dir: Vector3) -> Basis:
	var y_axis = dir.normalized()
	var reference = Vector3.RIGHT if abs(y_axis.dot(Vector3.UP)) > 0.9 else Vector3.UP
	var x_axis = reference.cross(y_axis).normalized()
	var z_axis = x_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)

func setup(start: Vector3, hit: Vector3, permanent=false):
	if mesh:
		mesh = mesh.duplicate()

	var dir = hit - start
	var length = dir.length()
	global_position = (start + hit) * 0.5
	mesh.height = length
	global_transform.basis = _orient_along(dir)

	if not permanent:
		await get_tree().create_timer(0.15).timeout
		queue_free()

	return self

func update_line(start: Vector3, hit: Vector3):
	var dir = hit - start
	var length = dir.length()
	if length < 0.0001:
		return
	global_position = (start + hit) * 0.5
	mesh.height = length
	global_transform.basis = _orient_along(dir)
