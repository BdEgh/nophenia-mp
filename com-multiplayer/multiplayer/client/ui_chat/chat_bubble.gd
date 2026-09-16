extends HBoxContainer

@onready var message_label = %MessageLabel
@onready var left_spacer = %LeftSpacer
@onready var right_spacer = %RightSpacer

func set_message(text: String, sender: String):
    var is_own_message = (sender == "You")
    
    if !is_own_message:
        message_label.text = sender + ": "
    message_label.text += text
    
    if is_own_message:
        left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        right_spacer.size_flags_horizontal = 0
    else:
        left_spacer.size_flags_horizontal = 0
        right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    
    if message_label.get_content_width() > 250.0:
        message_label.autowrap_mode = 3
        message_label.custom_minimum_size.x = 250.0
    
    create_tween().tween_property(message_label, "modulate:a", 1.0, 0.5) \
        .from(0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_message_label_meta_hover_started(meta: Variant) -> void:
    message_label.tooltip_text = str(meta)
    self.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _on_message_label_meta_hover_ended(meta: Variant) -> void:
    message_label.tooltip_text = ""
    self.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _on_message_label_meta_clicked(meta: Variant) -> void:
    if meta is String and meta.begins_with("s="):
        var mp = get_tree().get_first_node_in_group("mp")
        var _stage = meta.substr(2)
        var chat = mp.chat.get_node("ChatUI")
        var rl = mp.remote_loader
        chat.toggle_chat()
        rl.change_stage(_stage)
        return
    OS.shell_open(str(meta))
