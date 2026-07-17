extends RefCounted

const RESOLUTION_OPTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

# Automates the dynamic instantiation, scaling, rotation, and positioning of variant scenes
static func instantiate_move_nodes(player: CharacterBody3D, custom_paths: Dictionary, move_nodes: Dictionary) -> void:
	var path_map := {
		player.MoveState.WALK: custom_paths.get("walk", ""),
		player.MoveState.SPRINT: custom_paths.get("sprint", ""),
		player.MoveState.CROUCH: custom_paths.get("crouch", "")
	}

	var model_scale: float = custom_paths.get("scale", 1.0)

	for state in path_map:
		var path: String = path_map[state]
		if path != "":
			var scene = load(path)
			if scene:
				var instance = scene.instantiate()
				instance.scale = Vector3(model_scale, model_scale, model_scale)
				instance.rotation.y = PI
				instance.position.y = -1.0
				
				player.add_child(instance)
				instance.hide()
				move_nodes[state] = instance

	if move_nodes.has(player.MoveState.WALK):
		move_nodes[player.MoveState.WALK].show()

# Automates building the settings menu layout tree and wiring slider values directly to properties
static func build_settings_menu(player: CharacterBody3D) -> CanvasLayer:
	var menu = CanvasLayer.new()
	menu.layer = 10

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(340, 260)
	panel.position = Vector2(40, 40)
	menu.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(16, 16)
	vbox.custom_minimum_size = Vector2(308, 308)
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Settings (Y to close)"
	vbox.add_child(title)

	var mouse_label := Label.new()
	mouse_label.text = "Mouse Sensitivity"
	vbox.add_child(mouse_label)

	var mouse_sens_slider := HSlider.new()
	mouse_sens_slider.min_value = 0.0005
	mouse_sens_slider.max_value = 0.01
	mouse_sens_slider.step = 0.0001
	mouse_sens_slider.value = player.mouse_sensitivity
	mouse_sens_slider.custom_minimum_size = Vector2(280, 20)
	mouse_sens_slider.value_changed.connect(func(v): player.mouse_sensitivity = v)
	vbox.add_child(mouse_sens_slider)

	var zoom_label := Label.new()
	zoom_label.text = "Zoom Sensitivity"
	vbox.add_child(zoom_label)

	var zoom_sens_slider := HSlider.new()
	zoom_sens_slider.min_value = 1.02
	zoom_sens_slider.max_value = 2.0
	zoom_sens_slider.step = 0.01
	zoom_sens_slider.value = player.zoom_sensitivity
	zoom_sens_slider.custom_minimum_size = Vector2(280, 20)
	zoom_sens_slider.value_changed.connect(func(v): player.zoom_sensitivity = v)
	vbox.add_child(zoom_sens_slider)

	var render_scale_label := Label.new()
	render_scale_label.text = "Render Scale (viewport resolution)"
	vbox.add_child(render_scale_label)

	var render_scale_slider := HSlider.new()
	render_scale_slider.min_value = 0.5
	render_scale_slider.max_value = 2.0
	render_scale_slider.step = 0.05
	render_scale_slider.value = player.get_viewport().scaling_3d_scale
	render_scale_slider.custom_minimum_size = Vector2(280, 20)
	render_scale_slider.value_changed.connect(func(v): player.get_viewport().scaling_3d_scale = v)
	vbox.add_child(render_scale_slider)

	var res_label := Label.new()
	res_label.text = "Window Resolution"
	vbox.add_child(res_label)

	var resolution_dropdown := OptionButton.new()
	for res in RESOLUTION_OPTIONS:
		resolution_dropdown.add_item("%dx%d" % [res.x, res.y])
	resolution_dropdown.custom_minimum_size = Vector2(280, 20)
	resolution_dropdown.item_selected.connect(func(idx): 
		var res: Vector2i = RESOLUTION_OPTIONS[idx]
		var mode := DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(res)
		player.get_window().size = res
	)
	vbox.add_child(resolution_dropdown)

	return menu
