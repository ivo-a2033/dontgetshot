extends Node3D

@export var player_scene: PackedScene
@onready var players = $AllPlayers

const LobbyHelper := preload("res://world_helper.gd")

var player_nodes := {}
var timer = 0

var current_selected_index := 0
var current_map_index := 0
var current_weapon_index := 0 
var custom_paths := {
	"weapon_path": "",
	"weapon_fire_rate": 0.1,
	"weapon_spread": 0.0,
	"weapon_damage": 1,
	"weapon_auto": false
}
var preview_player: Node3D = null
var preview_map: Node3D = null

func _ready():
	$Button.pressed.connect(reset_to_lobby)
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	
	LobbyHelper.build_lobby_ui(self, $CanvasLayer, _cycle_character, _cycle_map, _cycle_weapon)
	
	# Force initialization of custom_paths with index 0 data on startup
	_cycle_character(0)
	_cycle_weapon(0)
	_spawn_preview_map()

func _physics_process(delta: float) -> void:
	
	if preview_player:
		preview_player.get_node("Head").rotate(Vector3(0,1,0), .01)
	timer += delta
	
	if timer > 3 and multiplayer.is_server():
		timer = 0
		print("A",  $WorldEnvironment.environment.background_energy_multiplier)
		change_sun.rpc($DirectionalLight3D.rotation.x, $DirectionalLight3D.light_energy, $WorldEnvironment.environment.background_energy_multiplier)    
		
	$DirectionalLight3D.rotation.x += 5.0/180.0*PI / 3.0 * delta
	$DirectionalLight3D.light_energy = max(0, -sin($DirectionalLight3D.rotation.x))

func _clear_preview():
	if preview_player:
		preview_player.queue_free()
		preview_player = null
	if preview_map:
		preview_map.queue_free()
		preview_map = null
		
@rpc("authority", "call_local", "reliable")
func spawn_player(id: int, paths: Dictionary, map_path: String = ""):
	if player_nodes.has(id):
		return

	if map_path != "" and not has_node("ActiveMap"):
		_clear_preview()
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

@rpc("any_peer", "call_local", "reliable")
func tell_server_my_character(paths: Dictionary, client_map_path: String = ""):
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	
	var host_map_path: String = LobbyHelper.map_library[current_map_index]["path"]
	spawn_player.rpc(sender_id, paths, host_map_path)
	
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

func _cycle_character(direction: int):
	current_selected_index += direction
	if current_selected_index < 0:
		current_selected_index = LobbyHelper.character_library.size() - 1
	elif current_selected_index >= LobbyHelper.character_library.size():
		current_selected_index = 0
		
	# --- FIX: Populate the character data into custom_paths ---
	var char_data = LobbyHelper.character_library[current_selected_index]
	custom_paths["walk"] = char_data.get("walk", "")
	custom_paths["sprint"] = char_data.get("sprint", "")
	custom_paths["crouch"] = char_data.get("crouch", "")
	custom_paths["scale"] = char_data.get("scale", 1.0)
	
	_spawn_preview_character()

func _cycle_map(direction: int):
	current_map_index += direction
	if current_map_index < 0:
		current_map_index = LobbyHelper.map_library.size() - 1
	elif current_map_index >= LobbyHelper.map_library.size():
		current_map_index = 0
		
	var map_label = null
	for child in $CanvasLayer.get_children():
		if child is HBoxContainer and child.position.y == 100:
			map_label = child.get_node_or_null("MapLabel")
			break
	
	if map_label:
		map_label.text = " Select Map: " + LobbyHelper.map_library[current_map_index]["name"] + " "
	_spawn_preview_map()

func _cycle_weapon(direction: int):
	current_weapon_index += direction
	if current_weapon_index < 0:
		current_weapon_index = LobbyHelper.weapon_library.size() - 1
	elif current_weapon_index >= LobbyHelper.weapon_library.size():
		current_weapon_index = 0
		
	var weapon_label = null
	for child in $CanvasLayer.get_children():
		if child is HBoxContainer and child.position.y == 150:
			weapon_label = child.get_node_or_null("WeaponLabel")
			break
	
	if weapon_label:
		weapon_label.text = " Select Weapon: " + LobbyHelper.weapon_library[current_weapon_index]["name"] + " "
	
	var weapon_data = LobbyHelper.weapon_library[current_weapon_index]
	custom_paths["weapon_path"] = weapon_data["path"]
	custom_paths["weapon_fire_rate"] = weapon_data["fire_rate"]
	custom_paths["weapon_spread"] = weapon_data["spread"]
	custom_paths["weapon_damage"] = weapon_data["damage"]
	custom_paths["weapon_auto"] = weapon_data["is_automatic"]
	custom_paths["shots"] = weapon_data["shots"]

	_spawn_preview_character()

func _spawn_preview_character():
	if preview_player:
		preview_player.queue_free()
	preview_player = LobbyHelper.generate_preview_character(self)

func _spawn_preview_map():
	if preview_map:
		preview_map.queue_free()
		
	var path: String = LobbyHelper.map_library[current_map_index].get("path", "")
	if path != "":
		var scene = load(path)
		if scene:
			preview_map = scene.instantiate()
			preview_map.position = Vector3.ZERO
			add_child(preview_map)

@rpc("any_peer", "call_local", "reliable")
func shoot_rpc(hit_id: int):
	var sender_id = multiplayer.get_remote_sender_id()
	var damage = 1
	if player_nodes.has(sender_id):
		damage = player_nodes[sender_id].custom_paths.get("weapon_damage", 1)
		
	if player_nodes.has(hit_id):
		player_nodes[hit_id].take_damage(damage)
		
@rpc("any_peer", "call_local", "reliable")
func change_sun(pos: float, light1, light2):
	$DirectionalLight3D.rotation.x = pos
	$DirectionalLight3D.light_energy = light1
	$WorldEnvironment.environment.background_energy_multiplier = light2
	
func reset_to_lobby():
	# Cleanly disconnect networking first
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

	get_tree().reload_current_scene()
