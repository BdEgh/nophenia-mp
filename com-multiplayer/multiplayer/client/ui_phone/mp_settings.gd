extends Control

@onready var option_autoconnect: Button = %option_autoconnect
@onready var option_start_server: Button = %option_start_server
@onready var option_col: Button = %option_col
@onready var name_edit: LineEdit = $margin_container/scroll_container/v_box_container/option_name/v_box_container/text_option/h_box_container/line_edit

const _NAV_LEFT_BTN_PATH := "screen/screen_view/navigation/nav_margin/nav_box/nav_info_left_btn"

var _pause_menu: Node
var _left_btn: Button

const NAMES = [
    "cheese", "milk", "tea",
    "coffee", "fish", "pumpkin",
    "melon", "apple", "banana",
    "berry", "honey", "sugar",
    "kiwi", "mango", "orange"
]

func _ready() -> void:
    #name_edit.placeholder_text = Steam.getPersonaName() if game.is_steam() and Steam.steamInit() \
        #else NAMES.pick_random()
    visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
    if visible:
        _connect_lb()
    else:
        _disconnect_lb()

func _resolve_nodes() -> bool:
    _pause_menu = game.nia.get_node("pause_menu")
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
    _refresh_options()
    audio.play_snd(game.loadres("phone_keypad_long"), 1.0)
    audio.play_snd(game.loadres("keypad"))
    _pause_menu.phone_feedback()
