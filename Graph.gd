class_name Graph
extends Control

export (PackedScene) var vertex_res
export (PackedScene) var edge_res
export (Font) var font

var clicked_vertex = null setget setClickedVertex
var hovered_vertex = null setget setHoveredVertex
var available_vertex_names = "ABCDEFGHIJKLMNOPQRSTUVWXZabcdefghijklmnopqrstuvwxyz"
var next_vertex_index = 0
var edge_dict = {}
var dijkstra_dict = {}
var eccentricities = {}
var radius = null
var diameter = null
var wiener_index = null
var fully_connected = false

signal calculations_done

func _init():
	var label = Label.new()
	font = label.get_font("font").duplicate(true)
	label.free()

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index==1 and event.is_pressed():
			var new_inst = addVertex( get_global_mouse_position() )
			if( clicked_vertex ):
				addEdge( clicked_vertex , new_inst )
				self.clicked_vertex=null
			updateCalculations()
			accept_event()
	

func setHoveredVertex(new_val):
	if(hovered_vertex):
		hovered_vertex.set_process_input(false)
		hovered_vertex.modulate = Color(0.5,0.5,0.5)
	hovered_vertex=new_val
	if(hovered_vertex):
		hovered_vertex.set_process_input(true)
		hovered_vertex.modulate = Color(1.0,1.0,1.0)
	update()

func setClickedVertex(new_val):
	if( clicked_vertex ):
		clicked_vertex.remove_child(clicked_vertex.get_child(0))
	clicked_vertex = new_val
	if( clicked_vertex ):
		var new_inst = preload("res://VertexParticles.tscn").instance()
		clicked_vertex.add_child(new_inst)
		new_inst.position = clicked_vertex.rect_size * 0.5
	update()

func getNextVertexName() -> String:
	next_vertex_index += 1
	return available_vertex_names.substr( next_vertex_index-1 , 1 )

func addVertex( global_pos : Vector2 ) -> GraphVertex:
	var new_inst = vertex_res.instance()
	var new_vertex_name = getNextVertexName()
	add_child( new_inst )
	new_inst.rect_global_position = global_pos - new_inst.rect_size*0.5
	new_inst.name = new_vertex_name
	edge_dict[new_vertex_name] = []
	return new_inst

func removeVertex( vertex ):
	var vertex_name
	if vertex is String:
		vertex_name = vertex
		vertex = get_node(vertex)
	else:
		vertex_name = vertex.name
	
	for edge in edge_dict[vertex_name]:
		var other_vertex = edge.vertex1
		if( other_vertex == vertex ): other_vertex = edge.vertex2
		edge_dict[other_vertex.name].erase(edge)
		edge.queue_free()
	edge_dict.erase(vertex_name)
	
	vertex.queue_free()

func toggleEdge( vertex1 , vertex2 ) -> void:
	if( edgeExists(vertex1,vertex2) ):
		removeEdge(vertex1,vertex2)
	else:
		addEdge(vertex1,vertex2)

func edgeExists( vertex1 , vertex2 ) -> bool :
	assert( edge_dict.has(vertex1.name) and edge_dict.has(vertex2.name) )
	assert( vertex1 != null and vertex2 != null and vertex1 != vertex2)
	for edge in edge_dict[vertex1.name]:
		if vertex2==edge.vertex1 or vertex2==edge.vertex2:
			return true
	return false

func addEdge( vertex1 , vertex2 ):
	var edge_inst = edge_res.instance()
	edge_inst.vertex1=vertex1
	edge_inst.vertex2=vertex2
	add_child(edge_inst)
	move_child(edge_inst,0)
	edge_dict[vertex1.name].append(edge_inst)
	edge_dict[vertex2.name].append(edge_inst)

func removeEdge( vertex1 , vertex2 ):
	var edge_inst = null
	for edge in edge_dict[vertex1.name]:
		if vertex2==edge.vertex1 or vertex2==edge.vertex2:
			edge_inst = edge
			break
	assert(edge_inst!=null)
	edge_dict[vertex1.name].erase(edge_inst)
	edge_dict[vertex2.name].erase(edge_inst)
	edge_inst.queue_free()

func getCloseVertex( vertex ) -> Array:
	var ret = [] 
	for edge in edge_dict[vertex.name]:
		if edge.vertex1==vertex:
			ret.append(edge.vertex2)
		else:
			ret.append(edge.vertex1)
	return ret

func updateCalculations() -> void:
	updateDijkstraDict()
	updateEccentricities()
	updateWienerIndex()
	emit_signal("calculations_done")

# Also updates radius & diameter
func updateEccentricities():
	eccentricities = {}
	var all_vertex_names = dijkstra_dict.keys()
	
	if( fully_connected ):
		for v1 in all_vertex_names:
			eccentricities[v1] = dijkstra_dict[v1].values().max()
		radius = eccentricities.values().min()
		diameter = eccentricities.values().max()
	else:
		for v1 in all_vertex_names:
			eccentricities[v1] = null
		radius = null
		diameter = null

func updateWienerIndex():
	if( fully_connected ):
		wiener_index = 0
		var all_vertex_names = dijkstra_dict.keys()
		for v1 in all_vertex_names:
			for v2 in all_vertex_names:
				if(v1>=v2):continue
				wiener_index += dijkstra_dict[v1][v2]
		wiener_index *= 2.0
	else:
		wiener_index = null

func updateDijkstraDict() -> void :
	var all_vertex_names = edge_dict.keys().duplicate()
	dijkstra_dict = {}
	for v1 in all_vertex_names:
		dijkstra_dict[v1] = {}
		for v2 in all_vertex_names:
			dijkstra_dict[v1][v2] = null
	for v1 in all_vertex_names:
		for edge in edge_dict[v1]:
			var v2 = edge.vertex1.name
			if v2==v1: v2 = edge.vertex2.name
			dijkstra_dict[v1][v2]=1
			dijkstra_dict[v2][v1]=1
		dijkstra_dict[v1][v1]=0
	
	for _step in range(0,all_vertex_names.size()):
		var got_updated = false
		for v1 in all_vertex_names:
			for v3 in all_vertex_names:
				if( v1>=v3 ): continue # Don't calculate it twice for each pair
				var current_min_dist = dijkstra_dict[v1][v3]
				if current_min_dist==null or current_min_dist>2: # It can't be better than 2 now
					for v2 in all_vertex_names:
						var d1 = dijkstra_dict[v1][v2]
						var d2 = dijkstra_dict[v2][v3]
						if d1 != null and d2 != null:
							if( current_min_dist==null or d1+d2<current_min_dist ):
								dijkstra_dict[v1][v3] = d1+d2
								dijkstra_dict[v3][v1] = dijkstra_dict[v1][v3]
								got_updated = true
								break
		if(got_updated==false):
			break
	
	fully_connected = true
	for v1 in all_vertex_names:
		for v2 in all_vertex_names:
			if(v1>v2):continue
			if dijkstra_dict[v1][v2]==null:
				fully_connected = false
				return

func _draw():
	var info_panel = get_node("../InfoPanel")
	if hovered_vertex and clicked_vertex:
		draw_line(  hovered_vertex.rect_position+hovered_vertex.rect_size*0.5 , 
					clicked_vertex.rect_position+clicked_vertex.rect_size*0.5 , 
					Color(1,0,0,1) , 1 , true )
	if info_panel.find_node("show_eccentricity").pressed:
		for vertex_name in edge_dict.keys():
			var eccentricity = str(eccentricities[vertex_name])
			var vertex = get_node(vertex_name)
			draw_string( font , vertex.rect_position, eccentricity , Color(1,1,1,1)  )
			




