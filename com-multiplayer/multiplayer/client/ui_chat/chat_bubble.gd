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
