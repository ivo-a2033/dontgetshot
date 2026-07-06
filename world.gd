extends Node3D

@export var player_scene: PackedScene

@onready var players = $AllPlayers

var player_nodes := {}

func _ready():
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	
@rpc("authority", "call_local", "reliable")
func spawn_player(id):
	if player_nodes.has(id):
		return

	var p = player_scene.instantiate()
	p.name = str(id)
	p.set_multiplayer_authority(id)

	players.add_child(p)
	player_nodes[id] = p

func _peer_connected(id):
	# Server creates the new player everywhere.
	spawn_player.rpc(id)

	# Then tell the new client about everyone that already exists.
	for pid in player_nodes.keys():
		if pid != id:
			spawn_player.rpc_id(id, pid)

func _peer_disconnected(id):
	if player_nodes.has(id):
		player_nodes[id].queue_free()
		player_nodes.erase(id)
