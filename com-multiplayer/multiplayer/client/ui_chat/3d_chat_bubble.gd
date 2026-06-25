extends Node3D

@onready var message_label: RichTextLabel = %MessageLabel
@onready var sprite: Sprite3D = $Sprite

func _ready() -> void:
    sprite.scale = Vector3(0.6, 0.6, 0.6)

func set_message(text: String, sender: String):
    var is_own_message = (sender == "You")
    
    var emoji_dir = get_script().resource_path.get_base_dir() + "/emoji"
    var emoji = load(emoji_dir.get_base_dir() + "/chat_emoji.gd").get_shared(emoji_dir)

    if !is_own_message:
        message_label.text = sender + ": "
    message_label.text += emoji.unwrap(text)
    
    var tween = create_tween().set_parallel(true)
    tween.tween_property(sprite, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(sprite, "position:y", position.y + 0.25, 7.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
    await get_tree().create_timer(7.0).timeout
    
    await create_tween().tween_property(sprite, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).finished
    queue_free()
