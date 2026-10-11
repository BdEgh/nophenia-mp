extends Control

@onready var button_list: VBoxContainer = %v_box_container


var map_button_res := load(get_script().resource_path.get_base_dir() + "/map_select_button.tscn")
func add_map(map: Dictionary):
    var button = map_button_res.instantiate()
    button_list.add_child(button)
    button.fill_data(map)
    
