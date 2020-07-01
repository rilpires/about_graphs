extends Panel

func _ready():
	for child in $Labels.get_children():
		if child is Label:
			child.text = child.name + " :"

func _on_Graph_calculations_done( graph : Graph ):
	for child in $Labels.get_children():
		if child is Label:
			child.text = child.name + " : " + str( graph.get( child.name ) )
