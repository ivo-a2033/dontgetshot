extends Node3D

@export var player_scene: PackedScene
@onready var players = $AllPlayers

var player_nodes := {}
var timer = 0

var character_library := [
	{
		"walk": "res://jogging.tscn",
		"sprint": "res://fast_run.tscn",
		"crouch": "res://Crouching.tscn",
		"scale": 70,
	},
	{
		"walk": "res://jogging_miku.tscn",
		"sprint": "res://fast_run_miku.tscn",
		"crouch": "res://crawling_miku.tscn",
		"scale": 10
	},
	
	{
		"walk": "res://tripijog.tscn",
		"sprint": "res://tripirun.tscn",
		"crouch": "res://tripicrawl.tscn",
		"scale": 1
	},
]

var current_selected_index := 0
var preview_player: Node3D = null

func _ready():
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	
	_setup_lobby_ui()
	_spawn_preview_character()

func _physics_process(delta: float) -> void:
	timer += delta
	if timer > 3 and is_multiplayer_authority():
		timer = 0
		change_sun.rpc($DirectionalLight3D.rotation.x)    
		
	$DirectionalLight3D.rotation.x += 5.0/180.0*PI / 3.0 * delta
	$DirectionalLight3D.light_energy = max(0,-sin($DirectionalLight3D.rotation.x))

@rpc("authority", "call_local", "reliable")
func spawn_player(id: int, paths: Dictionary):
	if player_nodes.has(id):
		return

	var p = player_scene.instantiate()
	p.name = str(id)
	p.set_multiplayer_authority(id)
	p.custom_paths = paths

	players.add_child(p)
	p.position.z -= 10
	player_nodes[id] = p

	# Our own player just spawned — the lobby preview is no longer needed
	if id == multiplayer.get_unique_id():
		_clear_preview()

func _clear_preview():
	if preview_player:
		preview_player.queue_free()
		preview_player = null
		
@rpc("any_peer", "call_local", "reliable")
func tell_server_my_character(paths: Dictionary):
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	
	spawn_player.rpc(sender_id, paths)
	
	for pid in player_nodes.keys():
		if pid != sender_id:
			var existing_player = player_nodes[pid]
			spawn_player.rpc_id(sender_id, pid, existing_player.custom_paths)

func _peer_connected(id):
	if not multiplayer.is_server():
		return

func _peer_disconnected(id):
	if player_nodes.has(id):
		player_nodes[id].queue_free()
		player_nodes.erase(id)

# --- Lobby Selection UI & Preview Logic ---

func _setup_lobby_ui():
	var canvas = CanvasLayer.new()
	add_child(canvas)
	
	var hbox = HBoxContainer.new()
	hbox.position = Vector2(50, 50)
	canvas.add_child(hbox)
	
	var btn_prev = Button.new()
	btn_prev.text = " < "
	btn_prev.pressed.connect(_cycle_character.bind(-1))
	hbox.add_child(btn_prev)
	
	var label = Label.new()
	label.text = " Select Character "
	hbox.add_child(label)
	
	var btn_next = Button.new()
	btn_next.text = " > "
	btn_next.pressed.connect(_cycle_character.bind(1))
	hbox.add_child(btn_next)

func _cycle_character(direction: int):
	current_selected_index += direction
	
	if current_selected_index < 0:
		current_selected_index = character_library.size() - 1
	elif current_selected_index >= character_library.size():
		current_selected_index = 0
		
	_spawn_preview_character()

func _spawn_preview_character():
	if preview_player:
		preview_player.queue_free()
		
	var current_char_data = character_library[current_selected_index]
	var model_scale: float = current_char_data.get("scale", 1.0)
		
	preview_player = player_scene.instantiate()
	
	if preview_player.has_node("MeshInstance3D"): preview_player.get_node("MeshInstance3D").free()
	if preview_player.has_node("ProgressBar"): preview_player.get_node("ProgressBar").free()
	if preview_player.has_node("gun"): preview_player.get_node("gun").free()
	if preview_player.has_node("OmniLight3D"): preview_player.get_node("OmniLight3D").free()
	if preview_player.has_node("AudioStreamPlayer3D"): preview_player.get_node("AudioStreamPlayer3D").free()
	if preview_player.has_node("AudioStreamPlayer3D2"): preview_player.get_node("AudioStreamPlayer3D2").free()
	
	# Keep Head/Camera3D, but strip the in-game HUD hanging off it
	if preview_player.has_node("Head/Camera3D/CanvasLayer"):
		preview_player.get_node("Head/Camera3D/CanvasLayer").free()
	if preview_player.has_node("Head/Camera3D/Label3D"):
		preview_player.get_node("Head/Camera3D/Label3D").free()
	
	preview_player.set_script(null)
	add_child(preview_player)
	
	# Activate the preview's camera manually since the script (and its authority checks) is gone
	if preview_player.has_node("Head/Camera3D"):
		preview_player.get_node("Head/Camera3D").current = true
	
	# ... rest unchanged (loading walk/sprint/crouch meshes)
	
	# Safely build the library animations on top of it
	for key in ["walk", "sprint", "crouch"]:
		var path = current_char_data.get(key, "")
		if path != "":
			var scene = load(path)
			if scene:
				var mesh_instance = scene.instantiate()
				
				mesh_instance.scale = Vector3(model_scale, model_scale, model_scale)
				mesh_instance.rotation.y = 0
				mesh_instance.position.y = 0
				
				if key != "walk":
					mesh_instance.hide()
				else:
					if mesh_instance.has_node("AnimationPlayer"):
						mesh_instance.get_node("AnimationPlayer").play("mixamo_com")
						
				preview_player.add_child(mesh_instance)

	preview_player.position = Vector3(0, 1.0, -5)

@rpc("any_peer", "call_local", "reliable")
func shoot_rpc(hit_id: int):
	if player_nodes.has(hit_id):
		player_nodes[hit_id].take_damage(1)
		
@rpc("any_peer", "call_local", "reliable")
func change_sun(pos: float):
	$DirectionalLight3D.rotation.x = pos
