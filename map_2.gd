extends Node3D

var box: PackedScene = preload("res://samplecsgbox.tscn")
var world_boxes: Array = []

# --- Exposed parameters to tweak the Tower & Ring generation ---

## Global locations of the 4 towers in 3D space.
## Towers are moved closer (30 units apart) to guarantee overlapping structures.
@export var tower_positions: Array[Vector3] = [
	Vector3(-15.0, 0.0, -15.0), # Front-Left
	Vector3(15.0, 0.0, -15.0),  # Front-Right
	Vector3(-15.0, 0.0, 15.0),  # Back-Left
	Vector3(15.0, 0.0, 15.0)    # Back-Right
]

## Radius of the cylindrical towers. 
## Set larger than half the distance between towers so they physically overlap/intersect.
@export var tower_radius: float = 25.0

## How many individual rings are stacked vertically on each tower
@export var rings_per_tower: int = 5

## Vertical spacing (step height) between each ring level on a tower
@export var vertical_ring_spacing: float = 12.0

## The 3D rotation (inclination tilt) applied to each stacked ring.
@export var ring_tilts: Array[Vector3] = [
	Vector3(deg_to_rad(15), 0.0, 0.0),
	Vector3(0.0, 0.0, deg_to_rad(15)),
	Vector3(deg_to_rad(-15), 0.0, 0.0),
	Vector3(0.0, 0.0, deg_to_rad(-15))
]

## How many individual platforms make up a single full ring
@export var platforms_per_ring: int = 30


func init_world():
	if !multiplayer.is_server():
		return

	# Prevent regenerating if already made
	if world_boxes.size() > 0:
		return

	# Loop through each of the 4 towers
	for tower_idx in range(tower_positions.size()):
		var tower_center = tower_positions[tower_idx]

		# Stack N rings up each tower
		for ring_idx in range(rings_per_tower):
			var local_y_offset = ring_idx * vertical_ring_spacing
			
			# Determine inclination angle for this ring layer
			var tilt = Vector3.ZERO
			if ring_tilts.size() > 0:
				tilt = ring_tilts[ring_idx % ring_tilts.size()]
			
			var ring_basis = Basis.from_euler(tilt)

			# Generate the circular platforms
			for i in range(platforms_per_ring):
				var t = float(i) / float(platforms_per_ring)
				var angle = t * TAU
				
				# 1. Platform coordinate relative to a local, flat circle
				var local_pos = Vector3(cos(angle) * tower_radius, local_y_offset, sin(angle) * tower_radius)
				
				# Generate a tiny 1-to-2 degree random pitch offset (local X axis jitter)
				# to break up identical overlapping planes and completely stop Z-fighting
				var jitter_x = randf_range(deg_to_rad(-2.0), deg_to_rad(2.0))
				var local_basis = Basis.from_euler(Vector3(jitter_x, -angle, 0.0))

				# 2. Apply ring inclination tilt locally, then shift to global tower coordinates
				var tilted_pos = ring_basis * local_pos
				var global_pos = tower_center + tilted_pos
				
				var global_basis = ring_basis * local_basis
				var global_rot = global_basis.get_euler()

				# 3. Instantiate and position immediately under this node
				var boxi = box.instantiate()
				add_child(boxi)
				boxi.global_position = global_pos
				boxi.global_rotation = global_rot
				boxi.size = Vector3(4.0, 1.5, 8.0) 

				# 4. Save absolute transformed data for network syncing
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
