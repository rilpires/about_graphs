extends OptionButton

var reset_button : Button = null
var current_selected_id = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	add_item("Free graph")
	add_item("Challenge 1")
	add_item("Challenge 2")
	add_item("Challenge 3")
	
	yield( get_tree() , "physics_frame" )
	var current_rot = get_tree().current_scene
	reset_button = current_rot.find_node("clear",true,false)
	
	current_selected_id = get_selected_id()


func _on_ChallengeSelector_item_selected(index):
	if( current_selected_id == index ): return
	reset_button.emit_signal("pressed")
	current_selected_id = index
