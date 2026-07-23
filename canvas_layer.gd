extends CanvasLayer

# This node is a pure UI shell. It owns no game state and reaches into no
# other node. It only reports what the player did (signals) and exposes
# its own controls (ip text, slider values) for World to read/write.

signal host_requested
signal join_requested(ip: String)

var is_server := false

@onready var ip_edit = $IPEdit
@onready var h_slider = $HSlider
@onready var h_slider2 = $HSlider2

func _ready():
	$Host.pressed.connect(func(): host_requested.emit())
	$Join.pressed.connect(func(): join_requested.emit(ip_edit.text))

func set_sliders(bg_energy: float, light_energy: float) -> void:
	h_slider.value = bg_energy * 100
	h_slider2.value = light_energy * 100

func get_slider_ratios() -> Vector2:
	return Vector2(h_slider.value / 100.0, h_slider2.value / 100.0)
