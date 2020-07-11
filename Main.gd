extends TabContainer


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	for child in get_children():
		var info_panel = child.get_node("InfoPanel")
		var graph_node = child.find_node("Graph")
		graph_node.connect("calculations_done",info_panel,"_on_Graph_calculations_done",[graph_node])
		graph_node.connect("hovered_vertex_changed",info_panel,"_hovered_vertex_changed",[graph_node])
		info_panel.find_node("show_eccentricity").connect("pressed",graph_node,"update")
		break

