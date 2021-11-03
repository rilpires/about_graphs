extends TabContainer


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	var info_panel = find_node("InfoPanel")
	var graph_node = find_node("Graph")
	var tool_bar = find_node("ToolBar")
	
	graph_node.connect("calculations_done",info_panel,"_on_Graph_calculations_done",[graph_node])
	graph_node.connect("hovered_vertex_changed",info_panel,"_hovered_vertex_changed",[graph_node])
	
	
	tool_bar.find_node("show_eccentricity").connect( "pressed" , graph_node , "update" )
	tool_bar.find_node("show_centrality").connect( "pressed" , graph_node , "update" )
	tool_bar.find_node("clear").connect( "pressed" , graph_node , "clearGraph" )
	
