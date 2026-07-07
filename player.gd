extends CharacterBody3D


var speed = 0
@export var sprintspeed := 12.0
@export var normalspeed := 8.0
@export var crouchspeed := 4.0

@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.0025

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var head = $Head
@onready var camera = $Head/Camera3D

var health = 100

func _ready():
	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		$Head/Camera3D.current = true
		$Head/Sketchfab_Scene2.hide()
	else:
		$Head/Camera3D.current = false	

func _unhandled_input(event):
	
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event is InputEventMouseButton:
		if event.button_index == 3:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
	if !is_multiplayer_authority():
		return
	if event is InputEventMouseButton:
		if event.button_index == 1 and event.pressed:
			shoot()
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
		


	

func _physics_process(delta):
	
	$gun.rotation.x = -$Head.rotation.x
	
	$Label3D.text = "♥".repeat(health / 20)	
	
	if !is_multiplayer_authority():
		return
		
	
	send_transform.rpc(global_position, rotation, $Head.rotation.x) # we can do this since we know by now we're multiplayer authority
	
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity
	if Input.is_action_pressed("sprint"):
		speed = sprintspeed
	elif Input.is_action_pressed("crouch"):
		speed = crouchspeed
		go_down.rpc(1)
	else:
		speed = normalspeed
		go_down.rpc(0)

		
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	var direction = (
		transform.basis * Vector3(input.x, 0, input.y)
	).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()
	
@rpc("any_peer", "unreliable")
func send_transform(pos: Vector3, rot: Vector3, pitch: float):
	if is_multiplayer_authority():
		return

	global_position = pos
	rotation = rot
	$Head.rotation.x = pitch

	
func shoot():
	$AudioStreamPlayer3D.play()
	$gun/RayCast3D.force_raycast_update()

	if $gun/RayCast3D.is_colliding():
		var hit = $gun/RayCast3D.get_collider()
		if hit and is_instance_of(hit, CharacterBody3D):
			get_parent().get_parent().shoot_rpc.rpc_id(1, hit.get_multiplayer_authority())
			
func take_damage(amount: int):
	health -= amount
	update_health.rpc(health)
	print("took dmg, so i")
	print(get_multiplayer_authority())
	
@rpc("any_peer", "call_local", "reliable")
func go_down(val):
	if val:
		$MeshInstance3D.position.y = -0.4
		$Head.position.y = 0.8
	else:
		$MeshInstance3D.position.y = 0
		$Head.position.y = 1.28

@rpc("any_peer", "reliable")
func update_health(h):
	health = h
