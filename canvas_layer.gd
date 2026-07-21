extends CanvasLayer

var is_server := false

@onready var ip_edit = $IPEdit

func _ready():
	$Host.pressed.connect(_on_host_pressed)
	$Join.pressed.connect(_on_join_pressed)

func _on_host_pressed():
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(7777)

	multiplayer.multiplayer_peer = peer
	is_server = true
	
	var lobby = get_parent()
	
	# --- FIX: Send the combined lobby custom_paths instead of just character library data ---
	var chosen_paths = lobby.custom_paths
	
	var default_map_node = lobby.get_node_or_null("Map1")
	if default_map_node:
		default_map_node.queue_free()
		
	if lobby.preview_map:
		lobby.preview_map.queue_free()
		lobby.preview_map = null

	var map_data = lobby.LobbyHelper.map_library[lobby.current_map_index]
	var map_scene = load(map_data["path"])
	var active_map = map_scene.instantiate()
	active_map.name = "ActiveMap"
	lobby.add_child(active_map)

	lobby.spawn_player(1, chosen_paths)

	hide()
	
	if active_map.has_method("init_world"):
		active_map.init_world()

func _on_join_pressed():
	print("join")
	var peer = ENetMultiplayerPeer.new()
	if ip_edit.text == "":
		peer.create_client("192.168.1.72", 7777)
	else:
		peer.create_client(ip_edit.text, 7777)

	peer.get_peer(1).set_timeout(0, 0, 2000)

	multiplayer.multiplayer_peer = peer
	is_server = false

	multiplayer.connected_to_server.connect(func():
		var lobby = get_parent()
		
		if lobby.preview_map:
			lobby.preview_map.queue_free()
			lobby.preview_map = null
			
		# --- FIX: Pass the combined paths dictionary here too ---
		var chosen_paths = lobby.custom_paths
		
		# Send character AND weapon selection to server
		lobby.tell_server_my_character.rpc(chosen_paths)
	)

	multiplayer.connection_failed.connect(func():
		multiplayer.multiplayer_peer = null
		show()
	)

	hide()
