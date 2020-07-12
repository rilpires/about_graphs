extends Panel

var current_component = 0
var component_template

func _ready():
	component_template = get_node("Components").get_child(0)
	component_template.get_parent().remove_child(component_template)

func _update_labels( g : Graph ):
	var components_to_show = []
	for c in g.component_size.keys():
		if g.component_size[c] >= 2:
			components_to_show.push_back(c)
	while( get_node("Components").get_child_count() > components_to_show.size() ):
		var to_delete = get_node("Components").get_child(0)
		to_delete.get_parent().remove_child(to_delete)
		to_delete.queue_free()
	while( get_node("Components").get_child_count() < components_to_show.size() ):
		get_node("Components").add_child( component_template.duplicate() )
	for c in components_to_show:
		var component_rect = get_node("Components").get_child( components_to_show.find(c) )
		component_rect.modulate = lerp( Color.white , g.getComponentColor(c) , 0.5 )
		var labels_parent = component_rect.get_node("labels")
		for child in labels_parent.get_children():
			child.text = beautify_name(child.name) + " : " + str( g.get( child.name )[c] )


func _hovered_vertex_changed( graph : Graph ):
	call_deferred('_on_Graph_calculations_done',graph)

func _on_Graph_calculations_done( graph : Graph ):
	_update_labels( graph )

func beautify_name( n : String ) -> String:
	n[0] = n[0].to_upper()
	return n.replace("_"," ")