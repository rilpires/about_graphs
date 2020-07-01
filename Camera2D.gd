extends Camera2D

func _ready():
	pass # Replace with function body.

func _input(event):
	if( event is InputEventMouseMotion and Input.is_mouse_button_pressed(BUTTON_MIDDLE) ):
		position -= event.relative * zoom.x
		get_tree().set_input_as_handled()
	if( event is InputEventMouseButton and event.is_pressed() ):
		if( event.button_index==BUTTON_WHEEL_UP ):
			zoom /= 1.1
			get_tree().set_input_as_handled()
		elif( event.button_index==BUTTON_WHEEL_DOWN ):
			zoom *= 1.1
			get_tree().set_input_as_handled()
