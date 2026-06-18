extends Node

var option_multiplayer_scene = load(get_script().resource_path.get_base_dir() + "/option_multiplayer.tscn")
var multiplayer_scene = load(get_script().resource_path.get_base_dir() + "/multiplayer.tscn")

var option_mods_scene = load(get_script().resource_path.get_base_dir() + "/option_mods.tscn")
var mods_scene = load(get_script().resource_path.get_base_dir() + "/mods.tscn")

@export var nia: CharacterBody3D
@export var client: Node

func _ready():
    _add_multiplayer_button()
    _add_mods_button()

func _add_option(option, screen):
    var pause_menu = nia.get_node("pause_menu")
    var screen_view = pause_menu.get_node("screen/screen_view")
    var options_vbox = screen_view.get_node("menu/options/margin_container/scroll_container/v_box_container")
    var menu_control = screen_view.get_node("menu")
    
    options_vbox.add_child(option)
    var cat_option = options_vbox.get_node_or_null("option_cat")
    options_vbox.move_child(option, cat_option.get_index())
    
    menu_control.add_child(screen)
    screen.layout_mode = 1
    option._screen = screen

func _add_multiplayer_button():
    var option_multiplayer = option_multiplayer_scene.instantiate()
    option_multiplayer.name = "option_multiplayer"
    
    var multiplayer_screen = multiplayer_scene.instantiate()
    multiplayer_screen.name = "multiplayer"
    multiplayer_screen.visible = false
    var info_label = multiplayer_screen.get_node("margin_container/v_box_container2/nine_patch_rect2/margin_container/info")
    if info_label:
        info_label.client = client
        var mp_client = get_tree().get_first_node_in_group("mp").network_client
        info_label.puppet_manager = mp_client.get_node("PuppetManager")
    
    _add_option(option_multiplayer, multiplayer_screen)

func _add_mods_button():
    var option_mods = option_mods_scene.instantiate()
    option_mods.name = "option_mods"
    
    var mods_screen = mods_scene.instantiate()
    mods_screen.name = "mods"
    mods_screen.visible = false
    
    _add_option(option_mods, mods_screen)
