class_name Graph
extends Control

export (PackedScene) var vertex_res
export (PackedScene) var edge_res
export (Font) var font
var clicked_vertex = null setget setClickedVertex
var hovered_vertex = null setget setHoveredVertex
var available_vertex_names = []
var available_component_names = []

var next_vertex_index = 0
var next_component_index = 0

var edge_dict = {} # vertex -> vertex
var component_dict = {}  # vertex -> component
var dijkstra_dict = {} # [vertex,vertex] -> distance 
var sub_dijktras = {} # component -> dijkstra_dict
var eccentricities = {} # vertex -> eccentricity
var component_size = {} # component -> size
var radius = {} # component -> radius
var diameter = {} # component -> diameter
var centrality = {} # 
var wiener_index = {} # component -> wiender_index


signal calculations_done
signal hovered_vertex_changed

func _init():
	var label = Label.new()
	font = label.get_font("font").duplicate(true)
	label.free()
	
	available_vertex_names += ["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"]
	var alphabet_size = available_vertex_names.size()
	for i in [1,2,3]:
		for j in range(0,alphabet_size):
			available_vertex_names.push_back( available_vertex_names[j]+str(i) )
	available_component_names = available_vertex_names.duplicate()
	for i in range(0,available_component_names.size()):
		available_component_names[i] = "G" + available_component_names[i].to_lower()
	for i in range(0,10):
		var random_color = Color(1,0,0)
		random_color.h = rand_range(0,1)
		available_component_colors.push_back( random_color )

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
		hovered_vertex.modulate = Color(0.7,0.7,0.7)
	hovered_vertex=new_val
	if(hovered_vertex):
		hovered_vertex.set_process_input(true)
		hovered_vertex.modulate = Color(1.0,1.0,1.0)
	update()
	emit_signal("hovered_vertex_changed")

func setClickedVertex(new_val):
	if( clicked_vertex ):
		clicked_vertex.remove_child(clicked_vertex.get_node("Particles2D"))
	clicked_vertex = new_val
	if( clicked_vertex ):
		var new_inst = preload("res://VertexParticles.tscn").instance()
		clicked_vertex.add_child(new_inst)
		new_inst.position = clicked_vertex.rect_size * 0.5
	update()

func getNextVertexName() -> String:
	next_vertex_index += 1
	return available_vertex_names[ next_vertex_index-1 ]
func getNextComponentName() -> String:
	next_vertex_index += 1
	return available_vertex_names[ next_vertex_index-1 ]

func addVertex( global_pos : Vector2 ) -> GraphVertex:
	var new_inst = vertex_res.instance()
	var new_vertex_name = getNextVertexName()
	new_inst.name = new_vertex_name
	add_child( new_inst )
	new_inst.rect_global_position = global_pos - new_inst.rect_size*0.5
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
	if( vertex is String ): vertex = get_node(vertex)
	for edge in edge_dict[vertex.name]:
		if edge.vertex1==vertex:
			ret.append(edge.vertex2)
		else:
			ret.append(edge.vertex1)
	return ret

func updateCalculations() -> void:
	updateDijkstraDict()
	updateComponents()
	updateEccentricities()
	updateWienerIndex()
	updateCentrality()
	emit_signal("calculations_done")

# Also updates radius & diameter
func updateEccentricities():
	eccentricities = {}
	radius = {}
	diameter = {}
	for component_index in range( 0 , next_component_index ):
		var sub_dijkstra = sub_dijktras[component_index]
		var eccentricities_so_far = []
		for v_name in sub_dijkstra.keys():
			var eccentricity = sub_dijkstra[v_name].values().max()
			eccentricities[v_name] = eccentricity
			eccentricities_so_far.push_back(eccentricity)
		radius[component_index] = eccentricities_so_far.min()
		diameter[component_index] = eccentricities_so_far.max()

func updateWienerIndex():
	wiener_index = {}
	for component_index in range( 0 , next_component_index ):
		wiener_index[component_index] = 0
		var sub_dijkstra = sub_dijktras[component_index]
		var all_vertex_names = sub_dijkstra.keys()
		for v1 in all_vertex_names:
			for v2 in all_vertex_names:
				if(v1>=v2):continue
				wiener_index[component_index] += sub_dijkstra[v1][v2]
		wiener_index[component_index] *= 2.0

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

func updateComponents():
	component_dict = {}
	sub_dijktras = {}
	component_size = {}
	next_component_index = 0
	
	for v_name in edge_dict.keys():
		component_dict[v_name] = null
	
	var discovered_queue = []
	for v_name in component_dict.keys():
		if( component_dict[v_name]==null ):
			var current_component_index = next_component_index
			next_component_index += 1
			component_dict[v_name] = current_component_index
			discovered_queue.push_back(v_name)
			while( discovered_queue.size() ):
				var next_v_name = discovered_queue.pop_front()
				for v2_obj in getCloseVertex(next_v_name):
					var v2_name = v2_obj.name
					if( component_dict[v2_name] == null ):
						component_dict[v2_name] = current_component_index
						discovered_queue.push_back(v2_name)
	for v_name in edge_dict.keys():
		var component_color = available_component_colors[ component_dict[v_name] % available_component_colors.size() ]
		get_node(v_name).self_modulate = component_color
		for edge in edge_dict[v_name]:
			edge.self_modulate = lerp( Color.white , component_color , 0.4 )
	
	for i in range( 0 , next_component_index ):
		sub_dijktras[i] = _generate_sub_dijkstra(i)
		component_size[i] = sub_dijktras[i].size()

func updateCentrality():
	centrality = {}
	for c in range(0,next_component_index):
		for v_name in sub_dijktras[c].keys():
			var sum = 0.0
			for d in sub_dijktras[c][v_name].values():
				sum += d
			if( sum == 0 ):
				centrality[v_name] = 0
			else:
				centrality[v_name] = (sub_dijktras[c].size()-1) / sum

func _generate_sub_dijkstra( component_index ) -> Dictionary:
	if( component_index==0 and next_component_index==1 ): return dijkstra_dict
	var ret = {}
	var component_vertex = []
	for v_name in edge_dict.keys():
		if component_dict[v_name]==component_index:
			component_vertex.push_back(v_name)
	for v_name in component_vertex:
		ret[v_name] = {}
	for v1 in component_vertex:
		for v2 in component_vertex:
			ret[v1][v2] = dijkstra_dict[v1][v2]
			ret[v2][v1] = ret[v1][v2]
	return ret

var available_component_colors = [Color.red,Color.blue,Color.green,Color.yellow,Color.blueviolet,Color.beige,Color.turquoise,Color.aqua,Color.blanchedalmond]
func getComponentColor( component : int ):
	return available_component_colors[ component % available_component_colors.size() ]

func _draw():
	var tool_bar = get_node("../ToolBar")
	
	if hovered_vertex and clicked_vertex:
		draw_line(  hovered_vertex.rect_position+hovered_vertex.rect_size*0.5 , 
					clicked_vertex.rect_position+clicked_vertex.rect_size*0.5 , 
					Color(1,0,0,1) , 1 , true )
	
	if tool_bar.find_node("show_eccentricity").pressed:
		for vertex_name in edge_dict.keys():
			var eccentricity = str(eccentricities[vertex_name])
			var vertex = get_node(vertex_name)
			draw_string( font , vertex.rect_position, eccentricity , Color(1,1,1,1)  )
	elif tool_bar.find_node("show_centrality").pressed:
		for vertex_name in edge_dict.keys():
			var c = str( centrality[vertex_name]*100.0 ).substr(0,4) + '%'
			var vertex = get_node(vertex_name)
			draw_string( font , vertex.rect_position, c , Color(1,1,1,1)  )
			




