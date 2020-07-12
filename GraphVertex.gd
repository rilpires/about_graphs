class_name GraphVertex
extends TextureRect

var click_toggling = false

func _ready():
	_on_GraphVertex_mouse_entered()
	_on_GraphVertex_mouse_exited()

func _on_GraphVertex_mouse_entered():
	get_parent().setHoveredVertex(self)

func _on_GraphVertex_mouse_exited():
	if( get_parent().hovered_vertex==self ):
		get_parent().setHoveredVertex(null)

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

func _input(event):
	if( event is InputEventMouseButton):
		if event.button_index==BUTTON_LEFT:
			if event.is_pressed():
				click_toggling = true
				#get_tree().set_input_as_handled() # It doesnt work as expected
			elif click_toggling:
				_mouse_click()
				#get_tree().set_input_as_handled() # It doesnt work as expected
		elif event.button_index==BUTTON_RIGHT:
			if event.is_pressed():
				var graph = get_parent()
				graph.removeVertex(self)
				graph.updateCalculations()

func get_drag_data(position):
	var control_preview = Control.new()
	control_preview.connect("item_rect_changed",self,"_control_preview_item_rect_changed",[control_preview,position])
	set_drag_preview(control_preview)
	return self;

func _control_preview_item_rect_changed(prev:Control,offset:Vector2):
	rect_global_position = get_global_mouse_position() - offset
	if( offset.length_squared() > 1 ):
		click_toggling = false
	raise()

func _exit_tree():
	if get_parent().hovered_vertex == self:
		get_parent().hovered_vertex = null
		if get_parent().clicked_vertex == self:
			get_parent().clicked_vertex = null

