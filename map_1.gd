extends Node3D

var box: PackedScene = preload("res://samplecsgbox.tscn")

var world_boxes: Array = []


func init_world():
	if !multiplayer.is_server():
		return

	# Prevent regenerating if already made
	if world_boxes.size() > 0:
		return

	for i in range(50):
		var data = {
			"pos": Vector3(
				randf_range(-100, 100),
				2,
				randf_range(-100, 100)
			),
			"rot": Vector3(
				randf_range(0, TAU),
				randf_range(0, TAU),
				randf_range(0, TAU)
			)
		}

		world_boxes.append(data)
		spawn_box(data["pos"], data["rot"])


func spawn_box(pos: Vector3, rot: Vector3):
	var boxi = box.instantiate()
	boxi.position = pos
	boxi.rotation = rot
	boxi.size = Vector3(0.2, 4.0, 10.0)
	add_child(boxi)


@rpc("authority", "reliable")
func receive_world(boxes):
	for data in boxes:
		spawn_box(data["pos"], data["rot"])


func send_world_to_player(id: int):
	if !multiplayer.is_server():
		return

	receive_world.rpc_id(id, world_boxes)
