extends Control

signal redraw_graph

func _ready():
	for child in get_node("HBox").get_children():
		child.connect( "pressed" , self , "emit_signal" , ["redraw_graph"] )
