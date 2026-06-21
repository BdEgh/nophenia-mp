extends Node

var option_mp_info_scene = load(get_script().resource_path.get_base_dir() + "/option_mp_info.tscn")
var mp_info_scene = load(get_script().resource_path.get_base_dir() + "/mp_info.tscn")
var option_mp_settings_scene = load(get_script().resource_path.get_base_dir() + "/option_mp_settings.tscn")
var mp_settings_scene = load(get_script().resource_path.get_base_dir() + "/mp_settings.tscn")
var signal_tower_scene = load(get_script().resource_path.get_base_dir() + "/signal_tower.tscn")

var band_low = load(get_script().resource_path.get_base_dir() + "/icons/band_low.tres")
var band_medium = load(get_script().resource_path.get_base_dir() + "/icons/band_medium.tres")
var band_high = load(get_script().resource_path.get_base_dir() + "/icons/band_high.tres")
var hosting = load(get_script().resource_path.get_base_dir() + "/icons/hosting.tres")

@export var client: Node

var _refresh_timer: Timer
var _sp_band_tower: TextureRect
var _online_band_tower: TextureRect
var _no_calls: TextureRect
var _hosting: TextureRect
var _signal_status: Label
var _online_signal_status: Label
var _signal_status_tween: Tween
var _was_connected: bool = false

func _ready():
    _add_mp_settings_button()
    _add_mp_info_button()
    _add_icons()
    _add_refresh_timer()

func _add_icons():
    _sp_band_tower = game.nia.get_node("pause_menu/screen/screen_view/status/status_box/no_signal_tower")
    _no_calls = game.nia.get_node("pause_menu/screen/screen_view/status/status_box/no_calls")
    _signal_status = game.nia.get_node("pause_menu/screen/screen_view/menu/home/signal_status")
    _online_signal_status = _signal_status.duplicate()
    _online_signal_status.name = "online_signal_status"
    _online_signal_status.unique_name_in_owner = false
    _online_signal_status.visible = false
    _signal_status.add_sibling(_online_signal_status)
    _online_band_tower = signal_tower_scene.instantiate()
    _online_band_tower.visible = false
    _online_band_tower.size_flags_horizontal = Control.SIZE_EXPAND
    _sp_band_tower.add_sibling(_online_band_tower)
    var header := _sp_band_tower.get_parent()
    header.move_child(_online_band_tower, _sp_band_tower.get_index())
    _hosting = signal_tower_scene.instantiate()
    _hosting.texture = hosting
    _hosting.visible = false
    _hosting.tooltip_text = "server is working on port %d" % get_tree().get_first_node_in_group("mp").mp_cfg.server_port
    _no_calls.add_sibling(_hosting)
    header.move_child(_hosting, _no_calls.get_index())
    var pause_menu = game.nia.get_node("pause_menu")
    pause_menu.visibility_changed.connect(_on_pause_menu_visibility_changed.bind(pause_menu))

func _on_pause_menu_visibility_changed(pause_menu):
    if not pause_menu.visible:
        return
    var mp_client = get_tree().get_first_node_in_group("mp").network_client
    var ping = mp_client.get_node("ClientApi").last_ping
    if ping == -1 or ping > 1000:
        return
    _show_connected_status()

func _add_refresh_timer():
    _refresh_timer = Timer.new()
    _refresh_timer.wait_time = 3.0
    _refresh_timer.autostart = true
    _refresh_timer.timeout.connect(_update_signal_tower)
    _refresh_timer.timeout.connect(_update_hosting_icon)
    add_child(_refresh_timer)

func _update_hosting_icon():
    var mp_server = get_tree().get_first_node_in_group("mp").network_server
    if mp_server and not _hosting.visible:
        _hosting.visible = true
    elif not mp_server and _hosting.visible:
        _hosting.visible = false

func _update_signal_tower():
    var mp_client = get_tree().get_first_node_in_group("mp").network_client
    var ping = mp_client.get_node("ClientApi").last_ping
    if ping == -1 or ping > 1000:
        _online_band_tower.visible = false
        _sp_band_tower.visible = true
        _no_calls.visible = true
        _was_connected = false
        _online_signal_status.visible = false
        _signal_status.visible = true
        return
    if not _was_connected:
        _was_connected = true

    if ping <= 100:
        _online_band_tower.texture = band_high
    elif ping <= 200:
        _online_band_tower.texture = band_medium
    else:
        _online_band_tower.texture = band_low
    _online_band_tower.tooltip_text = "%d ms" % ping
    _sp_band_tower.visible = false
    _online_band_tower.visible = true
    _no_calls.visible = false

func _show_connected_status():
    _signal_status.visible = false
    _online_signal_status.visible = true
    _online_signal_status.text = "connected to server"
    var _revert = ( func(_temp):
        if not is_instance_valid(_online_signal_status):
            return
        if config.has_killed_her:
            match randi_range(0, 12):
                2: _online_signal_status.text = "signal_reset_afterthought_alt"
                3: _online_signal_status.text = "signal_reset_afterthought_alt_002"
                4: _online_signal_status.text = "signal_reset_afterthought_alt_003"
                5: _online_signal_status.text = "signal_reset_afterthought_alt_004"
                6: _online_signal_status.text = "signal_reset_afterthought_alt_005"
                7: _online_signal_status.text = "signal_reset_afterthought_alt_006"
                8: _online_signal_status.text = "signal_reset_afterthought_alt_007"
                _: _online_signal_status.text = "signal_reset_afterthought"
            config.has_killed_her = false
        else:
            match randi_range(0, 25):
                10: _online_signal_status.text = game.ran_array(game.lane).replace("%s", tr(game.active_stage.stage_name))
                _: pass
        )
    if _signal_status_tween and _signal_status_tween.is_running():
        _signal_status_tween.kill()
    _signal_status_tween = create_tween()
    _signal_status_tween.tween_method(_revert, 0.0, 0.0, 0).set_delay(randf_range(3.5, 10.0))

func _add_option(option, screen):
    var pause_menu = game.nia.get_node("pause_menu")
    var screen_view = pause_menu.get_node("screen/screen_view")
    var options_vbox = screen_view.get_node("menu/options/margin_container/scroll_container/v_box_container")
    var menu_control = screen_view.get_node("menu")
    
    options_vbox.add_child(option)
    var forget_option = options_vbox.get_node_or_null("option_new_save")
    options_vbox.move_child(option, forget_option.get_index())
    
    menu_control.add_child(screen)
    option._screen = screen

func _add_mp_info_button():
    var option_multiplayer = option_mp_info_scene.instantiate()
    option_multiplayer.name = "option_multiplayer"
    
    var multiplayer_screen = mp_info_scene.instantiate()
    multiplayer_screen.name = "multiplayer"
    multiplayer_screen.visible = false
    var info_label = multiplayer_screen.get_node("margin_container/v_box_container2/nine_patch_rect2/margin_container/info")
    if info_label:
        info_label.client = client
        var mp_client = get_tree().get_first_node_in_group("mp").network_client
        info_label.puppet_manager = mp_client.get_node("PuppetManager")
    
    _add_option(option_multiplayer, multiplayer_screen)

func _add_mp_settings_button():
    var option_mp_settings = option_mp_settings_scene.instantiate()
    option_mp_settings.name = "option_mods"
    
    var mp_settings = mp_settings_scene.instantiate()
    mp_settings.name = "mp_settings"
    mp_settings.visible = false
    mp_settings.visibility_changed.connect(_reset_mp_settings_scroll.bind(mp_settings))

    _add_option(option_mp_settings, mp_settings)

func _reset_mp_settings_scroll(mp_settings):
    if not mp_settings.visible:
        return
    await get_tree().process_frame
    var scroll = mp_settings.get_node_or_null("margin_container/scroll_container")
    if scroll:
        scroll.scroll_vertical = 0
