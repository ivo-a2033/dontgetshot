extends CharacterBody3D

enum MoveState { IDLE, WALK, SPRINT, CROUCH }
const ANIM_NAME := "mixamo_com"

var speed = 0
@export var sprintspeed := 12.0
@export var normalspeed := 8.0
@export var crouchspeed := 4.0

@export var jump_velocity := 0
@export var mouse_sensitivity := 0.0025

# --- shooting ---
@export var fire_rate := 0.15  # seconds between shots while held
var shooting := false
var shoot_cooldown := 0.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * 2

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var jogging_node = $Jogging
@onready var fast_run_node = $"Fast Run"
@onready var crouching_node = $Crouching

var move_nodes := {}
var current_move_state := MoveState.IDLE

var health = 100
var last_position = Vector3.ZERO
var focused = true

var idle_timer := 0.0
const IDLE_GRACE := 0.5  # seconds of no movement before we call it idle

var remote_crouching := false  # set via go_down RPC, used only on non-authority peers


func _ready():
	move_nodes = {
		MoveState.WALK: jogging_node,
		MoveState.SPRINT: fast_run_node,
		MoveState.CROUCH: crouching_node,
	}
	for node in move_nodes.values():
		node.hide()
		node.get_node("AnimationPlayer").stop()

	# Idle default: jogging node visible, just not playing.
	jogging_node.show()

	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		$Head/Camera3D.current = true
	else:
		$Head/Camera3D.current = false


func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		focused = false
	if event is InputEventMouseButton:
		if event.button_index == 3:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			focused = true
		if event.button_index == 5:
			$Head/Camera3D.fov *= 1.2
		if event.button_index == 4:
			$Head/Camera3D.fov /= 1.2
		$Head/Camera3D.fov = clamp($Head/Camera3D.fov, 5, 360)
	if !is_multiplayer_authority():
		$Head/Camera3D/Label3D.hide()
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
	$Label3D.text = "♥".repeat(health / 20)

	if !is_multiplayer_authority():
		_process_remote_animation(delta)
		return

	if $gun/RayCast3D.is_colliding():
		$Head/Camera3D/Label3D.global_position = $gun/RayCast3D.get_collision_point()

	if shoot_cooldown > 0.0:
		shoot_cooldown -= delta

	if shooting and shoot_cooldown <= 0.0:
		shoot()
		shoot_cooldown = fire_rate

	send_transform.rpc(global_position, rotation, $Head.rotation.x)

	if not is_on_floor():
		velocity.y -= gravity * delta

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

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity * min(speed / float(normalspeed), 1.5)

	var desired_state := MoveState.IDLE
	if is_crouching:
		desired_state = MoveState.CROUCH
	elif is_moving:
		desired_state = MoveState.SPRINT if is_sprinting else MoveState.WALK

	_set_move_state(desired_state)

	if is_moving:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

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

	# IDLE's "node" is jogging_node itself, just not playing.
	var active_node = jogging_node
	var should_play := true
	match new_state:
		MoveState.WALK:
			active_node = jogging_node
		MoveState.SPRINT:
			active_node = fast_run_node
		MoveState.CROUCH:
			active_node = crouching_node
		MoveState.IDLE:
			active_node = jogging_node
			should_play = false

	for state_key in move_nodes:
		var node = move_nodes[state_key]
		if node != active_node:
			node.hide()
			node.get_node("AnimationPlayer").stop()

	active_node.show()
	if should_play:
		active_node.get_node("AnimationPlayer").play(ANIM_NAME)
	else:
		active_node.get_node("AnimationPlayer").stop()

	# Only the authority drives the crouch mesh-offset RPC; remotes just react to it.
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
	$gun/RayCast3D.force_raycast_update()

	var start = $gun.global_position
	var end = start + $gun.global_transform.basis.z * 200.0

	if $gun/RayCast3D.is_colliding():

		var hit = $gun/RayCast3D.get_collider()
		if hit is CharacterBody3D:
			get_parent().get_parent().shoot_rpc.rpc_id(1, hit.get_multiplayer_authority())
			end = $gun/RayCast3D.get_collision_point()

	spawn_tracer.rpc(start, end)

@rpc("any_peer", "call_local", "unreliable")
func spawn_tracer(start: Vector3, end: Vector3):
	var tracer = preload("res://Tracer.tscn").instantiate()
	get_tree().current_scene.add_child(tracer)
	tracer.setup(start, end)

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
