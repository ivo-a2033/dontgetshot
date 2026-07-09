extends Node3D

@export var player_scene: PackedScene

@onready var players = $AllPlayers

var player_nodes := {}
var timer = 0

func _ready():
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	
func _physics_process(delta: float) -> void:
	timer += delta
	if timer > 3 and is_multiplayer_authority():
		timer = 0
		change_sun.rpc($DirectionalLight3D.rotation.x)	
	
	$DirectionalLight3D.rotation.x += 5.0/180.0*PI / 3.0 * delta
	$DirectionalLight3D.light_energy = max(0,-sin($DirectionalLight3D.rotation.x))
	
		
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

@rpc("any_peer", "call_local", "reliable")
func shoot_rpc(hit_id: int):
	if player_nodes.has(hit_id):
		player_nodes[hit_id].take_damage(10)
	
@rpc("any_peer", "call_local", "reliable")
func change_sun(pos: float):
	$DirectionalLight3D.rotation.x = pos
