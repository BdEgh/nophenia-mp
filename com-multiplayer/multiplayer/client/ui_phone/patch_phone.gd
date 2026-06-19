extends Node

var option_multiplayer_scene = load(get_script().resource_path.get_base_dir() + "/option_multiplayer.tscn")
var multiplayer_scene = load(get_script().resource_path.get_base_dir() + "/multiplayer.tscn")
var option_mods_scene = load(get_script().resource_path.get_base_dir() + "/option_mods.tscn")
var mods_scene = load(get_script().resource_path.get_base_dir() + "/mods.tscn")
var signal_tower_scene = load(get_script().resource_path.get_base_dir() + "/signal_tower.tscn")

var band_low = load(get_script().resource_path.get_base_dir() + "/icons/band_low.tres")
var band_medium = load(get_script().resource_path.get_base_dir() + "/icons/band_medium.tres")
var band_high = load(get_script().resource_path.get_base_dir() + "/icons/band_high.tres")

@export var client: Node

var _refresh_timer: Timer
var _sp_band_tower: TextureRect
var _online_band_tower: TextureRect

func _ready():
    _add_multiplayer_button()
    _add_mods_button()
    _add_band_tower()
    _add_refresh_timer()

func _add_band_tower():
    _sp_band_tower = game.nia.get_node("pause_menu/screen/screen_view/status/status_box/no_signal_tower")
    _online_band_tower = signal_tower_scene.instantiate()
    _online_band_tower.visible = false
    _sp_band_tower.add_sibling(_online_band_tower)
    _sp_band_tower.get_parent().move_child(_online_band_tower, _sp_band_tower.get_index())

func _add_refresh_timer():
    _refresh_timer = Timer.new()
    _refresh_timer.wait_time = 3.0
    _refresh_timer.autostart = true
    _refresh_timer.timeout.connect(_update_signal_tower)
    add_child(_refresh_timer)

func _update_signal_tower():
    var mp_client = get_tree().get_first_node_in_group("mp").network_client
    var ping = mp_client.get_node("ClientApi").last_ping
    if ping == -1 or ping > 1000:
        _online_band_tower.visible = false
        _sp_band_tower.visible = true
        return
    elif ping <= 100:
        _online_band_tower.texture = band_high
    elif ping <= 200:
        _online_band_tower.texture = band_medium
    else:
        _online_band_tower.texture = band_low
    _online_band_tower.tooltip_text = "%d ms" % ping
    _sp_band_tower.visible = false
    _online_band_tower.visible = true

func _add_option(option, screen):
    var pause_menu = game.nia.get_node("pause_menu")
    var screen_view = pause_menu.get_node("screen/screen_view")
    var options_vbox = screen_view.get_node("menu/options/margin_container/scroll_container/v_box_container")
    var menu_control = screen_view.get_node("menu")
    
    options_vbox.add_child(option)
    var cat_option = options_vbox.get_node_or_null("option_cat")
    options_vbox.move_child(option, cat_option.get_index())
    
    menu_control.add_child(screen)
    screen.layout_mode = 1
    option._screen = screen

    _link_focus(option)

func _focusable(vbox, idx, step):
    var i = idx + step
    while i >= 0 and i < vbox.get_child_count():
        var c = vbox.get_child(i)
        if c is Control and c.focus_mode != Control.FOCUS_NONE:
            return c
        i += step
    return null

func _link_focus(option):
    var vbox = option.get_parent()
    var idx = option.get_index()
    var prev = _focusable(vbox, idx, -1)
    var next = _focusable(vbox, idx, 1)
    option.focus_neighbor_top = option.get_path_to(prev) if prev else NodePath()
    option.focus_neighbor_bottom = option.get_path_to(next) if next else NodePath()
    if prev:
        prev.focus_neighbor_bottom = prev.get_path_to(option)
    if next:
        next.focus_neighbor_top = next.get_path_to(option)

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
    option_mods.visible = false
    
    var mods_screen = mods_scene.instantiate()
    mods_screen.name = "mods"
    mods_screen.visible = false
    
    _add_option(option_mods, mods_screen)
