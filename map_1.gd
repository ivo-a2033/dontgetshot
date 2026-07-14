extends Node3D

var box: PackedScene = preload("res://samplecsgbox.tscn")
var world_boxes: Array = []

# Expose parameters to tweak the size and height of the spirals
@export var radius: float = 30.0
@export var peak_height: float = 50.0 # Maximum height reached at the very end of the spiral

func init_world():
	if !multiplayer.is_server():
		return

	# Prevent regenerating if already made
	if world_boxes.size() > 0:
		return

	var walls_per_spiral = 50
	var total_spirals = 3
	
	# Calculate the exact mathematical incline angle required to climb to the peak height
	# over an arc of 180 degrees (PI radians).
	# Distance along a circular arc is ArcLength = Angle * Radius -> PI * radius
	var arc_distance = PI * radius
	var calculated_incline_rad = atan(peak_height / arc_distance)
	
	# We want 3 spirals offset evenly around the circle (0, 120, and 240 degrees)
	for spiral_idx in range(total_spirals):
		var start_angle_offset = spiral_idx * (TAU / 3.0)
		
		for i in range(walls_per_spiral):
			# Progress along the current spiral (from 0.0 to 1.0)
			# Using (walls_per_spiral - 1) prevents dividing by zero and ensures we hit 180 deg exactly
			var t = float(i) / float(walls_per_spiral - 1)
			
			# The path wraps around 180 degrees (PI radians) from its start point
			var angle = start_angle_offset + (t * PI)
			
			# Position calculation (X and Z form the circle)
			var x = cos(angle) * radius
			var z = sin(angle) * radius
			
			# Y calculation: Climbs straight up continuously from 0 to peak_height
			var y = t * peak_height
			
			var pos = Vector3(x, y, z)
			
			# Rotation calculation:
			# 1. Yaw (rot_y): Align tangential to the circle
			var rot_y = -angle
			
			# 2. Pitch (rot_x): Tilt the box upward along the constant climbing angle.
			# Using a negative sign here aligns with Godot's 3D rotation convention for tilting up.
			var rot = Vector3(-calculated_incline_rad, rot_y, 0.0)
			
			var data = {
				"pos": pos,
				"rot": rot
			}
			
			world_boxes.append(data)
			spawn_box(data["pos"], data["rot"])


func spawn_box(pos: Vector3, rot: Vector3):
	var boxi = box.instantiate()
	boxi.position = pos
	boxi.rotation = rot
	# Custom size: 4x4 platforms with a thin 1.5 thickness for solid platforming feel
	boxi.size = Vector3(4.0, 1.5, 4.0) 
	add_child(boxi)


@rpc("authority", "reliable")
func receive_world(boxes):
	for data in boxes:
		spawn_box(data["pos"], data["rot"])


func send_world_to_player(id: int):
	if !multiplayer.is_server():
		return

	receive_world.rpc_id(id, world_boxes)
