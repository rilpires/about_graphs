class_name GraphVertex
extends TextureRect

var click_toggling = false
var dragging = false
var original_pos = Vector2(0,0)
var original_mouse_pos = Vector2()
var adjs_delta_angle = []
var speed = Vector2()
var accel = Vector2()

func _ready():
	_on_GraphVertex_mouse_entered()
	_on_GraphVertex_mouse_exited()

func _on_GraphVertex_mouse_entered():
	get_parent().setHoveredVertex(self)

func _on_GraphVertex_mouse_exited():
	if( get_parent().hovered_vertex==self ):
		get_parent().setHoveredVertex(null)
	dragging = false
	set_process(false)
	click_toggling = false

func _mouse_click():
	var graph = get_parent()
	if graph.clicked_vertex == null:
		graph.clicked_vertex = self
	elif graph.clicked_vertex != self:
		graph.toggleEdge(self,graph.clicked_vertex)
		graph.clicked_vertex = null
		graph.updateCalculations()
	elif graph.clicked_vertex == self:
		graph.clicked_vertex = null

func _gui_input(event):
	if( event is InputEventMouseButton):
		if event.button_index==BUTTON_LEFT:
			if event.is_pressed():
				click_toggling = true
				original_pos = rect_global_position
				original_mouse_pos = get_global_mouse_position()
				dragging = true
				set_process(true)
				#get_tree().set_input_as_handled() # It doesnt work as expected
			else:
				if click_toggling:
					_mouse_click()
					click_toggling = false
				dragging = false
				set_process(false)
				#get_tree().set_input_as_handled() # It doesnt work as expected
		elif event.button_index==BUTTON_RIGHT:
			if event.is_pressed():
				var graph = get_parent()
				graph.removeVertex(self)
				graph.updateCalculations()
		get_tree().set_input_as_handled()
	elif( event is InputEventMouseMotion ):
		if( dragging ):
			raise()
			var delta_pos = get_global_mouse_position() - original_mouse_pos
			rect_global_position = original_pos + get_global_mouse_position() - original_mouse_pos
			if( delta_pos.length_squared() > 2 ):
				click_toggling = false
				get_parent().update()

func _exit_tree():
	if get_parent().hovered_vertex == self:
		get_parent().hovered_vertex = null
		if get_parent().clicked_vertex == self:
			get_parent().clicked_vertex = null

