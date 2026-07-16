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
	{
		"walk": "res://naruto_j.tscn",
		"sprint": "res://naruto_s.tscn",
		"crouch": "res://naruto_c.tscn",
		"scale": 100
	},
]

# --- NEW: Map Library ---
var map_library := [
	{
		"name": "Bunkers",
		"path": "res://shootermap3.tscn"
	},
	{
		"name": "Arena",
		"path": "res://lowpoly.tscn"
	},
	
	{
		"name": "Residential",
		"path": "res://fpsmap.tscn"
	},
	
	{
		"name": "Rings",
		"path": "res://map_2.tscn"
	}
]

var current_selected_index := 0
var current_map_index := 0

var preview_player: Node3D = null
var preview_map: Node3D = null

func _ready():
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	
	_setup_lobby_ui()
	_spawn_preview_character()
	_spawn_preview_map()

func _physics_process(delta: float) -> void:
	timer += delta
	if timer > 3 and is_multiplayer_authority():
		timer = 0
		change_sun.rpc($DirectionalLight3D.rotation.x)	
		
	$DirectionalLight3D.rotation.x += 5.0/180.0*PI / 3.0 * delta
	$DirectionalLight3D.light_energy = max(0,-sin($DirectionalLight3D.rotation.x))



func _clear_preview():
	if preview_player:
		preview_player.queue_free()
		preview_player = null
	if preview_map:
		preview_map.queue_free()
		preview_map = null
		
# --- CHANGE: Added map_path parameter to spawn_player ---
@rpc("authority", "call_local", "reliable")
func spawn_player(id: int, paths: Dictionary, map_path: String = ""):
	if player_nodes.has(id):
		return

	# --- NEW: If a client doesn't have the active map loaded, load it now ---
	if map_path != "" and not has_node("ActiveMap"):
		_clear_preview() # Safely free preview player and map
		var map_scene = load(map_path)
		if map_scene:
			var active_map = map_scene.instantiate()
			active_map.name = "ActiveMap"
			add_child(active_map)


	var p = player_scene.instantiate()
	p.name = str(id)
	p.set_multiplayer_authority(id)
	p.custom_paths = paths

	players.add_child(p)
	p.position.z -= 10
	player_nodes[id] = p

	if id == multiplayer.get_unique_id():
		_clear_preview()
		
	if multiplayer.is_server():
		var active_map = get_node_or_null("ActiveMap")
		if active_map and active_map.has_method("send_world_to_player"):
			active_map.send_world_to_player(id)

# --- CHANGE: Updated tell_server_my_character to receive and pass map_path ---
@rpc("any_peer", "call_local", "reliable")
func tell_server_my_character(paths: Dictionary, client_map_path: String = ""):
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	
	# The host knows the authoritative map path, so we use the host's selected map path
	var host_map_path = map_library[current_map_index]["path"]
	
	# Spawn the new player on all clients, forcing them to load the host's map
	spawn_player.rpc(sender_id, paths, host_map_path)
	
	# Send existing players (and the host's map path) to the newly connected peer
	for pid in player_nodes.keys():
		if pid != sender_id:
			var existing_player = player_nodes[pid]
			spawn_player.rpc_id(sender_id, pid, existing_player.custom_paths, host_map_path)

func _peer_connected(id):
	if not multiplayer.is_server():
		return

func _peer_disconnected(id):
	if player_nodes.has(id):
		player_nodes[id].queue_free()
		player_nodes.erase(id)

# --- Lobby Selection UI & Preview Logic ---

func _setup_lobby_ui():
	var canvas = $CanvasLayer
	add_child(canvas)
	
	# --- Character Selection HBox ---
	var char_hbox = HBoxContainer.new()
	char_hbox.position = Vector2(350, 50)
	canvas.add_child(char_hbox)
	
	var btn_prev = Button.new()
	btn_prev.text = " < "
	btn_prev.pressed.connect(_cycle_character.bind(-1))
	char_hbox.add_child(btn_prev)
	
	var label = Label.new()
	label.text = " Select Character "
	char_hbox.add_child(label)
	
	var btn_next = Button.new()
	btn_next.text = " > "
	btn_next.pressed.connect(_cycle_character.bind(1))
	char_hbox.add_child(btn_next)

	# --- Map Selection HBox ---
	var map_hbox = HBoxContainer.new()
	map_hbox.position = Vector2(350, 100)
	canvas.add_child(map_hbox)
	
	var btn_map_prev = Button.new()
	btn_map_prev.text = " < "
	btn_map_prev.pressed.connect(_cycle_map.bind(-1))
	map_hbox.add_child(btn_map_prev)
	
	var map_label = Label.new()
	map_label.name = "MapLabel"
	map_label.text = " Select Map: " + map_library[current_map_index]["name"] + " "
	map_hbox.add_child(map_label)
	
	var btn_map_next = Button.new()
	btn_map_next.text = " > "
	btn_map_next.pressed.connect(_cycle_map.bind(1))
	map_hbox.add_child(btn_map_next)
	
	# For Character Label:
	label.show_behind_parent = true
	label.add_theme_stylebox_override("normal", StyleBoxFlat.new())
	label.get_theme_stylebox("normal").bg_color = Color(0, 0, 0, 0.6) # Black with 60% opacity

	# For Map Label:
	map_label.show_behind_parent = true
	map_label.add_theme_stylebox_override("normal", StyleBoxFlat.new())
	map_label.get_theme_stylebox("normal").bg_color = Color(0, 0, 0, 0.6)

func _cycle_character(direction: int):
	current_selected_index += direction
	
	if current_selected_index < 0:
		current_selected_index = character_library.size() - 1
	elif current_selected_index >= character_library.size():
		current_selected_index = 0
		
	_spawn_preview_character()

func _cycle_map(direction: int):
	current_map_index += direction
	
	if current_map_index < 0:
		current_map_index = map_library.size() - 1
	elif current_map_index >= map_library.size():
		current_map_index = 0
		
	var map_label = $CanvasLayer.get_node_or_null("HBoxContainer2/MapLabel")
	if not map_label:
		for child in $CanvasLayer.get_children():
			if child is HBoxContainer and child.position.y == 100:
				map_label = child.get_node("MapLabel")
				break
	
	if map_label:
		map_label.text = " Select Map: " + map_library[current_map_index]["name"] + " "
		
	_spawn_preview_map()

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
	
	if preview_player.has_node("Head/Camera3D/CanvasLayer"):
		preview_player.get_node("Head/Camera3D/CanvasLayer").free()
	if preview_player.has_node("Head/Camera3D/Label3D"):
		preview_player.get_node("Head/Camera3D/Label3D").free()
	
	preview_player.set_script(null)
	add_child(preview_player)
	
	if preview_player.has_node("Head/Camera3D"):
		preview_player.get_node("Head/Camera3D").current = true
	
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

func _spawn_preview_map():
	if preview_map:
		preview_map.queue_free()
		
	var current_map_data = map_library[current_map_index]
	var path = current_map_data.get("path", "")
	if path != "":
		var scene = load(path)
		if scene:
			preview_map = scene.instantiate()
			preview_map.position = Vector3.ZERO
			add_child(preview_map)

@rpc("any_peer", "call_local", "reliable")
func shoot_rpc(hit_id: int):
	if player_nodes.has(hit_id):
		player_nodes[hit_id].take_damage(1)
		
@rpc("any_peer", "call_local", "reliable")
func change_sun(pos: float):
	$DirectionalLight3D.rotation.x = pos
