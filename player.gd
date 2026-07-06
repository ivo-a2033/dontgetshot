extends CharacterBody3D

@export var speed := 6.0
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
	else:
		$Head/Camera3D.current = false	

func _unhandled_input(event):
	
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if !is_multiplayer_authority():
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
		

	

func _physics_process(delta):
	
	$gun.rotation.x = -$Head.rotation.x
	
	if $gun/RayCast3D.get_collider_rid() != null:
			print($gun/RayCast3D.get_collider_rid())
	
	if !is_multiplayer_authority():
		return
	
	if is_multiplayer_authority():
		send_transform.rpc(global_position, rotation, $Head.rotation.x)
	
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

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
	
@rpc("any_peer", "reliable")
func take_damage(amount: int):
	health -= amount
