extends Node3D

var box: PackedScene = preload("res://samplecsgbox.tscn")
var world_boxes: Array = []

# --- Exposed parameters to tweak the Ring generation ---

## The radius for each individual ring.
@export var ring_radii: Array[float] = [30, 40, 50, 60, 70, 80]

## The local height (Y offset) for each ring before rotation is applied.
@export var ring_heights: Array[float] = [10.0, 10.0, 10.0, 10.0, 10.0, 10.0]

## The 3D rotation (Pitch, Yaw, Roll) in radians applied to each ring around the center of the world.
@export var ring_rotations: Array[Vector3] = [
	Vector3(0.0, 0.0, 0.0),                  
	Vector3(deg_to_rad(30), 0.0, 0.0),    
	Vector3(0.0, 0.0, deg_to_rad(-30)),  
	Vector3(deg_to_rad(60), 0.0, 0.0),      
	Vector3(deg_to_rad(30), 0.0, deg_to_rad(30)),       
	Vector3(0.0, deg_to_rad(30), 0.0),      
]

## How many individual platforms make up a single full ring.
@export var platforms_per_ring: int = 50


func init_world():
	if !multiplayer.is_server():
		return

	# Prevent regenerating if already made
	if world_boxes.size() > 0:
		return

	var total_rings = ring_radii.size()

	for ring_idx in range(total_rings):
		var r = ring_radii[ring_idx]
		var h = ring_heights[ring_idx] if ring_idx < ring_heights.size() else 0.0
		var rot_offset = ring_rotations[ring_idx] if ring_idx < ring_rotations.size() else Vector3.ZERO

		# Basis representing the ring's 3D rotation orientation
		var ring_basis = Basis.from_euler(rot_offset)

		for i in range(platforms_per_ring):
			var t = float(i) / float(platforms_per_ring)
			var angle = t * TAU
			
			# 1. Coordinate relative to a flat 2D circle
			var local_pos = Vector3(cos(angle) * r, h, sin(angle) * r)
			var local_basis = Basis.from_euler(Vector3(0.0, -angle, 0.0))

			# 2. Mathematically rotate the coordinates to match the ring's tilt
			var global_pos = ring_basis * local_pos
			var global_basis = ring_basis * local_basis
			var global_rot = global_basis.get_euler()

			# 3. Instantiate and position immediately under this node
			var boxi = box.instantiate()
			add_child(boxi)
			boxi.global_position = global_pos
			boxi.global_rotation = global_rot
			boxi.size = Vector3(4.0, 1.5, 8.0) 

			# 4. Save the absolute transformed data for syncing later
			var data = {
				"pos": global_pos,
				"rot": global_rot
			}
			world_boxes.append(data)


func spawn_box(pos: Vector3, rot: Vector3):
	var boxi = box.instantiate()
	add_child(boxi)
	boxi.global_position = pos
	boxi.global_rotation = rot
	boxi.size = Vector3(4.0, 1.5, 8.0) 


@rpc("authority", "reliable")
func receive_world(boxes):

		
	for data in boxes:
		spawn_box(data["pos"], data["rot"])


func send_world_to_player(id: int):
	if !multiplayer.is_server():
		return

	receive_world.rpc_id(id, world_boxes)
