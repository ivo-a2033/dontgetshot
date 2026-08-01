extends Label3D


var time = 0

func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	position.y += delta * 30
	time += delta
	if time > 2:
		queue_free()
