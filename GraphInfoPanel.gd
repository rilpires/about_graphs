extends Panel

var current_component = 0

func _ready():
	for child in $Labels.get_children():
		if child is Label:
			child.text = child.name + " :"

func _hovered_vertex_changed( graph : Graph ):
	call_deferred('_on_Graph_calculations_done',graph)

func _on_Graph_calculations_done( graph : Graph ):
	if( graph.hovered_vertex and graph.component_dict.has(graph.hovered_vertex.name) ):
		current_component = graph.component_dict[ graph.hovered_vertex.name ]
	if graph.edge_dict.size() > 0 :
		for child in $Labels.get_children():
			if child is Label:
				child.text = child.name + " : " + str( graph.get( child.name )[current_component] )
