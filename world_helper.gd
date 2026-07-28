extends RefCounted

const character_library := [
	{
		"walk": "res://jogging.tscn",
		"sprint": "res://fast_run.tscn",
		"crouch": "res://Crouching.tscn",
		"scale": 70.0,
	},
	{
		"walk": "res://jogging_miku.tscn",
		"sprint": "res://fast_run_miku.tscn",
		"crouch": "res://crawling_miku.tscn",
		"scale": 10.0
	},
	{
		"walk": "res://tripijog.tscn",
		"sprint": "res://tripirun.tscn",
		"crouch": "res://tripicrawl.tscn",
		"scale": 1.0
	},
	{
		"walk": "res://naruto_j.tscn",
		"sprint": "res://naruto_s.tscn",
		"crouch": "res://naruto_c.tscn",
		"scale": 100.0
	},
]

const map_library := [
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
	},
	{
		"name": "Industry",
		"path": "res://industrymap.tscn"
	},
	{
		"name": "Bridge",
		"path": "res://arenamap.tscn"
	},
	{
		"name": "Custom",
		"path": "res://handmademap.tscn"
	},
	
	{
		"name": "Tunnels",
		"path": "res://tunnels.tscn"
	}
]

# --- NEW: Weapon Library ---
const weapon_library := [
	{
		"name": "Auto",
		"path": "res://autogun.tscn",
		"fire_rate": 0.1,
		"spread": 2,
		"damage": 15,
		"is_automatic": true,
		"shots": 1
	},
	
	{
		"name": "Sniper",
		"path": "res://sniper.tscn",
		"fire_rate": 2,
		"spread": 0.02,
		"damage": 100,
		"is_automatic": false,
		"shots": 1
	},
	
	{
		"name": "Shotgun",
		"path": "res://shotgun.tscn",
		"fire_rate": .2,
		"spread": 10,
		"damage": 100,
		"is_automatic": false,
		"shots": 10

	}
	
]

static func build_lobby_ui(lobby: Node3D, canvas: CanvasLayer, cycle_char_callable: Callable, cycle_map_callable: Callable, cycle_weapon_callable: Callable) -> void:
	lobby.add_child(canvas)
	
	var char_hbox := HBoxContainer.new()
	char_hbox.position = Vector2(350, 50)
	canvas.add_child(char_hbox)
	
	var btn_prev := Button.new()
	btn_prev.text = " < "
	btn_prev.pressed.connect(cycle_char_callable.bind(-1))
	char_hbox.add_child(btn_prev)
	
	var label := Label.new()
	label.text = " Select Character "
	char_hbox.add_child(label)
	
	var btn_next := Button.new()
	btn_next.text = " > "
	btn_next.pressed.connect(cycle_char_callable.bind(1))
	char_hbox.add_child(btn_next)

	var map_hbox := HBoxContainer.new()
	map_hbox.position = Vector2(350, 100)
	canvas.add_child(map_hbox)
	
	var btn_map_prev := Button.new()
	btn_map_prev.text = " < "
	btn_map_prev.pressed.connect(cycle_map_callable.bind(-1))
	map_hbox.add_child(btn_map_prev)
	
	var map_label := Label.new()
	map_label.name = "MapLabel"
	map_label.text = " Select Map: " + map_library[lobby.current_map_index]["name"] + " "
	map_hbox.add_child(map_label)
	
	var btn_map_next := Button.new()
	btn_map_next.text = " > "
	btn_map_next.pressed.connect(cycle_map_callable.bind(1))
	map_hbox.add_child(btn_map_next)

	# --- NEW: Weapon Selection UI ---
	var weapon_hbox := HBoxContainer.new()
	weapon_hbox.position = Vector2(350, 150)
	canvas.add_child(weapon_hbox)
	
	var btn_weap_prev := Button.new()
	btn_weap_prev.text = " < "
	btn_weap_prev.pressed.connect(cycle_weapon_callable.bind(-1))
	weapon_hbox.add_child(btn_weap_prev)
	
	var weapon_label := Label.new()
	weapon_label.name = "WeaponLabel"
	weapon_label.text = " Select Weapon: " + weapon_library[lobby.current_weapon_index]["name"] + " "
	weapon_hbox.add_child(weapon_label)
	
	var btn_weap_next := Button.new()
	btn_weap_next.text = " > "
	btn_weap_next.pressed.connect(cycle_weapon_callable.bind(1))
	weapon_hbox.add_child(btn_weap_next)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	
	label.show_behind_parent = true
	label.add_theme_stylebox_override("normal", style)
	map_label.show_behind_parent = true
	map_label.add_theme_stylebox_override("normal", style)
	weapon_label.show_behind_parent = true
	weapon_label.add_theme_stylebox_override("normal", style)

	# Hand the label refs back to World so it doesn't have to rediscover
	# them later by scanning children for a matching position.
	lobby.map_label = map_label
	lobby.weapon_label = weapon_label

static func generate_preview_character(lobby: Node3D) -> Node3D:
	var char_data: Dictionary = character_library[lobby.current_selected_index]
	var model_scale: float = char_data.get("scale", 1.0)
	var preview_player: Node3D = lobby.player_scene.instantiate()
	
	var nodes_to_free := [
		"MeshInstance3D", "ProgressBar", "gun", "OmniLight3D",
		"AudioStreamPlayer3D", "AudioStreamPlayer3D2",
		"Head/Camera3D/CanvasLayer", "Head/Camera3D/Label3D"
	]
	for path in nodes_to_free:
		if preview_player.has_node(path):
			preview_player.get_node(path).free()
	
	preview_player.set_script(null)
	lobby.add_child(preview_player)
	
	if preview_player.has_node("Head/SpringArm3D/Camera3D"):
		preview_player.get_node("Head/SpringArm3D/Camera3D").current = true
	
	var base_walk_node: Node3D = null
	
	for key in ["walk", "sprint", "crouch"]:
		var path: String = char_data.get(key, "")
		if path != "":
			var scene = load(path)
			if scene:
				var mesh_instance: Node3D = scene.instantiate()
				mesh_instance.scale = Vector3(model_scale, model_scale, model_scale)
				mesh_instance.rotation.y = 0
				mesh_instance.position.y = 0
				
				if key != "walk":
					mesh_instance.hide()
				else:
					base_walk_node = mesh_instance
					if mesh_instance.has_node("AnimationPlayer"):
						mesh_instance.get_node("AnimationPlayer").play("mixamo_com")
						
				preview_player.add_child(mesh_instance)

	# --- NEW: Attach Weapon Preview to character model ---
	var weapon_data: Dictionary = weapon_library[lobby.current_weapon_index]
	var weapon_path: String = weapon_data.get("path", "")
	if weapon_path != "" and base_walk_node:
		var weapon_scene = load(weapon_path)
		if weapon_scene:
			var weapon_instance = weapon_scene.instantiate()
			weapon_instance.scale *= .005
			weapon_instance.rotation.y = PI/2
			weapon_instance.position.x -= 0.5
			weapon_instance.position.y = 1
			# Tries to find a designated hand bone attachment or defaults to mesh base layout
			
			preview_player.add_child(weapon_instance)

	preview_player.position = Vector3(0, 1.0, -5)
	return preview_player
