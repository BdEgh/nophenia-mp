extends Control

@onready var chat_container = %ChatContainer
@onready var message_input = %MessageInput
@onready var send_button = %SendButton
@onready var scroll_container = %ScrollContainer

var chat_bubble_scene = load(get_script().resource_path.get_base_dir() + "/chat_bubble.tscn")
@export var client_api: Node
@export var puppet_manager: Node

func _ready():
	send_button.pressed.connect(_on_send_pressed)
	message_input.text_submitted.connect(_on_message_submitted)
	
	visible = false
	
	if client_api:
		client_api.player_message.connect(_on_player_message)
	else:
		ModLoaderLog.warning("client_api not found", self.name)

func _input(event):
	if event is InputEventKey and event.pressed:
		if !visible and (event.keycode == KEY_T or event.keycode == KEY_ENTER):
			toggle_chat()
		if visible and event.keycode == KEY_ESCAPE:
			toggle_chat()

func toggle_chat():
	var nia = game.find("player")
	var camera
	if nia:
		camera = nia.get_node("cam_box/cam_arm/cam_arm_fix/view")
	
	if !visible:
		if nia.is_freecam:
			return
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		visible = true
		nia.is_freecam = true
		nia._screenshot_cd = true
		if camera:
			var cam_arm = nia.get_node("cam_box/cam_arm")
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
		nia.is_freecam = false
		nia._screenshot_cd = false
		game.active_stage.anomaly_occurring = false

func _animate_camera(camera: Node3D, target_x: float):
	create_tween().tween_property(camera, "position:x", target_x, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func add_message(text: String, sender: String = "You"):
	var bubble = chat_bubble_scene.instantiate()
	
	chat_container.add_child(bubble)
	bubble.set_message(text, sender)

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

func _on_send_pressed():
	_send_message()

func _on_message_submitted(_text: String):
	_send_message()

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
