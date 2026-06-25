extends Control

@onready var chat_container = %ChatContainer
@onready var message_input = %MessageInput
@onready var send_button = %SendButton
@onready var scroll_container = %ScrollContainer

var chat_bubble_scene = load(get_script().resource_path.get_base_dir() + "/chat_bubble.tscn")
var emoji_scene = load(get_script().resource_path.get_base_dir() + "/emoji.tscn")
var emoji_button_scene = load(get_script().resource_path.get_base_dir() + "/emoji_button.tscn")
@export var client: Node:
    set(value):
        if value == client:
            return
        _disconnect_client()
        client = value
        _connect_client()
@export var puppet_manager: Node

var toggling := false
var emoji_prefix_regex := RegEx.new()
var emoji_dir: String = get_script().resource_path.get_base_dir() + "/emoji"
var emoji = load(emoji_dir.get_base_dir() + "/chat_emoji.gd").get_shared(emoji_dir)

func _ready() -> void:
    emoji_prefix_regex.compile(":([a-z_]*)$")
    message_input.text_changed.connect(_on_input_changed)
    visible = false

func _connect_client() -> void:
    if client == null or client.player_message.is_connected(_on_player_message):
        return
    client.player_message.connect(_on_player_message)

func _disconnect_client() -> void:
    if client == null or not client.player_message.is_connected(_on_player_message):
        return
    client.player_message.disconnect(_on_player_message)

var emoji_popup: Control = null
var emoji_prefix = null
var emoji_timer := 0.0

func _trailing_prefix():
    var m = emoji_prefix_regex.search(message_input.text)
    return m.get_string(1) if m else null

func _on_input_changed(_text: String) -> void:
    var prefix = _trailing_prefix()
    if prefix == null:
        emoji_prefix = null
        emoji_timer = 0.0
        _close_emoji_window()
    elif prefix != emoji_prefix:
        emoji_prefix = prefix
        emoji_timer = 1.0
        _close_emoji_window()

func _physics_process(delta: float) -> void:
    if emoji_timer <= 0.0 or not emoji_prefix:
        return
    emoji_timer -= delta
    if emoji_timer <= 0.0 and _trailing_prefix() == emoji_prefix:
        _open_emoji_window(emoji_prefix)

func _pick_emoji(emoji_name: String) -> void:
    var m = emoji_prefix_regex.search(message_input.text)
    var text = message_input.text.substr(0, m.get_start()) if m else message_input.text
    text += ":%s:" % emoji_name
    message_input.text = text
    message_input.caret_column = text.length()
    emoji_prefix = null
    _close_emoji_window()
    message_input.grab_focus()

func _open_emoji_window(prefix: String) -> void:
    var paths = emoji.paths
    var names := []
    for emoji_name in paths:
        if emoji_name.begins_with(prefix):
            names.append(emoji_name)
    if names.is_empty():
        return
    names.sort()
    _close_emoji_window()
    emoji_popup = emoji_scene.instantiate()
    add_child(emoji_popup)
    var v_box = emoji_popup.get_node("scroll_container/v_box_container")
    for emoji_name in names:
        var button = emoji_button_scene.instantiate()
        button.get_node("emoji/icon").texture = load(paths[emoji_name])
        button.get_node("emoji/name").text = ":%s:" % emoji_name
        button.pressed.connect(_pick_emoji.bind(emoji_name))
        v_box.add_child(button)
    if emoji_popup:
        var rect = message_input.get_global_rect()
        var font = message_input.get_theme_font("font")
        var font_size = message_input.get_theme_font_size("font_size")
        var caret_x = font.get_string_size(message_input.text, 0, -1, font_size).x
        emoji_popup.global_position = Vector2(rect.position.x + caret_x, rect.position.y - emoji_popup.size.y)

func _close_emoji_window() -> void:
    if emoji_popup:
        emoji_popup.queue_free()
        emoji_popup = null

func _input(event):
    if event is InputEventKey and event.pressed and !event.echo:
        if !visible and (event.keycode == KEY_T or event.keycode == KEY_ENTER):
            if get_tree().get_first_node_in_group("player").is_paused:
                return
            toggle_chat()
        elif visible and event.keycode == KEY_ESCAPE:
            toggle_chat()
            get_viewport().set_input_as_handled()

func toggle_chat():
    if toggling:
        return
    
    toggling = true
    var camera = get_tree().get_first_node_in_group("player").get_node("cam_box/cam_arm/cam_arm_fix/view")
    
    if !visible:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        visible = true
        _set_player_input_enabled(false)
        if camera:
            var cam_arm = get_tree().get_first_node_in_group("player").get_node("cam_box/cam_arm")
            var move_multiplier = (cam_arm.spring_length - 1.2) / 2 + 1.0
            _animate_camera(camera, -0.65 * move_multiplier)
        await create_tween().tween_property(self, "modulate:a", 1.0, 0.5).from(0.0).set_trans(Tween.TRANS_CIRC).finished
        message_input.grab_focus()
    else:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
        emoji_prefix = null
        _close_emoji_window()
        message_input.release_focus()
        if camera:
            _animate_camera(camera, 0.0)
        await create_tween().tween_property(self, "modulate:a", 0.0, 0.5).from(1.0).set_trans(Tween.TRANS_CIRC).finished
        visible = false
        _set_player_input_enabled(true)
        game.active_stage.anomaly_occurring = false
    
    toggling = false

func _set_player_input_enabled(enabled: bool) -> void:
    get_tree().get_first_node_in_group("player").set_process_unhandled_input(enabled)
    get_tree().get_first_node_in_group("player").is_paused = not enabled
    if !enabled:
        get_tree().get_first_node_in_group("player").velocity = Vector3.ZERO
        var anim_tree = get_tree().get_first_node_in_group("player").get_node_or_null("anim_tree")
        if anim_tree:
            anim_tree.set("parameters/idle_walk_run/blend_position", Vector2.ZERO)

func _animate_camera(camera: Node3D, target_x: float):
    create_tween().tween_property(camera, "position:x", target_x, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func add_message(text: String, sender: String = "You"):
    if sender == "You":
        audio.play_snd(game.loadres("phone_keypad_short"), -1, 0.6, "snd")
    var bubble = chat_bubble_scene.instantiate()
    
    chat_container.add_child(bubble)
    bubble.set_message(emoji.unwrap(text), sender)

func _on_player_message(player_id: int, message: String, player_name: String) -> void:
    if message.begins_with("DO:"):
        return

    var sender_name = player_name if player_name != "" else str(player_id)
    if puppet_manager:
        var puppet = puppet_manager.get_puppet(player_id)
        if puppet:
            if sender_name == str(player_id) and puppet.player_name != "":
                sender_name = puppet.player_name
            puppet.show_chat_message(message, sender_name)
    
    var was_at_bottom = _is_scrolled_to_bottom()
    add_message(message, sender_name)
    if was_at_bottom:
        _scroll_to_bottom()

func _is_scrolled_to_bottom() -> bool:
    var v_scroll = scroll_container.get_v_scroll_bar()
    return scroll_container.scroll_vertical >= int(v_scroll.max_value - v_scroll.page) - 4

func _scroll_to_bottom() -> void:
    await get_tree().create_timer(0.1).timeout
    scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)

func _send_message():
    var text = message_input.text.strip_edges()
    if text.is_empty():
        return
    
    message_input.text = ""
    if client:
        client.send_chat_message(text)
        add_message(text, "You")
    else:
        ModLoaderLog.warning("cannot send message - client not found", self.name)
    
    _scroll_to_bottom()

func _on_send_button_pressed() -> void:
    _send_message()

func _on_message_input_text_submitted(_new_text: String) -> void:
    _send_message()
