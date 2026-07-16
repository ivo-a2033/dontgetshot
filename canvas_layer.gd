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
	var chosen_paths = lobby.character_library[lobby.current_selected_index]
	
	# The host spawns directly via the main function
	lobby.spawn_player(1, chosen_paths)

	hide()
	get_parent().get_node("Map1").init_world()

func _on_join_pressed():
	print("join")
	var peer = ENetMultiplayerPeer.new()
	if ip_edit.text == "":
		peer.create_client("192.168.1.72", 7777)
	else:
		peer.create_client(ip_edit.text, 7777)

	# Set the peer timeout: (peer_id=1 is the server, min_timeout=0, max_timeout=2000ms)
	peer.get_peer(1).set_timeout(0, 0, 2000)

	multiplayer.multiplayer_peer = peer
	is_server = false

	multiplayer.connected_to_server.connect(func():
		var lobby = get_parent()
		var chosen_paths = lobby.character_library[lobby.current_selected_index]
		lobby.tell_server_my_character.rpc(chosen_paths)
	)

	multiplayer.connection_failed.connect(func():
		multiplayer.multiplayer_peer = null
		show()
	)

	hide()
