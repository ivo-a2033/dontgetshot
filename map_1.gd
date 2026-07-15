extends Node3D

var box: PackedScene = preload("res://samplecsgbox.tscn")
var world_boxes: Array = []

# --- Exposed parameters to tweak the spiral generation ---
@export var radius: Array[float] = [50.0, 70.0, 80.0]

## The peak heights for each individual spiral. 
## The size of this array will dynamically determine the total number of spirals generated.
@export var peak_heights: Array[float] = [50.0, 50.0, 40.0]

## How many full 360-degree rotations each spiral completes. (1.0 = 1 full turn, 0.5 = 180 deg)
@export var total_revolutions: float = .5

## The point (from 0.0 to 1.0) along the spiral where the climb stops and platforms become flat.
## E.g., 0.8 means the final 20% of the spiral forms a flat ring at its peak height.
@export_range(0.0, 1.0) var flat_cap_threshold: float = 0.8

func init_world():
	if !multiplayer.is_server():
		return

	# Prevent regenerating if already made
	if world_boxes.size() > 0:
		return

	var walls_per_spiral = 50
	var total_spirals = peak_heights.size()
	
	# Compute total angle span in radians
	var total_angle_span = total_revolutions * TAU
	

	for spiral_idx in range(total_spirals):
		
		# Calculate the arc length of the climbing portion of the spiral
		var climbing_arc_distance = (total_angle_span * radius[spiral_idx]) * flat_cap_threshold
	
		# Fetch the specific height limit for this spiral
		var peak_h = peak_heights[spiral_idx]
		
		# Incline angle for the climbing portion
		var calculated_incline_rad = atan(peak_h / climbing_arc_distance) if climbing_arc_distance > 0 else 0.0
		
		# Distribute the start angles evenly around the circle
		var start_angle_offset = spiral_idx * (TAU / 3)
		
		for i in range(walls_per_spiral):
			print(radius[spiral_idx])

			# Progress along the current spiral (from 0.0 to 1.0)
			var t = float(i) / float(walls_per_spiral - 1)
			
			# Current angle based on target revolutions
			var angle = start_angle_offset + (t * total_angle_span)
			
			# Circle positioning (X and Z)
			var x = cos(angle) * radius[spiral_idx]
			var z = sin(angle) * radius[spiral_idx]
			
			# Initialize variables for height and tilt calculation
			var y: float
			var pitch: float
			
			if t < flat_cap_threshold:
				# 1. Climbing zone: height scales linearly up to the peak height
				# Scale t relative to the climbing phase (from 0.0 to 1.0)
				var t_climb = t / flat_cap_threshold
				y = t_climb * peak_h
				pitch = -calculated_incline_rad
			else:
				# 2. Flat Ring Cap zone: height is locked to peak, platform is level
				y = peak_h+(t-flat_cap_threshold)*.1
				pitch = 0.0
			
			var pos = Vector3(x, y, z)
			
			# Yaw (rot_y): Align tangentially to the circle curve
			var rot_y = -angle
			
			# Assemble rotation (Pitch, Yaw, Roll)
			var rot = Vector3(pitch, rot_y, 0.0)
			
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
