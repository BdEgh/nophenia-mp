extends Control

@onready var chat_container = %ChatContainer
@onready var message_input = %MessageInput
@onready var send_button = %SendButton
@onready var scroll_container = %ScrollContainer

var chat_bubble_scene = load(get_script().resource_path.get_base_dir() + "/chat_bubble.tscn")
@export var client_api: Node
@export var puppet_manager: Node

var toggling := false
var emoji_dir: String = get_script().resource_path.get_base_dir() + "/emoji"
var emoji_paths := {}
var emoji_regex := RegEx.new()

func _ready():
    visible = false
    _load_emoji()
    if client_api:
        client_api.player_message.connect(_on_player_message)
    else:
        ModLoaderLog.warning("client_api not found", self.name)

func _load_emoji():
    emoji_regex.compile(":([a-z_]+):")
    var dir = DirAccess.open(emoji_dir)
    if not dir:
        return
    for file in dir.get_files():
        emoji_paths[file.get_basename()] = emoji_dir + "/" + file
        if file.get_basename().begins_with("emiwa_"):
            emoji_paths[file.get_basename().trim_prefix("emiwa_")] = emoji_dir + "/" + file

func _unwrap_emoji(text: String) -> String:
    var result := ""
    var pos := 0
    for m in emoji_regex.search_all(text):
        result += text.substr(pos, m.get_start() - pos)
        var path = emoji_paths.get(m.get_string(1))
        if path:
            result += "[img height=32]%s[/img]" % path
        else:
            result += m.get_string(0)
        pos = m.get_end()
    result += text.substr(pos)
    return result

func _input(event):
    if event is InputEventKey and event.pressed and !event.echo:
        if !visible and (event.keycode == KEY_T or event.keycode == KEY_ENTER):
            if game.nia.is_paused:
                return
            toggle_chat()
        elif visible and event.keycode == KEY_ESCAPE:
            toggle_chat()
            get_viewport().set_input_as_handled()

func toggle_chat():
    if toggling:
        return
    
    toggling = true
    var camera = game.nia.get_node("cam_box/cam_arm/cam_arm_fix/view")
    
    if !visible:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        visible = true
        _set_player_input_enabled(false)
        if camera:
            var cam_arm = game.nia.get_node("cam_box/cam_arm")
            var move_multiplier = (cam_arm.spring_length - 1.2) / 2 + 1.0
            _animate_camera(camera, -0.65 * move_multiplier)
        await create_tween().tween_property(self, "modulate:a", 1.0, 0.5).from(0.0).set_trans(Tween.TRANS_CIRC).finished
        message_input.grab_focus()
        message_input.text = ""
    else:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
        message_input.release_focus()
        if camera:
            _animate_camera(camera, 0.0)
        await create_tween().tween_property(self, "modulate:a", 0.0, 0.5).from(1.0).set_trans(Tween.TRANS_CIRC).finished
        visible = false
        _set_player_input_enabled(true)
        game.active_stage.anomaly_occurring = false
    
    toggling = false

func _set_player_input_enabled(enabled: bool) -> void:
    game.nia.set_process_unhandled_input(enabled)
    game.nia.is_paused = not enabled
    if !enabled:
        game.nia.velocity = Vector3.ZERO
        var anim_tree = game.nia.get_node_or_null("anim_tree")
        if anim_tree:
            anim_tree.set("parameters/idle_walk_run/blend_position", Vector2.ZERO)

func _animate_camera(camera: Node3D, target_x: float):
    create_tween().tween_property(camera, "position:x", target_x, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func add_message(text: String, sender: String = "You"):
    var bubble = chat_bubble_scene.instantiate()
    
    chat_container.add_child(bubble)
    bubble.set_message(_unwrap_emoji(text), sender)

func _on_player_message(player_id: int, message: String):
    if message.begins_with("DO:"):
        return
    
    var sender_name = player_id
    if puppet_manager:
        sender_name = puppet_manager.NAMES[player_id % len(puppet_manager.NAMES)]
        var puppet = puppet_manager.get_puppet(player_id)
        if puppet:
            puppet.show_chat_message(message)
    
    add_message(message, sender_name)

func _send_message():
    var text = message_input.text.strip_edges()
    if text.is_empty():
        return
    
    message_input.text = ""
    if client_api:
        client_api.send_chat_message(text)
        add_message(text, "You")
    else:
        ModLoaderLog.warning("cannot send message - client_api not found", self.name)
    
    await get_tree().create_timer(0.1).timeout
    scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)

func _on_send_button_pressed() -> void:
    _send_message()

func _on_message_input_text_submitted(_new_text: String) -> void:
    _send_message()
