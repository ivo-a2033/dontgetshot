extends CharacterBody3D

enum MoveState { IDLE, WALK, SPRINT, CROUCH }
const ANIM_NAME := "mixamo_com"

# --- Dynamic Path Config ---
var custom_paths := {
	"walk": "",
	"sprint": "",
	"crouch": "",
	"scale": 1.0
}

var speed = 0
@export var sprintspeed := 12.0
@export var normalspeed := 8.0
@export var crouchspeed := 4.0
@export var spread_degrees := .2

@export var jump_velocity := 0
@export var mouse_sensitivity := 0.0025
@export var zoom_sensitivity := 1.2

# --- Wall Jumping Configuration ---
@export var wall_jump_force := 10.0
@export var wall_jump_up_force := 10.0
@export var air_control := 5.0 # How much control the player has in the air

# --- shooting ---
@export var fire_rate := 0.1
var shooting := false
var shoot_cooldown := 0.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * 2.5

@onready var head = $Head
@onready var camera = $Head/Camera3D

var move_nodes := {}
var current_move_state := MoveState.IDLE

var health = 100
var last_h = health
var last_position = Vector3.ZERO
var focused = true
var time_since_dmg = 10

var idle_timer := 0.0
const IDLE_GRACE := 0.5

var remote_crouching := false

# --- settings menu ---
var settings_open := false
var settings_menu: CanvasLayer
var resolution_options := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

func _ready():
		

	# Dynamically instantiate character variants instead of linking hardcoded editor nodes
	_instantiate_dynamic_nodes()

	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		$Head/Camera3D.current = true
		_build_settings_menu()
	else:
		$Head/Camera3D.current = false
		$ProgressBar.hide()
	

func _instantiate_dynamic_nodes():
	var path_map = {
		MoveState.WALK: custom_paths.get("walk", ""),
		MoveState.SPRINT: custom_paths.get("sprint", ""),
		MoveState.CROUCH: custom_paths.get("crouch", "")
	}

	# Read the unique scale configuration value from our custom dictionary data
	var model_scale: float = custom_paths.get("scale", 1.0)

	for state in path_map:
		var path = path_map[state]
		if path != "":
			var scene = load(path)
			if scene:
				var instance = scene.instantiate()
				
				# Apply individual model configuration scale variations
				instance.scale = Vector3(model_scale, model_scale, model_scale)
				
				# Rotate 180 degrees around the local Y axis
				instance.rotation.y = PI
				
				# Set custom baseline drop position to match your character height configuration
				# For instance, a 2.0-unit capsule requires a -1.0 Y offset to align with the ground.
				instance.position.y = -1.0
				
				add_child(instance)
				instance.hide()
				move_nodes[state] = instance

	if move_nodes.has(MoveState.WALK):
		move_nodes[MoveState.WALK].show()

func _build_settings_menu():
	settings_menu = CanvasLayer.new()
	settings_menu.layer = 10
	add_child(settings_menu)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(340, 260)
	panel.position = Vector2(40, 40)
	settings_menu.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(16, 16)
	vbox.custom_minimum_size = Vector2(308, 308)
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Settings (Y to close)"
	vbox.add_child(title)

	var mouse_label := Label.new()
	mouse_label.text = "Mouse Sensitivity"
	vbox.add_child(mouse_label)

	var mouse_sens_slider := HSlider.new()
	mouse_sens_slider.min_value = 0.0005
	mouse_sens_slider.max_value = 0.01
	mouse_sens_slider.step = 0.0001
	mouse_sens_slider.value = mouse_sensitivity
	mouse_sens_slider.custom_minimum_size = Vector2(280, 20)
	mouse_sens_slider.value_changed.connect(func(v): mouse_sensitivity = v)
	vbox.add_child(mouse_sens_slider)

	var zoom_label := Label.new()
	zoom_label.text = "Zoom Sensitivity"
	vbox.add_child(zoom_label)

	var zoom_sens_slider := HSlider.new()
	zoom_sens_slider.min_value = 1.02
	zoom_sens_slider.max_value = 2.0
	zoom_sens_slider.step = 0.01
	zoom_sens_slider.value = zoom_sensitivity
	zoom_sens_slider.custom_minimum_size = Vector2(280, 20)
	zoom_sens_slider.value_changed.connect(func(v): zoom_sensitivity = v)
	vbox.add_child(zoom_sens_slider)

	var render_scale_label := Label.new()
	render_scale_label.text = "Render Scale (viewport resolution)"
	vbox.add_child(render_scale_label)

	var render_scale_slider := HSlider.new()
	render_scale_slider.min_value = 0.5
	render_scale_slider.max_value = 2.0
	render_scale_slider.step = 0.05
	render_scale_slider.value = get_viewport().scaling_3d_scale
	render_scale_slider.custom_minimum_size = Vector2(280, 20)
	render_scale_slider.value_changed.connect(func(v): get_viewport().scaling_3d_scale = v)
	vbox.add_child(render_scale_slider)

	var res_label := Label.new()
	res_label.text = "Window Resolution"
	vbox.add_child(res_label)

	var resolution_dropdown := OptionButton.new()
	for res in resolution_options:
		resolution_dropdown.add_item("%dx%d" % [res.x, res.y])
	resolution_dropdown.custom_minimum_size = Vector2(280, 20)
	resolution_dropdown.item_selected.connect(_on_resolution_selected)
	vbox.add_child(resolution_dropdown)

	settings_menu.visible = false

func _on_resolution_selected(idx: int):
	var res: Vector2i = resolution_options[idx]
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(res)
	get_window().size = res

func _toggle_settings_menu():
	settings_open = !settings_open
	settings_menu.visible = settings_open
	if settings_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if focused else Input.MOUSE_MODE_VISIBLE)

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		focused = false
	if event is InputEventMouseButton:
		if event.button_index == 3:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			focused = true
		if not settings_open:
			if event.button_index == 5:
				$Head/Camera3D.fov *= zoom_sensitivity
			if event.button_index == 4:
				$Head/Camera3D.fov /= zoom_sensitivity
			
			var active_key = current_move_state
			if active_key == MoveState.IDLE:
				active_key = MoveState.WALK

			var active_node = move_nodes.get(active_key)
			if active_node and is_multiplayer_authority():
				active_node.visible = ($Head/Camera3D.fov >= 15.0)
				
			$Head/Camera3D.fov = clamp($Head/Camera3D.fov, 5, 360)


	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Y and is_multiplayer_authority():
		_toggle_settings_menu()
		return

	if settings_open:
		return

	if event is InputEventMouseButton:
		if event.button_index == 1:
			shooting = event.pressed
	if event is InputEventMouseMotion and focused:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta):
	$gun.rotation.x = -$Head.rotation.x
	$ProgressBar.value = health 

	if !is_multiplayer_authority():
		_process_remote_animation(delta)
		return
		
	if last_h > health:
		time_since_dmg = 0
	last_h = health
	time_since_dmg += delta
	if time_since_dmg < 2:
		$Head/Camera3D/CanvasLayer/ColorRect.material.set_shader_parameter("intensity", time_since_dmg)



	if shoot_cooldown > 0.0:
		shoot_cooldown -= delta

	if shooting and shoot_cooldown <= 0.0 and not settings_open:
		shoot()
		shoot_cooldown = fire_rate

	send_transform.rpc(global_position, rotation, $Head.rotation.x)


	
	
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var is_moving := direction.length() > 0.01

	var is_crouching := Input.is_action_pressed("crouch")
	var is_sprinting := Input.is_action_pressed("sprint")

	if is_crouching:
		speed = crouchspeed
	elif is_sprinting:
		speed = sprintspeed
	else:
		speed = normalspeed

	# --- Jump and Wall-Jump System ---
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		var normal = get_floor_normal()
		
		# If the angle of the surface is very steep, it's a wall (even if is_on_floor is true)
		if normal.y < 0.7:
			# Wall Jump: launch away from the wall normal and upwards
			velocity.x = normal.x * wall_jump_force
			velocity.z = normal.z * wall_jump_force
			velocity.y = wall_jump_up_force
		else:
			# Standard Jump
			velocity.y = jump_velocity * min(speed / float(normalspeed), 1.5)

	var desired_state := MoveState.IDLE
	if is_crouching:
		desired_state = MoveState.CROUCH
	elif is_moving:
		desired_state = MoveState.SPRINT if is_sprinting else MoveState.WALK

	_set_move_state(desired_state)

	# --- Fluid Air & Ground Movement ---
	# We use a lower interpolation rate in the air so we don't instantly kill wall jump momentum.
	var accel = 45.0 if is_on_floor() else air_control
	var deaccel = 45.0 if is_on_floor() else 2.0 # Slide nicely when key is released in air

	if is_moving:
		velocity.x = move_toward(velocity.x, direction.x * speed, accel * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deaccel * delta)
		velocity.z = move_toward(velocity.z, 0.0, deaccel * delta)

	# Reset upward velocity if we bump into ANY surface above us (including tilted ramps)
	if velocity.y > 0:
		for col_idx in range(get_slide_collision_count()):
			var collision := get_slide_collision(col_idx)
			# If the collision normal points downwards, we hit something above our head
			if collision.get_normal().y < -0.1:
				velocity.y = 0
				break

	if not is_on_floor():
		velocity.y -= gravity * delta
		
	move_and_slide()

func _process_remote_animation(delta):
	if remote_crouching:
		idle_timer = 0.0
		_set_move_state(MoveState.CROUCH)
		last_position = position
		return

	var dist = (position - last_position).length()
	var move_speed = dist / delta

	if move_speed > 0.05:
		idle_timer = 0.0
		var desired_state = MoveState.SPRINT if move_speed > (normalspeed + sprintspeed) * 0.5 else MoveState.WALK
		_set_move_state(desired_state)
	else:
		idle_timer += delta
		if idle_timer >= IDLE_GRACE:
			_set_move_state(MoveState.IDLE)

	last_position = position

func _set_move_state(new_state: MoveState) -> void:
	if new_state == current_move_state:
		return

	var old_state := current_move_state

	# Safely resolve target key, treating IDLE as using the WALK node
	var target_key = new_state
	if new_state == MoveState.IDLE:
		target_key = MoveState.WALK
		
	var active_node = move_nodes.get(target_key, null)
	var should_play := (new_state != MoveState.IDLE)

	for state_key in move_nodes:
		var node = move_nodes[state_key]
		if node != active_node:
			node.hide()
			if node.has_node("AnimationPlayer"):
				node.get_node("AnimationPlayer").stop()

	if active_node:
		active_node.show()
		if active_node.has_node("AnimationPlayer"):
			if should_play:
				active_node.get_node("AnimationPlayer").play(ANIM_NAME)
			else:
				active_node.get_node("AnimationPlayer").stop()

	if is_multiplayer_authority():
		if old_state == MoveState.CROUCH and new_state != MoveState.CROUCH:
			go_down.rpc(0)
		if new_state == MoveState.CROUCH and old_state != MoveState.CROUCH:
			go_down.rpc(1)

	current_move_state = new_state

@rpc("any_peer", "unreliable")
func send_transform(pos: Vector3, rot: Vector3, pitch: float):
	if is_multiplayer_authority():
		return

	global_position = pos
	rotation = rot
	$Head.rotation.x = pitch

func shoot():
	$AudioStreamPlayer3D.play()

	var spread_rad = deg_to_rad(spread_degrees)
	$gun/RayCast3D.rotation.x = randf_range(-spread_rad, spread_rad)
	$gun/RayCast3D.rotation.y = randf_range(-spread_rad, spread_rad)

	$gun/RayCast3D.force_raycast_update()

	var start = $gun.global_position
	var end = start + $gun/RayCast3D.global_transform.basis.z * 200.0

	if $gun/RayCast3D.is_colliding():
		var hit = $gun/RayCast3D.get_collider()
		if hit is CharacterBody3D:
			get_parent().get_parent().shoot_rpc.rpc_id(1, hit.get_multiplayer_authority())
			$AudioStreamPlayer3D2.play()
		end = $gun/RayCast3D.get_collision_point()

	$gun/RayCast3D.rotation = Vector3.ZERO
	spawn_tracer.rpc(start, end)

@rpc("any_peer", "call_local", "unreliable")
func spawn_tracer(start: Vector3, end: Vector3):
	var tracer = preload("res://Tracer.tscn").instantiate()
	add_child(tracer)
	tracer.setup(start, end)

func take_damage(amount: int):
	health -= amount
	update_health.rpc(health)

@rpc("any_peer", "call_local", "reliable")
func go_down(val):
	if val:
		$MeshInstance3D.position.y = -0.4
		$Head.position.y = 0.8
		$gun.position.y = -0.5
	else:
		$MeshInstance3D.position.y = 0
		$Head.position.y = 1.28
		$gun.position.y = 0.3

	if !is_multiplayer_authority():
		remote_crouching = bool(val)

@rpc("any_peer", "reliable")
func update_health(h):
	health = h
