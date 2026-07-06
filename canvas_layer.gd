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
	get_parent().spawn_player(1)

	hide()

func _on_join_pressed():
	var peer = ENetMultiplayerPeer.new()
	if ip_edit.text == "":
		peer.create_client("192.168.1.72", 7777)
	else:
		peer.create_client(ip_edit.text, 7777)

	multiplayer.multiplayer_peer = peer
	is_server = false

	hide()
