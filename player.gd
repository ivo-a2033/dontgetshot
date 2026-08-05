extends CharacterBody3D

enum MoveState { IDLE, WALK, SPRINT, CROUCH }
const ANIM_NAME := "mixamo_com"
const SetupHelper := preload("res://player_helper.gd")

var use_custom_anim_names := false  

const ANIM_JOG := "Jog_Fwd"
const ANIM_CRAWL := "Crawl"
const ANIM_RUN := "Run Anime"

# --- Dynamic Path Config ---
var custom_paths := {
	"walk": "",
	"sprint": "",
	"crouch": "",
	"scale": 1.0,
	"weapon_path": "",        # --- Added ---
	"weapon_fire_rate": 0.1,  # --- Added ---
	"weapon_spread": 0.0,     # --- Added ---
	"weapon_damage": 1,       # --- Added ---
	"weapon_auto": false,      # --- Added ---
	"shots": 1,
	"recoil": 0
}

var speed = 0
@export var sprintspeed := 12.0
@export var normalspeed := 8.0
@export var crouchspeed := 4.0
@export var spread_degrees := .2
@export var recoil := 0.0

@export var jump_velocity := 0
@export var mouse_sensitivity := 0.0025
@export var zoom_sensitivity := 1.05

@export var air_control := 5.0
var increasing_speed_rate = 4
var speed_ceiling = 12.0
var speed_mod = 0.0


# --- shooting ---
@export var fire_rate := 0.1
var shooting := false
var shoot_cooldown := 0.0

# --- Temporary Collision Disable (Phasing) ---
@export var collision_disable_duration := .05
var collision_disable_timer := 0.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * 2.5

@onready var head = $Head
@onready var camera = $Head/SpringArm3D/Camera3D
var raycast

var move_nodes := {}
var current_move_state := MoveState.IDLE

var health = 1000
var last_h = health
var last_position = Vector3.ZERO
var focused = true
var time_since_dmg = 10

var idle_timer := 0.0
const IDLE_GRACE := 0.5

var remote_crouching := false
@export var max_aim_distance := 500000.0

# --- settings menu ---
var settings_open := false
var settings_menu: CanvasLayer
var weapon_instance

var aim
var coyote = false
var coyote_count = 0
var normals_list = []
var sight_on = false
var wing_fuel = 100
var gun_flipped = false
var recoil_effect = 0
var label_scene = load("label.tscn")
func _ready():
	
	$wings.get_node("AnimationPlayer").play("Take 001")
	$Head/SpringArm3D.add_excluded_object(get_rid())
	
	$AudioStreamPlayer3D.max_polyphony = 10
	
	SetupHelper.instantiate_move_nodes(self, custom_paths, move_nodes)

	# --- NEW: Instantiate Weapon Model for Everyone ---
	
	for i in get_children():
		if "sasuke" in i.name:
			use_custom_anim_names = true
	
	if custom_paths["shots"] > 1:
		$AudioStreamPlayer3D.stream = load("res://shotgunshot.mp3")
	var weapon_path: String = custom_paths.get("weapon_path", "")
	if weapon_path != "":
		var weapon_scene = load(weapon_path)
		if weapon_scene:
			weapon_instance = weapon_scene.instantiate()
			weapon_instance.scale *= .005
			weapon_instance.rotation.y = -PI/2
			weapon_instance.position.x += 0.5
			# Attach it to your gun pivot node
			weapon_instance.name = "gun"

			add_child(weapon_instance)
			raycast = RayCast3D.new()
			raycast.target_position.x = -1000000000
			weapon_instance.add_child(raycast)
			weapon_instance.force_update_transform()
			raycast.force_update_transform()
			
	var start = raycast.global_position
	var end = raycast.global_position + raycast.global_transform.basis.z * raycast.target_position.x	
	aim = spawn_tracer(start, end, true)
	add_child(aim)
	# --- NEW: Override Exported Weapon Stats with Custom Paths ---
	fire_rate = custom_paths.get("weapon_fire_rate", fire_rate)
	spread_degrees = custom_paths.get("weapon_spread", spread_degrees)
	recoil = custom_paths["recoil"]

	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		$Head/SpringArm3D/Camera3D.current = true
		settings_menu = SetupHelper.build_settings_menu(self)
		add_child(settings_menu)
		settings_menu.visible = false
	else:
		aim.hide()
		$Head/SpringArm3D/Camera3D.current = false
		$ProgressBar.hide()

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
				$Head/SpringArm3D/Camera3D.fov *= zoom_sensitivity
			if event.button_index == 4:
				$Head/SpringArm3D/Camera3D.fov /= zoom_sensitivity
			
			
				
			$Head/SpringArm3D/Camera3D.fov = clamp($Head/SpringArm3D/Camera3D.fov, 5, 360)

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Y and is_multiplayer_authority():
		_toggle_settings_menu()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_O and is_multiplayer_authority():
		$Head/SpotLight3D.visible = not $Head/SpotLight3D.visible
		send_extra.rpc($Head/SpotLight3D.visible, $wings.visible, gun_flipped)

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q and is_multiplayer_authority():
		sight_on = not sight_on
		$Head/SpringArm3D/Camera3D/sight2.visible = sight_on
		if sight_on:
			#$Head.position.z = -40
			spread_degrees = custom_paths.get("weapon_spread", spread_degrees) * .2
			$Head/SpringArm3D/Camera3D.fov = 15
			
		else:
			#$Head.position.z = -0.4
			spread_degrees = custom_paths.get("weapon_spread", spread_degrees)
			$Head/SpringArm3D/Camera3D.fov = 75
			
		var active_key = current_move_state
		if active_key == MoveState.IDLE:
			active_key = MoveState.WALK
		var active_node = move_nodes.get(active_key)
		if active_node and is_multiplayer_authority():
			active_node.visible = ($Head/SpringArm3D/Camera3D.fov >= 25.0)

	if settings_open:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H and is_multiplayer_authority():
		if collision_disable_timer <= 0.0 and has_node("CollisionShape3D"):
			$CollisionShape3D.disabled = true
			collision_disable_timer = collision_disable_duration

	if event is InputEventMouseButton:
		if event.button_index == 1:
			shooting = event.pressed
	if event is InputEventMouseMotion and focused:
		var mod_sensitive = mouse_sensitivity
		if sight_on:
			mod_sensitive = mouse_sensitivity * .25
		else:
			mod_sensitive = mouse_sensitivity
		rotate_y(-event.relative.x * mod_sensitive)
		head.rotate_x(-event.relative.y * mod_sensitive)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta):
	
	var active_key = current_move_state
	if active_key == MoveState.IDLE:
		active_key = MoveState.WALK

	var active_node = move_nodes.get(active_key)
	if active_node and is_multiplayer_authority():
		active_node.visible = ($Head/SpringArm3D/Camera3D.fov >= 25.0)

	if wing_fuel < 100:
		wing_fuel += delta * 10.0
		
	$ProgressBar2.value = wing_fuel
	
	if raycast == null:
		return 
		
	$ProgressBar.value = health * .1
	weapon_instance.rotation.z = -$Head.rotation.x 
	


	
	
	
	if !is_multiplayer_authority():
		_process_remote_animation(delta)
		return
		
	
	var camera_forward = -camera.global_transform.basis.z
	var target_point = camera.global_position + (camera_forward * max_aim_distance)

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(camera.global_position, target_point)
	query.exclude = [get_rid()]
	var result = space_state.intersect_ray(query)

	if not result.is_empty():
		target_point = result.position

	# Single source of truth for both the visual line and the pitch tracking
	aim.update_line(raycast.global_position, target_point)

	var gun_to_target = target_point - weapon_instance.global_position
	var player_forward = -global_transform.basis.z
	var horizontal_dist = gun_to_target.dot(player_forward)
	var vertical_dist = gun_to_target.y
	var target_pitch = atan2(vertical_dist, horizontal_dist)
	#weapon_instance.rotation.z = -target_pitch
		

	
	if last_h > health:
		time_since_dmg = 0
	last_h = health
	time_since_dmg += delta
	if time_since_dmg < 2:
		$Head/SpringArm3D/Camera3D/CanvasLayer/ColorRect.material.set_shader_parameter("intensity", time_since_dmg)

	if collision_disable_timer > 0.0:
		collision_disable_timer -= delta
		if collision_disable_timer <= 0.0 and has_node("CollisionShape3D"):
			$CollisionShape3D.disabled = false

	if shoot_cooldown > 0.0:
		shoot_cooldown -= delta

	if shooting and shoot_cooldown <= 0.0 and not settings_open:
		for i in range(custom_paths["shots"]):
			shoot(target_point)
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

	

	var desired_state := MoveState.IDLE
	if is_crouching:
		desired_state = MoveState.CROUCH
	elif is_moving:
		desired_state = MoveState.SPRINT if is_sprinting else MoveState.WALK

	_set_move_state(desired_state)

	var accel = 90.0 if is_on_floor() else air_control
	var deaccel = 45.0 if is_on_floor() else 2.0

	if is_moving:
		velocity.x = move_toward(velocity.x, direction.x * (speed+speed_mod), accel * delta)
		velocity.z = move_toward(velocity.z, direction.z * (speed+speed_mod), accel * delta)
		if speed+speed_mod < speed_ceiling:
			speed_mod += increasing_speed_rate * delta
	else:
		velocity.x = move_toward(velocity.x, 0.0, deaccel * delta)
		velocity.z = move_toward(velocity.z, 0.0, deaccel * delta)
	
	if !is_sprinting:
		speed_mod = 0

	if velocity.y > 0:
		for col_idx in range(get_slide_collision_count()):
			var collision := get_slide_collision(col_idx)
			if collision.get_normal().y < -.1:
				#velocity.y = 0
				break

	if not is_on_floor():
		velocity.y -= gravity * delta
		
	if is_moving:
		var slide_normal := get_floor_normal()
		var horizontal_dir := Vector3(direction.x, 0.0, direction.z).normalized()
		
		# Project our original input direction onto the wall surface
		#if slide_normal.length_squared() != 0:
			#var wall_tangent := horizontal_dir.slide(slide_normal).normalized()
			#
			#if wall_tangent.length() > 0.001:
				#velocity.x = wall_tangent.x * (speed+speed_mod)
				#velocity.z = wall_tangent.z *( speed+speed_mod)
			
			
	normals_list.append(get_floor_normal())
	if len(normals_list) > 0.1 / delta:
		normals_list.remove_at(0)
	var sum = Vector3.ZERO
	for n in normals_list:
		sum += n
	var normal = sum/len(normals_list)
	
	if Input.is_action_just_pressed("ui_accept") and coyote:
		velocity.y = jump_velocity * min(speed / float(normalspeed), 1.5)


	if is_on_floor():
		coyote_count = .2
		$wings.hide()
		send_extra.rpc($Head/SpotLight3D.visible, $wings.visible, gun_flipped)

	else:
		coyote_count -= delta
		
	coyote = coyote_count > 0
	if Input.is_action_just_pressed("r") and coyote and wing_fuel >= 100:
		velocity.y = jump_velocity * min(speed / float(normalspeed), 1.5) * 3
		$wings.show()
		wing_fuel = 0
		send_extra.rpc($Head/SpotLight3D.visible, $wings.visible, gun_flipped)

	if sight_on:
		velocity.x *= 0.8
		velocity.z *= 0.8	
	move_and_slide()
	
	var other = null
	for i in get_parent().get_children():
		if self != i:
			other = i
	if other:
		$Label.text = "YOU:" + str(health) + "ENEMY: " + str(other.health)
	
	if Input.is_action_just_pressed("e"):
		get_node("gun").position.x *= -1
		gun_flipped = not gun_flipped
		send_extra($Head/SpotLight3D.visible, $wings.visible, gun_flipped)

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
				var anim_to_play = ANIM_NAME
				if use_custom_anim_names:
					match target_key:
						MoveState.SPRINT:
							anim_to_play = ANIM_RUN
						MoveState.CROUCH:
							anim_to_play = ANIM_CRAWL
						_:
							anim_to_play = ANIM_JOG
				active_node.get_node("AnimationPlayer").play(anim_to_play)
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
	
@rpc("any_peer", "unreliable")
func send_extra(light: bool, wings: bool, gun_flipped: bool):
	if is_multiplayer_authority():
		return

	$Head/SpotLight3D.visible = light
	$wings.visible = wings
	if gun_flipped:
		get_node("gun").position.x = abs(get_node("gun").position.x )* -1
	else:
		get_node("gun").position.x = abs(get_node("gun").position.x )

func shoot(target_point: Vector3):
	
	$Head.rotation.x += recoil/180.0*PI * 5 * (1.0/float(custom_paths["shots"]))
	$Head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	$AudioStreamPlayer3D.play()

	var origin = raycast.global_position
	var forward = (target_point - origin).normalized()

	# Build a basis perpendicular to forward for spread
	var right = forward.cross(Vector3.UP).normalized()
	if right.length() < 0.01:
		right = forward.cross(Vector3.FORWARD).normalized()
	var up = right.cross(forward).normalized()

	var spread_rad = deg_to_rad(spread_degrees)
	var spread_dir = (forward
		+ right * randf_range(-spread_rad, spread_rad)
		+ up * randf_range(-spread_rad, spread_rad)
	).normalized()

	var end = origin + spread_dir * max_aim_distance

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [get_rid()]
	var result = space_state.intersect_ray(query)

	var start = origin
	if not result.is_empty():
		end = result.position
		var hit = result.collider
		if hit is CharacterBody3D:
			if "Doll" in hit.name:
				hit.take_damage(custom_paths.get("weapon_damage", 1))
			else:
				get_parent().get_parent().shoot_rpc.rpc_id(1, hit.get_multiplayer_authority())
				$AudioStreamPlayer3D2.play()
				var label = label_scene.instantiate()
				label.text = str(custom_paths.get("weapon_damage", 1))
				label.position = hit.position + Vector3(0,0,0) + Vector3(randf_range(-2,2), randf_range(-2,2), randf_range(-2,2))
				get_parent().get_parent().add_child(label)

	spawn_tracer.rpc(start, end)

@rpc("any_peer", "call_local", "unreliable")
func spawn_tracer(start: Vector3, end: Vector3, permanent=false):
	var tracer = preload("res://Tracer.tscn").instantiate()
	if not permanent:
		add_child(tracer)
	#tracer.top_level = true   # <-- ignore parent's transform entirely
	tracer.setup(start, end, permanent)
	
	return tracer

func take_damage(amount: int):
	health -= amount
	update_health.rpc(health)

@rpc("any_peer", "call_local", "reliable")
func go_down(val):
	if val:
		$MeshInstance3D.position.y = -0.4
		$Head.position.y = 0.8
		if has_node("Head/SpringArm3D/Camera3D/gun"):
			$Head/SpringArm3D/Camera3D/gun.position.y = -0.5
	else:
		$MeshInstance3D.position.y = 0
		$Head.position.y = 1.28
		if has_node("Head/SpringArm3D/Camera3D/gun"):
			$Head/SpringArm3D/Camera3D/gun.position.y = 0.3

	if !is_multiplayer_authority():
		remote_crouching = bool(val)

@rpc("any_peer", "reliable")
func update_health(h):
	health = h
