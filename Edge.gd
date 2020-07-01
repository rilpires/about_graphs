extends ColorRect


var vertex1 = null
var vertex2 = null


# Called when the vertex enters the scene tree for the first time.
func _ready():
	if vertex1 == null or vertex2 == null:
		queue_free()
	update_position()
	vertex1.connect("item_rect_changed",self,"update_position")
	vertex2.connect("item_rect_changed",self,"update_position")

func update_position():
	rect_rotation = 0
	rect_global_position = (vertex1.rect_global_position + vertex2.rect_global_position)*0.5 + vertex1.rect_size*0.5
	rect_size.x = (vertex1.rect_global_position - vertex2.rect_global_position).length()
	rect_size.y = 8
	rect_global_position -= rect_size*0.5
	rect_pivot_offset = rect_size*0.5
	rect_rotation = rad2deg( (vertex1.rect_global_position - vertex2.rect_global_position).angle() )


func _on_Edge_mouse_entered():
	use_parent_material = true

func _on_Edge_mouse_exited():
	use_parent_material = false

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index==BUTTON_MASK_RIGHT:
		var graph = get_parent()
		graph.removeEdge(vertex1,vertex2)
		graph.updateCalculations()









