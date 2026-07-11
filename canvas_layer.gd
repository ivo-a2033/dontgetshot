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

func _on_join_pressed():
	print("join")
	var peer = ENetMultiplayerPeer.new()
	if ip_edit.text == "":
		var err = peer.create_client("192.168.1.72", 7777)
		print(err)
	else:
		peer.create_client(ip_edit.text, 7777)

	multiplayer.multiplayer_peer = peer
	is_server = false

	# FIX 4: Wait until we connect safely, then send our choice up to the server
	multiplayer.connected_to_server.connect(func():
		var lobby = get_parent()
		var chosen_paths = lobby.character_library[lobby.current_selected_index]
		lobby.tell_server_my_character.rpc(chosen_paths)
	)

	hide()
