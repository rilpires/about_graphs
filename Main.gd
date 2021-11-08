extends Control

var info_panel
var tool_bar
var graph_node
var challenge_selector : OptionButton
var http_req : HTTPRequest
var server_dict = null

# Called when the node enters the scene tree for the first time.
func _ready():
	http_req = get_node("HTTPRequest")
	info_panel = find_node("InfoPanel",true,false)
	tool_bar = find_node("ToolBar",true,false)
	graph_node = find_node("Graph",true,false)
	challenge_selector = find_node("ChallengeSelector",true,false)
	
	graph_node.connect("calculations_done",info_panel,"_on_Graph_calculations_done",[graph_node])
	graph_node.connect("hovered_vertex_changed",info_panel,"_hovered_vertex_changed",[graph_node])
	
	
	tool_bar.find_node("show_eccentricity").connect( "pressed" , graph_node , "update" )
	tool_bar.find_node("show_centrality").connect( "pressed" , graph_node , "update" )
	tool_bar.find_node("clear").connect( "pressed" , self , "reset_graph" )
	
	
	var err = http_req.request("https://api.npoint.io/6381d4ecd481135c5d06") # Don't mess with it please? 
	if err != OK: print("Error sending request")
	else: print("Sent request successfully")
	
	challenge_selector.clear()
	challenge_selector.add_item( "Free graph" , 0 )

func reset_graph():
	var current_id = challenge_selector.get_selected_id()
	graph_node.clearGraph()
	if( current_id > 0 ):
		var challenge = server_dict.challenges[current_id-1]
		var challenge_description_node = get_node("ChallengeDescription")
		graph_node.fromString( challenge.graph )
		challenge_description_node.text = challenge.description
		challenge_description_node.get_node("AnimationPlayer").play("a")


func _on_HTTPRequest_request_completed(result, response_code, headers, body):
	var body_str = body.get_string_from_utf8()
	var body_obj = JSON.parse(body_str)
	if( body_obj.error != OK ): return
	server_dict = body_obj.result
	
	for i in range( 0 , server_dict.challenges.size() ):
		var challenge = server_dict.challenges[i]
		challenge_selector.add_item( challenge.title , i+1 ) 


