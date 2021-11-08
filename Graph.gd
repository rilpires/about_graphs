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

var using_sparse_algorithms = false
var edge_as_springs = true
var spring_length = 100
var edge_dict = {} # vertex -> [ edge , edge ,  .... ]

# calculated every "updateCalculations"
var component_dict = {}  # vertex -> component
var sub_asps = {} # component -> asp_dict(which is symmetrical [vertex][vertex]->distance)
var eccentricities = {} # vertex -> eccentricity
var edge_count = {} # component -> int(edge count)
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
	for i in [1,2,3,4,5]:
		for j in range(0,alphabet_size):
			available_vertex_names.push_back( available_vertex_names[j]+str(i) )
	available_component_names = available_vertex_names.duplicate()
	for i in range(0,available_component_names.size()):
		available_component_names[i] = "G" + available_component_names[i].to_lower()
	for _i in range(0,10):
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
	while( available_vertex_names[ next_vertex_index ] in edge_dict.keys() ):
		next_vertex_index += 1
		if( next_vertex_index >= available_vertex_names.size() ):
			return String(randi()%100000)
	
	return available_vertex_names[ next_vertex_index ]

func addVertex( global_pos : Vector2 , optional_name = null ) -> GraphVertex:
	var new_inst = vertex_res.instance()
	var new_vertex_name
	if optional_name:
		new_vertex_name = optional_name
	else:
		new_vertex_name = getNextVertexName()
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

func getCloseVertices( vertex ) -> Array:
	var ret = []
	if( vertex is String ): vertex = get_node(vertex)
	for edge in edge_dict[vertex.name]:
		if edge.vertex1==vertex:
			ret.append(edge.vertex2)
		else:
			ret.append(edge.vertex1)
	return ret

# Called every graph modification
func updateCalculations() -> void:
	updateComponents()
	updateAspDict()
	updateEccentricities()
	updateWienerIndex()
	updateCentrality()
	updateEdgeCount()
	emit_signal("calculations_done")

# Also updates radius & diameter
func updateEccentricities():
	eccentricities = {}
	radius = {}
	diameter = {}
	for component_index in range( 0 , next_component_index ):
		var sub_asp = sub_asps[component_index]
		var eccentricities_so_far = []
		for v_name in sub_asp.keys():
			var eccentricity = sub_asp[v_name].values().max()
			eccentricities[v_name] = eccentricity
			eccentricities_so_far.push_back(eccentricity)
		radius[component_index] = eccentricities_so_far.min()
		diameter[component_index] = eccentricities_so_far.max()

func updateWienerIndex():
	wiener_index = {}
	for component_index in range( 0 , next_component_index ):
		wiener_index[component_index] = 0
		var sub_asp = sub_asps[component_index]
		var all_vertex_names = sub_asp.keys()
		for v1 in all_vertex_names:
			for v2 in all_vertex_names:
				if(v1>=v2):continue
				wiener_index[component_index] += sub_asp[v1][v2]
		wiener_index[component_index] *= 2.0

func updateAspDict() -> void :
	sub_asps = {}
	
	var vertex_names_by_component_index = {}
	for v_name in component_dict.keys():
		var component_index = component_dict[v_name]
		if not vertex_names_by_component_index.has(component_index):
			vertex_names_by_component_index[component_index]=[]
		vertex_names_by_component_index[component_index].append(v_name)
	
	for component_index in component_size.keys():
		if( using_sparse_algorithms ):
			sub_asps[component_index] = calculateComponentAspSparse( vertex_names_by_component_index[component_index] )
		else:
			sub_asps[component_index] = calculateComponentAspFloydWarshall( vertex_names_by_component_index[component_index] )
	
	


func updateComponents():
	component_dict = {}
	sub_asps = {}
	component_size = {}
	next_component_index = 0
	
	for v_name in edge_dict.keys():
		component_dict[v_name] = null
	
	var discovered_queue = []
	for v_name in component_dict.keys():
		if( component_dict[v_name]==null ):
			var current_component_index = next_component_index
			var current_component_size = 1
			next_component_index += 1
			component_dict[v_name] = current_component_index
			discovered_queue.push_back(v_name)
			while( discovered_queue.size() ):
				var next_v_name = discovered_queue.pop_front()
				for v2_obj in getCloseVertices(next_v_name):
					var v2_name = v2_obj.name
					if( component_dict[v2_name] == null ):
						component_dict[v2_name] = current_component_index
						discovered_queue.push_back(v2_name)
						current_component_size += 1
			component_size[current_component_index] = current_component_size
	for v_name in edge_dict.keys():
		var component_color = available_component_colors[ component_dict[v_name] % available_component_colors.size() ]
		get_node(v_name).self_modulate = component_color
		for edge in edge_dict[v_name]:
			edge.self_modulate = lerp( Color.white , component_color , 0.4 )
	

func updateCentrality():
	centrality = {}
	for c in range(0,next_component_index):
		var asp_dict = sub_asps[c]
		for v_name in asp_dict.keys():
			var sum = 0.0
			for d in asp_dict[v_name].values():
				sum += d
			if( sum == 0 ):
				centrality[v_name] = 0
			else:
				centrality[v_name] = (component_size[c]-1) / sum


func updateEdgeCount():
	for c in component_size.keys():
		edge_count[c] = 0
	for v1_name in edge_dict.keys():
		var c = component_dict[v1_name]
		var v1 = get_node(v1_name)
		for v2 in getCloseVertices(v1):
			if( v1.name < v2.name ):
				edge_count[c] += 1


func clearGraph():
	clicked_vertex = null
	hovered_vertex = null
	for child in get_children():
		child.name = "$$$" + child.name
		child.queue_free()
	edge_dict = {}
	next_vertex_index = 0
	updateCalculations()

func fromString( g:String ):
	clearGraph()
	var g_splitted = g.split(";")
	if( g_splitted[0] == "[about_graphs]" ):
		g_splitted.remove(0)
	var edges_string
	var positions_string = null
	edges_string = g_splitted[0]
	if g_splitted.size() > 1 :
		positions_string = g_splitted[1]
	
	# Creating the vertices & edges
	var edges_string_splitted = edges_string.split(" ",false)
	for i1 in range(0,edges_string_splitted.size(),2):
		var i2 = i1+1
		var v1_name = edges_string_splitted[i1]
		var v2_name = edges_string_splitted[i2]
		if not ( v1_name in edge_dict.keys() ):
			addVertex( get_viewport_rect().size*0.5 + Vector2(100,0).rotated(rand_range(0,2*PI)) , v1_name )
		if not ( v2_name in edge_dict.keys() ):
			addVertex( get_viewport_rect().size*0.5 + Vector2(100,0).rotated(rand_range(0,2*PI)) , v2_name )
		var v1 = get_node(v1_name)
		var v2 = get_node(v2_name)
		if not edgeExists(v1,v2):
			addEdge( v1 , v2 )
	
	# Setting the positions, if available
	if positions_string != null:
		var positions_string_splitted = positions_string.split(" ",false)
		for i in range(0,positions_string_splitted.size(),3):
			var v_name = positions_string_splitted[i]
			var x = float(positions_string_splitted[i+1])
			var y = float(positions_string_splitted[i+2])
			get_node(v_name).rect_position = Vector2( x,y )
		
	updateCalculations()

func toString() -> String :
	var ret = "[about_graphs];"
	var edges_string = ""
	var position_string = ""
	
	for v1_name in edge_dict.keys():
		for v2 in getCloseVertices(v1_name):
			var v2_name = v2.name
			if v2_name>v1_name:
				edges_string += " " + v1_name + " " + v2_name
	
	for v_name in edge_dict.keys():
		var v = get_node(v_name)
		position_string += " " + v_name + " " + String(int(v.rect_position.x)) + " " + String(int(v.rect_position.y))
	
	return "[about_graphs]; " + edges_string + ";" + position_string;


func calculateComponentAspFloydWarshall( component_vertices ):
	var asp_dict = {}
	for v1 in component_vertices:
		asp_dict[v1] = {}
		for v2 in component_vertices:
			asp_dict[v1][v2] = null
	for v1 in component_vertices:
		for edge in edge_dict[v1]:
			var v2 = edge.vertex1.name
			if v2==v1: v2 = edge.vertex2.name
			asp_dict[v1][v2]=1
			asp_dict[v2][v1]=1
		asp_dict[v1][v1]=0

	for v2 in component_vertices:
		for v1 in component_vertices:
			for v3 in component_vertices:
				if v1>=v3: continue
				if( (asp_dict[v1][v2]==null) or (asp_dict[v2][v3]==null) ): continue
				if( (asp_dict[v1][v3]==null) or (asp_dict[v1][v3] > asp_dict[v1][v2] + asp_dict[v2][v3]) ):
					asp_dict[v1][v3] = asp_dict[v1][v2] + asp_dict[v2][v3]
					asp_dict[v3][v1] = asp_dict[v1][v3]
	return asp_dict

func calculateComponentAspSparse( component_vertices ):
	var asp_dict = {}
	var aux_vertices = []
	var bridges = []
	var bridge_map = {}
	
	
	for v in component_vertices:
		if edge_dict[v].size() > 2:
			aux_vertices.push_back(v)
		else:
			var new_bridge_index = bridges.size()
			var new_bridge = {}
			var to_explore = [v]
			var exploreds = [v]
			new_bridge["internal"] = []
			new_bridge["length"] = 0
			new_bridge["extrem0"] = null
			new_bridge["extrem1"] = null
			while to_explore.size()>0:
				var current_exploring = to_explore.pop_back()
				new_bridge["length"] += 1
				new_bridge["internal"].push_back(current_exploring)
				bridge_map[current_exploring] = new_bridge_index
				for v2 in getCloseVertices(current_exploring):
					v2 = v2.name
					if edge_dict[v2].size() > 2 :
						if( new_bridge["extrem0"] == null ):
							new_bridge["extrem0"] = v2
						elif new_bridge["extrem1"] != v2:
							new_bridge["extrem1"] = v2
					else:
						if not (v2 in exploreds):
							to_explore.push_back(v2)
							exploreds.push_back(v2)
			bridges.push_back(new_bridge)
	
	for bi in range(0,bridges.size()):
		var bridge = bridges[bi]
		pass
	

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
			draw_string( font , vertex.rect_position + Vector2(4,-2), eccentricity , Color(1,1,1,1)  )
	if tool_bar.find_node("show_centrality").pressed:
		for vertex_name in edge_dict.keys():
			var c = str( centrality[vertex_name]*100.0 ).substr(0,4) + '%'
			var vertex = get_node(vertex_name)
			draw_string( font , vertex.rect_position + vertex.rect_size*Vector2(0,1) + Vector2(4,10), c , Color(1,1,1,1)  )
			

func _process(delta):
	if(edge_as_springs):
		updateSprings()
		update()

func updateSprings():
	var angle_fixing_factor = 2 # greater: fast fixing
	
	for v_name in edge_dict.keys():
		var v = get_node(v_name)
		v.speed *= 0.83 # 1 -> ideal springs, never stops oscilating;
		v.accel = Vector2()
	
	for v_name in edge_dict.keys():
		var v = get_node(v_name)
		var degree = edge_dict[v_name].size()
		var close_vertices = getCloseVertices(v)
		var angles_by_vertex = {}
		var vertex_by_angle_sorted = []
		for i in range(0,close_vertices.size()):
			var v2 = close_vertices[i]
			var delta_pos = (v2.rect_position - v.rect_position)
			var angle = delta_pos.angle()
			while(angle<0):angle+=2*PI
			angles_by_vertex[v2.name] = angle
			v.accel += delta_pos.normalized()*( delta_pos.length() - spring_length )
		
		# ANGLE FIXING:
		if degree>1:
			var all_angles = angles_by_vertex.values()
			all_angles.sort()
			for a in all_angles:
				for _v in angles_by_vertex.keys():
					if angles_by_vertex[_v] == a and not (_v in vertex_by_angle_sorted) :
						vertex_by_angle_sorted.push_back(_v)
			for i_middle in range(0,degree):
				var v2 = get_node(vertex_by_angle_sorted[i_middle])
				var i_left = (i_middle-1)%degree
				var i_right = (i_middle+1)%degree
				if(i_left==-1):i_left+=degree
				var left_angle = all_angles[i_left]
				var mid_angle = all_angles[i_middle]
				var right_angle = all_angles[i_right]
				var left_delta = mid_angle - left_angle
				var right_delta = right_angle - mid_angle
				while(left_delta<0):left_delta+=2*PI
				while(right_delta<0):right_delta+=2*PI
				v2.accel += angle_fixing_factor*(v.rect_position - v2.rect_position).normalized().rotated(PI/2)*(left_delta-right_delta)
	
	
	
	var mean_v_by_component = {}
	for v_name in edge_dict.keys():
		var v = get_node(v_name)
		var c = component_dict[v_name]
		v.speed += v.accel*0.01
		if( not mean_v_by_component.has(c) ):
			mean_v_by_component[c] = Vector2()
		mean_v_by_component[c] += v.speed
	for c in mean_v_by_component.keys():
		mean_v_by_component[c] /= component_size[c]
	
	for v_name in edge_dict.keys():
		var v = get_node(v_name)
		if v.dragging: continue
		var c = component_dict[v_name]
		var mean_v = mean_v_by_component[c]
		v.rect_position += v.speed - mean_v*int(not Input.is_mouse_button_pressed(BUTTON_LEFT))
	


