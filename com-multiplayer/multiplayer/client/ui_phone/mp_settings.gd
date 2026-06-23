extends Control

@onready var option_autoconnect: Button = %option_autoconnect
@onready var option_address: Button = %option_address
@onready var option_start_server: Button = %option_start_server
@onready var option_col: Button = %option_col
@onready var option_seed: Button = %option_seed
@onready var name_edit: LineEdit = $margin_container/scroll_container/v_box_container/option_name/v_box_container/text_option/h_box_container/line_edit

const _NAV_LEFT_BTN_PATH := "screen/screen_view/navigation/nav_margin/nav_box/nav_info_left_btn"

var _pause_menu: Node
var _left_btn: Button

func _ready() -> void:
    name_edit.placeholder_text = get_tree().get_first_node_in_group("mp").default_name
    visibility_changed.connect(_on_visibility_changed)
    option_seed.tooltip_text = \
"determines the order of stages
shuffles after completing the game"

func _on_visibility_changed() -> void:
    if visible:
        _connect_lb()
    else:
        _disconnect_lb()

func _resolve_nodes() -> bool:
    _pause_menu = get_tree().get_first_node_in_group("player").get_node("pause_menu")
    _left_btn = _pause_menu.get_node_or_null(_NAV_LEFT_BTN_PATH)
    return _left_btn != null

func _connect_lb() -> void:
    if not _resolve_nodes():
        return
    if _left_btn.pressed.is_connected(_pause_menu._on_nav_info_left_btn_pressed):
        _left_btn.pressed.disconnect(_pause_menu._on_nav_info_left_btn_pressed)
    if not _left_btn.pressed.is_connected(_on_left_pressed):
        _left_btn.pressed.connect(_on_left_pressed)
    _left_btn.disable(false)

func _disconnect_lb() -> void:
    if _left_btn == null:
        return
    if _left_btn.pressed.is_connected(_on_left_pressed):
        _left_btn.pressed.disconnect(_on_left_pressed)
    if not _left_btn.pressed.is_connected(_pause_menu._on_nav_info_left_btn_pressed):
        _left_btn.pressed.connect(_pause_menu._on_nav_info_left_btn_pressed)

func _on_left_pressed() -> void:
    _reset_config()

func _refresh_options() -> void:
    for option in find_children("*", "Button", true, false):
        if option.has_method("_config_adjust"):
            option._config_adjust()

func _reset_config() -> void:
    var mp = get_tree().get_first_node_in_group("mp")
    var defaults = mp.mp_cfg_res.new()
    for _prop in mp.mp_cfg.get_script().get_script_property_list():
        mp.mp_cfg.set(_prop.name, defaults.get(_prop.name))
    mp.save_config()
    name_edit.placeholder_text = get_tree().get_first_node_in_group("mp").default_name
    _refresh_options()
    audio.play_snd(game.loadres("phone_keypad_long"), 1.0)
    audio.play_snd(game.loadres("keypad"))
    _pause_menu.phone_feedback()

func _on_option_start_server_toggled(toggled_on: bool) -> void:
    var mp = get_tree().get_first_node_in_group("mp")
    if mp:
        mp.mp_cfg.start_server = toggled_on
        if toggled_on:
            mp.set_network_server()
        else:
            mp.drop_network_server()
    
    if not option_autoconnect or not option_address:
        return
    if toggled_on:
        option_autoconnect.disabled = true
        option_address.disabled = true
        option_address.hide_text()
        var tooltip := "unable to edit while server is running"
        option_autoconnect.tooltip_text = tooltip
        option_address.tooltip_text = tooltip
    else:
        option_autoconnect.disabled = false
        option_autoconnect.tooltip_text = "Connect"
        option_address.disabled = false
        option_address.tooltip_text = "Address"

func _on_option_col_toggled(toggled_on: bool) -> void:
    var mp = get_tree().get_first_node_in_group("mp")
    mp.mp_cfg.collision = toggled_on
    mp.apply_player_collision()

func _on_option_autoconnect_toggled(toggled_on: bool) -> void:
    var mp = get_tree().get_first_node_in_group("mp")
    if mp:
        mp.mp_cfg.auto_connect = toggled_on
        if toggled_on:
            mp.set_network_client()
        else:
            mp.drop_network_client()

func _restart_server(text: String) -> void:
     var mp = get_tree().get_first_node_in_group("mp")
     if mp.mp_cfg.server_port == int(text):
         return
     mp.mp_cfg.server_port = int(text)
     if mp.mp_cfg.start_server:
         mp.drop_network_server()
         mp.set_network_server()

func _on_port_submitted(new_text: String) -> void:
    _restart_server(new_text)

@onready var port_line_edit: LineEdit = $margin_container/scroll_container/v_box_container/option_port/v_box_container/text_option/h_box_container/line_edit
func _on_port_focus_exited() -> void:
    _restart_server(port_line_edit.text)

func _restart_client(text: String) -> void:
    var mp = get_tree().get_first_node_in_group("mp")
    if mp.mp_cfg.address == text:
        return
    mp.mp_cfg.address = text
    if mp.mp_cfg.auto_connect:
        mp.drop_network_client()
        mp.set_network_client()

func _on_address_submitted(new_text: String) -> void:
    _restart_client(new_text)

@onready var address_line_edit: LineEdit = $margin_container/scroll_container/v_box_container/option_address/v_box_container/text_option/h_box_container/line_edit
func _on_address_exited() -> void:
    _restart_client(address_line_edit.text)

func _on_seed_submitted(new_text: String) -> void:
    var mp = get_tree().get_first_node_in_group("mp")
    mp.mp_cfg.rng_seed = int(new_text)

@onready var seed_line_edit: LineEdit = $margin_container/scroll_container/v_box_container/option_seed/v_box_container/text_option/h_box_container/line_edit
func _on_seed_focus_exited() -> void:
    var mp = get_tree().get_first_node_in_group("mp")
    mp.mp_cfg.rng_seed = int(seed_line_edit.text)

func _on_name_submitted(new_text: String) -> void:
    var mp = get_tree().get_first_node_in_group("mp")
    mp.mp_cfg.player_name = new_text

@onready var name_line_edit: LineEdit = $margin_container/scroll_container/v_box_container/option_name/v_box_container/text_option/h_box_container/line_edit
func _on_name_focus_exited() -> void:
    var mp = get_tree().get_first_node_in_group("mp")
    mp.mp_cfg.player_name = name_line_edit.text
